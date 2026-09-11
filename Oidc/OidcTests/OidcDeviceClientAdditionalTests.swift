//
//  OidcDeviceClientAdditionalTests.swift
//  OidcTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//
//  QA-authored tests for SDKS-4785 covering edge cases not addressed by existing suite.

import XCTest
@testable import PingOidc
@testable import PingNetwork

class OidcDeviceClientAdditionalTests: XCTestCase {

    // MARK: - Helpers

    private func makeOpenIdConfig(includeDeviceEndpoint: Bool = true) -> OpenIdConfiguration {
        OpenIdConfiguration(
            authorizationEndpoint: MockAPIEndpoint.authorization.url.absoluteString,
            tokenEndpoint: MockAPIEndpoint.token.url.absoluteString,
            userinfoEndpoint: MockAPIEndpoint.userinfo.url.absoluteString,
            endSessionEndpoint: MockAPIEndpoint.endSession.url.absoluteString,
            revocationEndpoint: MockAPIEndpoint.revocation.url.absoluteString,
            deviceAuthorizationEndpoint: includeDeviceEndpoint
                ? MockAPIEndpoint.deviceAuthorization.url.absoluteString
                : nil
        )
    }

    private func makeConfig(includeDeviceEndpoint: Bool = true) -> OidcClientConfig {
        let config = OidcClientConfig()
        config.clientId = "qa-client-id"
        config.scopes = Set(["openid", "profile"])
        config.redirectUri = "org.forgerock.demo://oauth2redirect"
        config.storage = MockStorage<Token>()
        config.httpClient = MockURLProtocol.makeClient()
        config.openId = makeOpenIdConfig(includeDeviceEndpoint: includeDeviceEndpoint)
        return config
    }

    private func mockHTTPResponse(url: URL, statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: MockResponse.headers
        )!
    }

    // MARK: - Edge Case 1: user() returns nil when no token is stored

    /// Verify `user()` returns nil when storage is empty.
    func testUserReturnsNilWhenStorageEmpty() async {
        let config = makeConfig()
        let client = OidcDeviceClient(config: config)
        let user = await client.user()
        XCTAssertNil(user, "user() must return nil when no token has been stored")
    }

    // MARK: - Edge Case 2: user() returns OidcUser after successful flow

    /// Verify `user()` returns a non-nil User after a token has been saved to storage.
    func testUserReturnsOidcUserAfterTokenStored() async throws {
        MockURLProtocol.startInterceptingRequests()
        defer { MockURLProtocol.stopInterceptingRequests() }

        nonisolated(unsafe) var tokenCallCount = 0

        MockURLProtocol.requestHandler = { [self] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.deviceAuthorization.url.path:
                return (mockHTTPResponse(url: MockAPIEndpoint.deviceAuthorization.url, statusCode: 200),
                        MockResponse.deviceAuthorizationResponseFastInterval)
            case MockAPIEndpoint.token.url.path:
                tokenCallCount += 1
                return (mockHTTPResponse(url: MockAPIEndpoint.token.url, statusCode: 200),
                        MockResponse.token)
            default:
                XCTFail("Unexpected request: \(request.url?.absoluteString ?? "<nil>")")
                return (mockHTTPResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500), Data())
            }
        }

        let config = makeConfig()
        let client = OidcDeviceClient(config: config)
        let stream = try await client.deviceAuthorization()

        for try await status in stream {
            if case .success = status { break }
        }

        let user = await client.user()
        XCTAssertNotNil(user, "user() must return a non-nil OidcUser after the device flow succeeds and saves a token")
    }

    // MARK: - Edge Case 3: deviceAuthorization() includes client_id and scope in POST body

    /// Verify the device authorization POST body contains client_id and scope parameters.
    func testDeviceAuthorizationPostBodyContainsClientIdAndScope() async throws {
        MockURLProtocol.startInterceptingRequests()
        defer { MockURLProtocol.stopInterceptingRequests() }

        MockURLProtocol.requestHandler = { [self] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.deviceAuthorization.url.path:
                return (mockHTTPResponse(url: MockAPIEndpoint.deviceAuthorization.url, statusCode: 200),
                        MockResponse.deviceAuthorizationResponseFastInterval)
            case MockAPIEndpoint.token.url.path:
                return (mockHTTPResponse(url: MockAPIEndpoint.token.url, statusCode: 400),
                        MockResponse.accessDenied)
            default:
                return (mockHTTPResponse(url: request.url ?? MockAPIEndpoint.discovery.url, statusCode: 500), Data())
            }
        }

        let config = makeConfig()
        let client = OidcDeviceClient(config: config)
        _ = try await client.deviceAuthorization()

        let deviceAuthRequest = MockURLProtocol.requestHistory.first {
            $0.url?.path == MockAPIEndpoint.deviceAuthorization.url.path
        }
        XCTAssertNotNil(deviceAuthRequest, "Expected a device authorization POST request")

        // Read POST body
        var bodyData = Data()
        if let data = deviceAuthRequest?.httpBody {
            bodyData = data
        } else if let stream = deviceAuthRequest?.httpBodyStream {
            stream.open()
            defer { stream.close() }
            let bufferSize = 4096
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }
            while stream.hasBytesAvailable {
                let n = stream.read(buffer, maxLength: bufferSize)
                if n > 0 { bodyData.append(buffer, count: n) }
            }
        }

        let bodyString = String(data: bodyData, encoding: .utf8) ?? ""
        XCTAssertTrue(bodyString.contains("client_id=qa-client-id"),
                      "Device auth POST body should contain client_id=qa-client-id, got: \(bodyString)")
        // scope contains openid and profile (order may vary)
        XCTAssertTrue(bodyString.contains("scope="),
                      "Device auth POST body should contain scope parameter, got: \(bodyString)")
    }

    // MARK: - Edge Case 4: interval=0 applies 5-second floor after URLError

    /// Verify that when the initial interval is 0 and a URLError occurs, the backoff
    /// floors at 5 seconds — i.e. min(max(0 * 2, 5), 60) = 5.
    func testBackoffIntervalIsNonNegativeWhenInitialIntervalIsZero() async throws {
        MockURLProtocol.startInterceptingRequests()
        defer { MockURLProtocol.stopInterceptingRequests() }

        nonisolated(unsafe) var tokenCallCount = 0

        MockURLProtocol.requestHandler = { [self] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.deviceAuthorization.url.path:
                return (mockHTTPResponse(url: MockAPIEndpoint.deviceAuthorization.url, statusCode: 200),
                        MockResponse.deviceAuthorizationResponseFastInterval) // interval = 0
            case MockAPIEndpoint.token.url.path:
                tokenCallCount += 1
                throw URLError(.timedOut)
            default:
                return (mockHTTPResponse(url: request.url ?? MockAPIEndpoint.discovery.url, statusCode: 500), Data())
            }
        }

        let config = makeConfig()
        let client = OidcDeviceClient(config: config)
        let stream = try await client.deviceAuthorization()

        var capturedInterval: Int? = nil
        outerLoop: for try await status in stream {
            switch status {
            case .polling(let count, let interval, _):
                capturedInterval = interval
                if count >= 1 { break outerLoop }
            case .started:
                break
            default:
                break outerLoop
            }
        }

        // min(max(0 * 2, 5), 60) = 5; the floor must be respected even when initial interval is 0
        if let interval = capturedInterval {
            XCTAssertGreaterThanOrEqual(interval, 5,
                "Backoff interval must be at least 5s even when initial interval is 0, got: \(interval)")
        }
    }

    // MARK: - Edge Case 5: unknown error code from token endpoint throws

    /// Verify that an unrecognized error code from the token endpoint causes the stream to throw.
    func testUnknownErrorCodeCausesStreamToThrow() async throws {
        MockURLProtocol.startInterceptingRequests()
        defer { MockURLProtocol.stopInterceptingRequests() }

        let unknownErrorBody = """
        {"error": "some_unknown_error_code"}
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { [self] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.deviceAuthorization.url.path:
                return (mockHTTPResponse(url: MockAPIEndpoint.deviceAuthorization.url, statusCode: 200),
                        MockResponse.deviceAuthorizationResponseFastInterval)
            case MockAPIEndpoint.token.url.path:
                return (mockHTTPResponse(url: MockAPIEndpoint.token.url, statusCode: 400),
                        unknownErrorBody)
            default:
                return (mockHTTPResponse(url: request.url ?? MockAPIEndpoint.discovery.url, statusCode: 500), Data())
            }
        }

        let config = makeConfig()
        let client = OidcDeviceClient(config: config)
        let stream = try await client.deviceAuthorization()

        var didThrow = false
        do {
            for try await _ in stream {}
        } catch {
            didThrow = true
        }

        XCTAssertTrue(didThrow,
            "An unknown error code from the token endpoint should cause the stream to throw")
    }

    // MARK: - Edge Case 6: DeviceAuthorizationResponse decodes interval=0

    /// Verify that interval=0 in the server response is preserved (not clamped to 5).
    func testIntervalZeroIsPreservedFromJSON() throws {
        let response = try JSONDecoder().decode(
            DeviceAuthorizationResponse.self,
            from: MockResponse.deviceAuthorizationResponseFastInterval
        )
        XCTAssertEqual(response.interval, 0,
            "interval=0 in server response should be decoded as 0, not defaulted to 5")
    }

    // MARK: - Edge Case 7: openIdConfiguration decodes device_authorization_endpoint

    /// Verify that `OpenIdConfiguration.deviceAuthorizationEndpoint` is decoded when present.
    func testOpenIdConfigurationDecodesDeviceAuthorizationEndpoint() throws {
        let json = """
        {
          "authorization_endpoint": "https://auth.example.com/authorize",
          "token_endpoint": "https://auth.example.com/token",
          "userinfo_endpoint": "https://auth.example.com/userinfo",
          "end_session_endpoint": "https://auth.example.com/signoff",
          "revocation_endpoint": "https://auth.example.com/revoke",
          "device_authorization_endpoint": "https://auth.example.com/device_authorization"
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(OpenIdConfiguration.self, from: json)
        XCTAssertEqual(
            config.deviceAuthorizationEndpoint,
            "https://auth.example.com/device_authorization",
            "OpenIdConfiguration should decode device_authorization_endpoint field"
        )
    }

    /// Verify that `OpenIdConfiguration.deviceAuthorizationEndpoint` is nil when absent.
    func testOpenIdConfigurationDeviceEndpointIsNilWhenAbsent() throws {
        let json = """
        {
          "authorization_endpoint": "https://auth.example.com/authorize",
          "token_endpoint": "https://auth.example.com/token",
          "userinfo_endpoint": "https://auth.example.com/userinfo",
          "end_session_endpoint": "https://auth.example.com/signoff",
          "revocation_endpoint": "https://auth.example.com/revoke"
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(OpenIdConfiguration.self, from: json)
        XCTAssertNil(
            config.deviceAuthorizationEndpoint,
            "OpenIdConfiguration.deviceAuthorizationEndpoint must be nil when absent from discovery response"
        )
    }

    // MARK: - Edge Case 7b: revoke() delegates to OidcClient

    /// Verify `revoke()` completes without error when no token is stored (nothing to revoke).
    func testRevokeWithNoStoredTokenCompletesWithoutError() async {
        let config = makeConfig()
        let client = OidcDeviceClient(config: config)
        // Should complete without throwing or crashing
        await client.revoke()
    }

    // MARK: - Edge Case 8: slow_down accumulates across multiple rounds

    /// Verify that two consecutive slow_down responses increase interval by 5 each time.
    func testSlowDownAccumulatesIntervalAcrossMultipleRounds() async throws {
        MockURLProtocol.startInterceptingRequests()
        defer { MockURLProtocol.stopInterceptingRequests() }

        nonisolated(unsafe) var tokenCallCount = 0

        MockURLProtocol.requestHandler = { [self] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.deviceAuthorization.url.path:
                // interval=0 so we start from 0 and accumulate
                return (mockHTTPResponse(url: MockAPIEndpoint.deviceAuthorization.url, statusCode: 200),
                        MockResponse.deviceAuthorizationResponseFastInterval)
            case MockAPIEndpoint.token.url.path:
                tokenCallCount += 1
                if tokenCallCount <= 2 {
                    return (mockHTTPResponse(url: MockAPIEndpoint.token.url, statusCode: 400),
                            MockResponse.slowDown)
                } else {
                    // Terminate with access_denied so the stream ends
                    return (mockHTTPResponse(url: MockAPIEndpoint.token.url, statusCode: 400),
                            MockResponse.accessDenied)
                }
            default:
                return (mockHTTPResponse(url: request.url ?? MockAPIEndpoint.discovery.url, statusCode: 500), Data())
            }
        }

        let config = makeConfig()
        let client = OidcDeviceClient(config: config)
        let stream = try await client.deviceAuthorization()

        var pollingIntervals: [Int] = []
        for try await status in stream {
            switch status {
            case .polling(_, let interval, _):
                pollingIntervals.append(interval)
            case .started, .accessDenied, .expired, .success, .failure:
                break
            }
        }

        // First slow_down: 0 + 5 = 5
        // Second slow_down: 5 + 5 = 10
        XCTAssertEqual(pollingIntervals.count, 2,
            "Expected 2 polling statuses from 2 slow_down responses, got \(pollingIntervals)")
        if pollingIntervals.count >= 2 {
            XCTAssertEqual(pollingIntervals[0], 5,
                "First slow_down should increase interval from 0 to 5")
            XCTAssertEqual(pollingIntervals[1], 10,
                "Second slow_down should increase interval from 5 to 10")
        }
    }
}
