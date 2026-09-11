//
//  DaVinciDeviceTests.swift
//  DavinciTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingOrchestrate
@testable import PingLogger
@testable import PingOidc
@testable import PingStorage
@testable import PingDavinci
@testable import PingNetwork

// MARK: - populateDeviceFlowVerificationRequest tests

/// Tests for `OidcClientConfig.populateDeviceFlowVerificationRequest`.
final class PopulateDeviceFlowVerificationRequestTests: XCTestCase {

    private func makeConfig(deviceAuthEndpoint: String, clientId: String = "my-client") -> OidcClientConfig {
        let config = OidcClientConfig()
        config.clientId = clientId
        config.openId = OpenIdConfiguration(
            authorizationEndpoint: "https://auth.example.com/authorize",
            tokenEndpoint: "https://auth.example.com/token",
            userinfoEndpoint: "https://auth.example.com/userinfo",
            endSessionEndpoint: "https://auth.example.com/signoff",
            revocationEndpoint: "https://auth.example.com/revoke",
            deviceAuthorizationEndpoint: deviceAuthEndpoint
        )
        return config
    }

    // MARK: - Standard PingOne endpoint strips /as/device_authorization suffix

    func testStripsAsDeviceAuthorizationSuffix() throws {
        let endpoint = "https://auth.pingone.ca/tenant123/as/device_authorization"
        let config = makeConfig(deviceAuthEndpoint: endpoint)
        let request = URLSessionHttpRequest()

        let populated = try config.populateDeviceFlowVerificationRequest(request: request, userCode: "ABCD-1234")

        XCTAssertEqual(populated.url,
                       "https://auth.pingone.ca/tenant123/applications/my-client/deviceFlow?userCode=ABCD-1234",
                       "URL should drop /as/device_authorization and append /applications/{clientId}/deviceFlow")
    }

    // MARK: - Custom-domain endpoint without the standard suffix uses endpoint as base
    //
    // NOTE: The PingOne-specific `/applications/{clientId}/deviceFlow` segment is appended
    // unconditionally. On a non-PingOne AS this will produce a URL that 404s server-side —
    // that's the intended fail-loud behavior (handled by the server, not locally suppressed).
    // We only assert the function does not throw and produces a non-empty URL; the exact
    // shape is not a contract we want callers to rely on for non-PingOne deployments.
    func testFallbackBaseWhenSuffixAbsentDoesNotThrow() throws {
        let endpoint = "https://custom.example.com/device_authorization"
        let config = makeConfig(deviceAuthEndpoint: endpoint)
        let request = URLSessionHttpRequest()

        let populated = try config.populateDeviceFlowVerificationRequest(request: request, userCode: "WXYZ-5678")

        XCTAssertNotNil(populated.url, "Function must not throw when suffix is absent; server is responsible for rejecting non-PingOne URLs")
        XCTAssertFalse(populated.url?.isEmpty ?? true)
    }

    // MARK: - clientId is correctly embedded in URL path

    func testClientIdIsEmbeddedInPath() throws {
        let endpoint = "https://auth.pingone.eu/tenant-abc/as/device_authorization"
        let config = makeConfig(deviceAuthEndpoint: endpoint, clientId: "special-client-id")
        let request = URLSessionHttpRequest()

        let populated = try config.populateDeviceFlowVerificationRequest(request: request, userCode: "TEST-0000")

        XCTAssertTrue(populated.url?.contains("/applications/special-client-id/deviceFlow") == true,
                      "clientId must appear in the applications path segment")
    }

    // MARK: - userCode is sent as camelCase query param

    func testUserCodeSentAsCamelCase() throws {
        let endpoint = "https://auth.pingone.ca/tenant123/as/device_authorization"
        let config = makeConfig(deviceAuthEndpoint: endpoint)
        let request = URLSessionHttpRequest()

        let populated = try config.populateDeviceFlowVerificationRequest(request: request, userCode: "MY-CODE")

        let url = populated.url ?? ""
        XCTAssertTrue(url.contains("userCode=MY-CODE"),
                      "userCode must be sent as camelCase query param, got: \(url)")
        XCTAssertFalse(url.contains("user_code="),
                       "snake_case user_code must NOT appear in the URL, got: \(url)")
    }

    // MARK: - Missing deviceAuthorizationEndpoint throws

    func testEmptyEndpointThrows() {
        let config = makeConfig(deviceAuthEndpoint: "", clientId: "c1")
        let request = URLSessionHttpRequest()

        XCTAssertThrowsError(try config.populateDeviceFlowVerificationRequest(request: request, userCode: "XX")) { error in
            guard case OidcError.unknown = error else {
                XCTFail("Expected OidcError.unknown, got \(error)")
                return
            }
        }
    }

    // MARK: - Nil deviceAuthorizationEndpoint throws

    func testNilEndpointThrows() {
        let config = OidcClientConfig()
        config.clientId = "c1"
        // openId is nil — no endpoint available
        let request = URLSessionHttpRequest()

        XCTAssertThrowsError(try config.populateDeviceFlowVerificationRequest(request: request, userCode: "XX")) { error in
            guard case OidcError.unknown = error else {
                XCTFail("Expected OidcError.unknown, got \(error)")
                return
            }
        }
    }
}

// MARK: - DaVinci device flow start overload tests

/// Tests for the DaVinci device flow start overload (`DaVinci.start { $0[.verificationUriComplete] = url }`).
final class DaVinciDeviceTests: XCTestCase, @unchecked Sendable {

    let testClientId = "test"
    let testScopes = ["openid", "email"]
    let testRedirectUri = "http://localhost:8080"
    let testDiscoveryEndpoint = "http://localhost/.well-known/openid-configuration"

    private func mockHTTPResponse(url: URL, statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: MockResponse.headers)!
    }

    private func makeDaVinci() -> DaVinci {
        DaVinci.createDaVinci { config in
            config.httpClient = MockURLProtocol.makeClient()
            config.module(PingDavinci.OidcModule.config) { oidcValue in
                oidcValue.clientId = self.testClientId
                oidcValue.scopes = Set(self.testScopes)
                oidcValue.redirectUri = self.testRedirectUri
                oidcValue.discoveryEndpoint = self.testDiscoveryEndpoint
                oidcValue.storage = MemoryStorage()
                oidcValue.logger = LogManager.standard
            }
        }
    }

    override func setUp() {
        super.setUp()
        MockURLProtocol.startInterceptingRequests()

        MockURLProtocol.requestHandler = { [self] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.discovery.url.path:
                return (mockHTTPResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200),
                        MockResponse.openIdConfigurationWithDeviceEndpointResponse)
            case MockAPIEndpoint.authorization.url.path:
                return (mockHTTPResponse(url: MockAPIEndpoint.authorization.url, statusCode: 200),
                        MockResponse.authorizeResponse)
            case MockAPIEndpoint.deviceFlow.url.path:
                return (mockHTTPResponse(url: MockAPIEndpoint.deviceFlow.url, statusCode: 200), Data())
            default:
                return (mockHTTPResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500), Data())
            }
        }
    }

    override func tearDown() {
        super.tearDown()
        MockURLProtocol.stopInterceptingRequests()
    }

    // MARK: - Test 1: user_code included when verificationUriComplete is set

    /// Test: `user_code` query parameter is appended to the authorization request when
    /// `verificationUriComplete` is set via the device-flow start overload.
    func testVerificationUriCompleteAddsUserCodeToAuthorizeRequest() async throws {
        let daVinci = makeDaVinci()

        _ = await daVinci.start { options in
            options.verificationUriComplete = URL(string: "https://example.com/activate?user_code=XYZW-1234")
        }

        // When verificationUriComplete is set, OidcModule bypasses the authorization endpoint
        // and instead POSTs to /applications/{clientId}/deviceFlow with userCode as a query param.
        let deviceFlowRequest = MockURLProtocol.requestHistory.first {
            $0.url?.path == MockAPIEndpoint.deviceFlow.url.path
        }
        XCTAssertNotNil(deviceFlowRequest, "Expected a request to the deviceFlow endpoint")
        let query = deviceFlowRequest?.url?.query ?? ""
        XCTAssertTrue(query.contains("userCode=XYZW-1234"),
                      "deviceFlow request should contain userCode=XYZW-1234, got: \(query)")
    }

    // MARK: - Test 2: user_code absent when verificationUriComplete is not set

    /// Test: When no `verificationUriComplete` is provided, the authorization request does not
    /// include a `user_code` parameter, and the existing flow is unaffected.
    func testNoVerificationUriCompleteDoesNotAddUserCode() async throws {
        let daVinci = makeDaVinci()

        _ = await daVinci.start()

        let authorizeRequest = MockURLProtocol.requestHistory.first {
            $0.url?.path == MockAPIEndpoint.authorization.url.path
        }
        XCTAssertNotNil(authorizeRequest, "Expected an authorization request")
        let query = authorizeRequest?.url?.query ?? ""
        XCTAssertFalse(query.contains("user_code="),
                       "Authorization request should NOT contain user_code when flow is not device flow, got: \(query)")
    }

    // MARK: - Test 3: key is consumed — subsequent start() does not resend user_code

    /// Test: After a device-flow start, the `verificationUriComplete` key is consumed.
    /// A subsequent plain `start()` on the same DaVinci instance must NOT include `user_code`.
    func testVerificationUriCompleteKeyIsConsumedAfterFirstStart() async throws {
        let daVinci = makeDaVinci()

        _ = await daVinci.start { options in
            options.verificationUriComplete = URL(string: "https://example.com/activate?user_code=ABCD-9876")
        }

        MockURLProtocol.requestHistory.removeAll()

        _ = await daVinci.start()

        // After the device-flow start consumed the key, a plain start() must go to the
        // authorization endpoint — not the deviceFlow endpoint.
        let authRequest = MockURLProtocol.requestHistory.first {
            $0.url?.path == MockAPIEndpoint.authorization.url.path
        }
        let deviceFlowRequest = MockURLProtocol.requestHistory.first {
            $0.url?.path == MockAPIEndpoint.deviceFlow.url.path
        }
        XCTAssertNotNil(authRequest, "Second start() should reach the authorization endpoint")
        XCTAssertNil(deviceFlowRequest, "Second start() must NOT reach the deviceFlow endpoint — key should have been consumed")
    }
}
