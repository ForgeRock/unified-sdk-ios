//
//  OidcClientPARTests.swift
//  OidcTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingOidc
@testable import PingNetwork
@testable import PingLogger
@testable import PingStorage
@testable import PingOrchestrate

// MARK: - PAR (Pushed Authorization Request) Tests

/// Helper to read httpBodyStream data from URLRequest (httpBody is nil when using URLSession with URLProtocol)
private func bodyData(from request: URLRequest) -> Data {
    if let body = request.httpBody {
        return body
    }
    guard let stream = request.httpBodyStream else {
        return Data()
    }
    stream.open()
    defer { stream.close() }
    var data = Data()
    let bufferSize = 4096
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }
    while stream.hasBytesAvailable {
        let bytesRead = stream.read(buffer, maxLength: bufferSize)
        if bytesRead > 0 {
            data.append(buffer, count: bytesRead)
        } else {
            break
        }
    }
    return data
}

final class OidcClientPARTests: XCTestCase {
    
    var oidcClientConfig: OidcClientConfig!
    
    static let parEndpointURL = URL(string: "\(MockAPIEndpoint.baseURL)/par")!
    
    /// OpenID configuration JSON that includes the PAR endpoint.
    static var openIdConfigurationWithPAR: Data {
        """
        {
          "authorization_endpoint" : "\(MockAPIEndpoint.authorization.url.absoluteString)",
          "token_endpoint" : "\(MockAPIEndpoint.token.url.absoluteString)",
          "userinfo_endpoint" : "\(MockAPIEndpoint.userinfo.url.absoluteString)",
          "end_session_endpoint" : "\(MockAPIEndpoint.endSession.url.absoluteString)",
          "revocation_endpoint" : "\(MockAPIEndpoint.revocation.url.absoluteString)",
          "pushed_authorization_request_endpoint" : "\(parEndpointURL.absoluteString)"
        }
        """.data(using: .utf8)!
    }
    
    /// Successful PAR response containing a request_uri.
    static var parResponse: Data {
        """
        {
          "request_uri" : "urn:ietf:params:oauth:request_uri:test-request-uri",
          "expires_in" : 60
        }
        """.data(using: .utf8)!
    }
    
    override func setUp() {
        super.setUp()
        oidcClientConfig = OidcClientConfig()
        oidcClientConfig.clientId = "test-client"
        oidcClientConfig.scopes = Set(["openid", "email"])
        oidcClientConfig.redirectUri = "http://localhost:8080/callback"
        oidcClientConfig.discoveryEndpoint = MockAPIEndpoint.discovery.url.absoluteString
        oidcClientConfig.storage = MockStorage<Token>()
        oidcClientConfig.httpClient = MockURLProtocol.makeClient()
        MockURLProtocol.startInterceptingRequests()
    }
    
    override func tearDown() {
        oidcClientConfig = nil
        MockURLProtocol.stopInterceptingRequests()
        super.tearDown()
    }
    
    /// Creates an `HTTPURLResponse` or throws, replacing force-unwrap (`!`) in mock handlers.
    private func mockResponse(url: URL, statusCode: Int, headers: [String: String]? = nil) throws -> HTTPURLResponse {
        guard let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: headers) else {
            throw URLError(.badServerResponse)
        }
        return response
    }
    
    /// Returns a 500 response for an unexpected request URL, falling back to the discovery URL
    /// when the inbound request has no URL.
    private func unexpectedResponse(for request: URLRequest) throws -> (HTTPURLResponse, Data) {
        XCTFail("Unexpected request: \(request.url?.path ?? "<no url>")")
        return (try mockResponse(url: request.url ?? MockAPIEndpoint.discovery.url, statusCode: 500), Data())
    }
    
    // MARK: - populateRequest Tests
    
    func testPopulateRequestWithPAREnabled() async throws {
        // Configure PAR
        oidcClientConfig.par = true
        
        // Set up mock handler
        MockURLProtocol.requestHandler = { [self] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.discovery.url.path:
                return (try mockResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, headers: MockResponse.headers), OidcClientPARTests.openIdConfigurationWithPAR)
            case OidcClientPARTests.parEndpointURL.path:
                return (try mockResponse(url: OidcClientPARTests.parEndpointURL, statusCode: 201, headers: MockResponse.headers), OidcClientPARTests.parResponse)
            default:
                return try unexpectedResponse(for: request)
            }
        }
        
        // Initialize OIDC to load the discovery document
        try await oidcClientConfig.oidcInitialize()
        
        let pkce = Pkce.generate()
        let httpClient = try XCTUnwrap(oidcClientConfig.httpClient, "HTTP client should be configured")
        var request = httpClient.request()
        
        request = try await oidcClientConfig.populateRequest(request: request, pkce: pkce, responseMode: "pi.flow")
        
        // Verify PAR request was made (request 0 = discovery, request 1 = PAR POST)
        XCTAssertEqual(MockURLProtocol.requestHistory.count, 2)
        
        let parRequest = MockURLProtocol.requestHistory[1]
        let parUrl = try XCTUnwrap(parRequest.url, "PAR request should have a URL")
        XCTAssertEqual(parUrl.path, "/par")
        XCTAssertEqual(parRequest.httpMethod, "POST")
        
        // Verify PAR POST body contains the expected form parameters
        let parBody = String(data: bodyData(from: parRequest), encoding: .utf8) ?? ""
        XCTAssertTrue(parBody.contains("client_id=test-client"), "PAR body should contain client_id")
        XCTAssertTrue(parBody.contains("response_type=code"), "PAR body should contain response_type")
        XCTAssertTrue(parBody.contains("code_challenge="), "PAR body should contain code_challenge")
        XCTAssertTrue(parBody.contains("code_challenge_method=S256"), "PAR body should contain code_challenge_method")
        XCTAssertTrue(parBody.contains("redirect_uri="), "PAR body should contain redirect_uri")
        XCTAssertTrue(parBody.contains("response_mode=pi.flow"), "PAR body should contain response_mode")
        
        // Verify the resulting authorize request URL uses request_uri (not full params)
        let authorizeUrl = try XCTUnwrap(request.url, "Populated request should have a URL")
        XCTAssertTrue(authorizeUrl.contains(MockAPIEndpoint.authorization.url.absoluteString), "Authorize URL should point to authorization endpoint")
        XCTAssertTrue(authorizeUrl.contains("request_uri="), "Authorize URL should contain request_uri parameter")
        XCTAssertTrue(authorizeUrl.contains("client_id=test-client"), "Authorize URL should contain client_id")
        XCTAssertTrue(authorizeUrl.contains("response_mode=pi.flow"), "Authorize URL should contain response_mode")
        
        // Verify the authorize URL does NOT contain full OIDC params (they were sent via PAR)
        XCTAssertFalse(authorizeUrl.contains("code_challenge="), "Authorize URL should NOT contain code_challenge when PAR is used")
        XCTAssertFalse(authorizeUrl.contains("response_type="), "Authorize URL should NOT contain response_type when PAR is used")
        XCTAssertFalse(authorizeUrl.contains("scope="), "Authorize URL should NOT contain scope when PAR is used")
    }
    
    func testPopulateRequestWithPARDisabled() async throws {
        // PAR is disabled by default
        XCTAssertFalse(oidcClientConfig.par)
        
        MockURLProtocol.requestHandler = { [self] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.discovery.url.path:
                return (try mockResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, headers: MockResponse.headers), OidcClientPARTests.openIdConfigurationWithPAR)
            default:
                return try unexpectedResponse(for: request)
            }
        }
        
        try await oidcClientConfig.oidcInitialize()
        
        let pkce = Pkce.generate()
        let httpClient = try XCTUnwrap(oidcClientConfig.httpClient, "HTTP client should be configured")
        var request = httpClient.request()
        
        request = try await oidcClientConfig.populateRequest(request: request, pkce: pkce, responseMode: "pi.flow")
        
        // Only discovery request should have been made (no PAR request)
        XCTAssertEqual(MockURLProtocol.requestHistory.count, 1)
        
        // Verify the authorize URL contains full OIDC params (standard flow)
        let authorizeUrl = try XCTUnwrap(request.url, "Populated request should have a URL")
        XCTAssertTrue(authorizeUrl.contains("client_id=test-client"))
        XCTAssertTrue(authorizeUrl.contains("response_type=code"))
        XCTAssertTrue(authorizeUrl.contains("code_challenge="))
        XCTAssertTrue(authorizeUrl.contains("code_challenge_method=S256"))
        XCTAssertTrue(authorizeUrl.contains("response_mode=pi.flow"))
        XCTAssertFalse(authorizeUrl.contains("request_uri="), "Standard flow should NOT use request_uri")
    }
    
    func testPopulateRequestPARWithEmptyResponseMode() async throws {
        oidcClientConfig.par = true
        
        MockURLProtocol.requestHandler = { [self] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.discovery.url.path:
                return (try mockResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, headers: MockResponse.headers), OidcClientPARTests.openIdConfigurationWithPAR)
            case OidcClientPARTests.parEndpointURL.path:
                return (try mockResponse(url: OidcClientPARTests.parEndpointURL, statusCode: 201, headers: MockResponse.headers), OidcClientPARTests.parResponse)
            default:
                return try unexpectedResponse(for: request)
            }
        }
        
        try await oidcClientConfig.oidcInitialize()
        
        let pkce = Pkce.generate()
        let httpClient = try XCTUnwrap(oidcClientConfig.httpClient, "HTTP client should be configured")
        var request = httpClient.request()
        
        // Empty responseMode (as used by Journey)
        request = try await oidcClientConfig.populateRequest(request: request, pkce: pkce, responseMode: "")
        
        // Verify PAR body does NOT contain response_mode when empty
        let parRequest = MockURLProtocol.requestHistory[1]
        let parBody = String(data: bodyData(from: parRequest), encoding: .utf8) ?? ""
        XCTAssertFalse(parBody.contains("response_mode"), "PAR body should NOT contain response_mode when empty")
        
        // Verify authorize URL does NOT contain response_mode when empty
        let authorizeUrl = try XCTUnwrap(request.url, "Populated request should have a URL")
        XCTAssertFalse(authorizeUrl.contains("response_mode"), "Authorize URL should NOT contain response_mode when empty")
        XCTAssertTrue(authorizeUrl.contains("request_uri="), "Authorize URL should contain request_uri")
    }
    
    func testPopulateRequestPARFailure() async throws {
        oidcClientConfig.par = true
        
        MockURLProtocol.requestHandler = { [self] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.discovery.url.path:
                return (try mockResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, headers: MockResponse.headers), OidcClientPARTests.openIdConfigurationWithPAR)
            case OidcClientPARTests.parEndpointURL.path:
                // PAR endpoint returns 400 error
                let errorResponse = Data("""
                {"error": "invalid_request", "error_description": "Invalid client"}
                """.utf8)
                return (try mockResponse(url: OidcClientPARTests.parEndpointURL, statusCode: 400, headers: MockResponse.headers), errorResponse)
            default:
                return try unexpectedResponse(for: request)
            }
        }
        
        try await oidcClientConfig.oidcInitialize()
        
        let pkce = Pkce.generate()
        let httpClient = try XCTUnwrap(oidcClientConfig.httpClient, "HTTP client should be configured")
        var request = httpClient.request()
        
        do {
            request = try await oidcClientConfig.populateRequest(request: request, pkce: pkce, responseMode: "pi.flow")
            XCTFail("Should have thrown an error for PAR failure")
        } catch let error as OidcError {
            // Verify the error is an API error
            if case .apiError(_, let message) = error {
                XCTAssertTrue(message.contains("Failed to create PAR request"), "Error should mention PAR request failure")
            } else {
                XCTFail("Expected apiError, got: \(error)")
            }
        }
    }
    
    func testPopulateRequestPARMissingRequestUri() async throws {
        oidcClientConfig.par = true
        
        MockURLProtocol.requestHandler = { [self] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.discovery.url.path:
                return (try mockResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, headers: MockResponse.headers), OidcClientPARTests.openIdConfigurationWithPAR)
            case OidcClientPARTests.parEndpointURL.path:
                // PAR endpoint returns 200 but without request_uri
                let badResponse = Data("""
                {"expires_in": 60}
                """.utf8)
                return (try mockResponse(url: OidcClientPARTests.parEndpointURL, statusCode: 200, headers: MockResponse.headers), badResponse)
            default:
                return try unexpectedResponse(for: request)
            }
        }
        
        try await oidcClientConfig.oidcInitialize()
        
        let pkce = Pkce.generate()
        let httpClient = try XCTUnwrap(oidcClientConfig.httpClient, "HTTP client should be configured")
        var request = httpClient.request()
        
        do {
            request = try await oidcClientConfig.populateRequest(request: request, pkce: pkce, responseMode: "pi.flow")
            XCTFail("Should have thrown an error for missing request_uri")
        } catch let error as OidcError {
            if case .authorizeError(_, let message) = error {
                XCTAssertTrue(message?.contains("request_uri") ?? false, "Error should mention missing request_uri")
            } else {
                XCTFail("Expected authorizeError, got: \(error)")
            }
        }
    }
    
    func testPopulateRequestPARFallsBackWhenNoPAREndpoint() async throws {
        // PAR is enabled but discovery does NOT include PAR endpoint
        oidcClientConfig.par = true
        
        MockURLProtocol.requestHandler = { [self] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.discovery.url.path:
                // Standard discovery without PAR endpoint
                return (try mockResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, headers: MockResponse.headers), MockResponse.openIdConfiguration)
            default:
                return try unexpectedResponse(for: request)
            }
        }
        
        try await oidcClientConfig.oidcInitialize()
        
        let pkce = Pkce.generate()
        let httpClient = try XCTUnwrap(oidcClientConfig.httpClient, "HTTP client should be configured")
        var request = httpClient.request()
        
        request = try await oidcClientConfig.populateRequest(request: request, pkce: pkce, responseMode: "pi.flow")
        
        // Only discovery request - no PAR request since endpoint is missing
        XCTAssertEqual(MockURLProtocol.requestHistory.count, 1)
        
        // Falls back to standard flow
        let authorizeUrl = try XCTUnwrap(request.url, "Populated request should have a URL")
        XCTAssertTrue(authorizeUrl.contains("client_id=test-client"))
        XCTAssertTrue(authorizeUrl.contains("response_type=code"))
        XCTAssertTrue(authorizeUrl.contains("code_challenge="))
        XCTAssertFalse(authorizeUrl.contains("request_uri="), "Should not use request_uri when PAR endpoint is missing")
    }
    
    // MARK: - generateAuthorizeUrl Tests
    
    func testGenerateAuthorizeUrlWithPAR() async throws {
        oidcClientConfig.par = true
        
        MockURLProtocol.requestHandler = { [self] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.discovery.url.path:
                return (try mockResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, headers: MockResponse.headers), OidcClientPARTests.openIdConfigurationWithPAR)
            case OidcClientPARTests.parEndpointURL.path:
                return (try mockResponse(url: OidcClientPARTests.parEndpointURL, statusCode: 201, headers: MockResponse.headers), OidcClientPARTests.parResponse)
            default:
                return try unexpectedResponse(for: request)
            }
        }
        
        try await oidcClientConfig.oidcInitialize()
        
        let oidcClient = OidcClient(config: oidcClientConfig)
        let url = try await oidcClient.generateAuthorizeUrl()
        
        let urlString = url.absoluteString
        XCTAssertTrue(urlString.contains("request_uri="), "Authorize URL should contain request_uri")
        XCTAssertTrue(urlString.contains("client_id=test-client"), "Authorize URL should contain client_id")
        XCTAssertFalse(urlString.contains("code_challenge="), "Authorize URL should NOT contain code_challenge")
    }
    
    func testGenerateAuthorizeUrlWithPARAndCustomParams() async throws {
        oidcClientConfig.par = true
        
        MockURLProtocol.requestHandler = { [self] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.discovery.url.path:
                return (try mockResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, headers: MockResponse.headers), OidcClientPARTests.openIdConfigurationWithPAR)
            case OidcClientPARTests.parEndpointURL.path:
                return (try mockResponse(url: OidcClientPARTests.parEndpointURL, statusCode: 201, headers: MockResponse.headers), OidcClientPARTests.parResponse)
            default:
                return try unexpectedResponse(for: request)
            }
        }
        
        try await oidcClientConfig.oidcInitialize()
        
        let oidcClient = OidcClient(config: oidcClientConfig)
        let url = try await oidcClient.generateAuthorizeUrl(customParams: ["custom_key": "custom_value"])

        let urlString = url.absoluteString
        XCTAssertTrue(urlString.contains("request_uri="), "Authorize URL should contain request_uri")
        XCTAssertTrue(urlString.contains("custom_key=custom_value"), "Authorize URL should contain custom parameters")
    }

    /// Regression test for a bug where `generateAuthorizeUrl` never called `oidcInitialize()`
    /// itself, so a config with `par = true` but no prior discovery (`openId == nil`) silently
    /// fell back to the standard, non-PAR flow — emitting every `additionalParameters` value
    /// (e.g. a sensitive token meant only for the PAR POST body) onto the returned URL's query
    /// string instead. `httpClient` is already set directly in `setUp()`, matching a caller that
    /// reuses an already-configured HTTP client for a second, standalone `OidcClientConfig`
    /// without separately calling `oidcInitialize()`.
    func testGenerateAuthorizeUrlSelfInitializesWhenOidcInitializeNotCalledExplicitly() async throws {
        oidcClientConfig.par = true
        oidcClientConfig.additionalParameters = ["access_token_hint": "super-secret-token"]

        MockURLProtocol.requestHandler = { [self] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.discovery.url.path:
                return (try mockResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, headers: MockResponse.headers), OidcClientPARTests.openIdConfigurationWithPAR)
            case OidcClientPARTests.parEndpointURL.path:
                return (try mockResponse(url: OidcClientPARTests.parEndpointURL, statusCode: 201, headers: MockResponse.headers), OidcClientPARTests.parResponse)
            default:
                return try unexpectedResponse(for: request)
            }
        }

        // Precondition: discovery has NOT run yet — this is the exact state that used to cause
        // the silent fallback.
        XCTAssertNil(oidcClientConfig.openId, "Precondition: discovery must not have run yet")

        let oidcClient = OidcClient(config: oidcClientConfig)
        let url = try await oidcClient.generateAuthorizeUrl()

        let urlString = url.absoluteString
        XCTAssertTrue(urlString.contains("request_uri="), "generateAuthorizeUrl should self-initialize and use PAR even when oidcInitialize() was never called explicitly")
        XCTAssertFalse(urlString.contains("access_token_hint="), "Sensitive additionalParameters must never leak onto the URL when PAR is enabled")

        // Verify the sensitive value actually went into the PAR POST body, not skipped entirely.
        let parRequest = MockURLProtocol.requestHistory[1]
        let parBody = String(data: bodyData(from: parRequest), encoding: .utf8) ?? ""
        XCTAssertTrue(parBody.contains("access_token_hint=super-secret-token"), "additionalParameters should be sent in the PAR POST body")
    }

    /// Regression test for the *other* half of the same bug: before this fix, calling the async
    /// `generateAuthorizeUrl()` without a prior `oidcInitialize()` call — with `par` left at its
    /// default `false` — still produced a URL with an empty authorization endpoint
    /// (`openId?.authorizationEndpoint ?? ""`), since `openId` had never been populated. This is
    /// not a PAR-specific bug: self-initializing fixes the plain standard-flow path too.
    func testGenerateAuthorizeUrlStandardFlowSelfInitializesWhenOidcInitializeNotCalledExplicitly() async throws {
        // par is false by default
        XCTAssertFalse(oidcClientConfig.par)

        MockURLProtocol.requestHandler = { [self] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.discovery.url.path:
                return (try mockResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, headers: MockResponse.headers), OidcClientPARTests.openIdConfigurationWithPAR)
            default:
                return try unexpectedResponse(for: request)
            }
        }

        XCTAssertNil(oidcClientConfig.openId, "Precondition: discovery must not have run yet")

        let oidcClient = OidcClient(config: oidcClientConfig)
        let url = try await oidcClient.generateAuthorizeUrl()

        let urlString = url.absoluteString
        XCTAssertTrue(urlString.contains(MockAPIEndpoint.authorization.url.absoluteString), "generateAuthorizeUrl should self-initialize so the URL points at the real authorization endpoint, not an empty one")
        XCTAssertTrue(urlString.contains("client_id=test-client"))
        XCTAssertTrue(urlString.contains("code_challenge="))
    }

    /// Lock-in test: the *synchronous* `generateAuthorizeUrl(customParams:) throws -> URL`
    /// overload never supports PAR, even when `par = true` and discovery has already populated a
    /// real PAR endpoint — this is documented behavior (see the `- Warning:` on that overload)
    /// that this fix does not touch and must not accidentally start supporting.
    func testSyncGenerateAuthorizeUrlIgnoresParEvenWhenEnabled() async throws {
        oidcClientConfig.par = true

        MockURLProtocol.requestHandler = { [self] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.discovery.url.path:
                return (try mockResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, headers: MockResponse.headers), OidcClientPARTests.openIdConfigurationWithPAR)
            default:
                return try unexpectedResponse(for: request)
            }
        }

        // Populate discovery (including a real PAR endpoint) so this test proves the sync
        // overload ignores PAR on principle, not merely because none was configured.
        try await oidcClientConfig.oidcInitialize()
        XCTAssertNotNil(oidcClientConfig.openId?.pushedAuthorizationRequestEndpoint, "Precondition: a PAR endpoint must be discovered")

        let oidcClient = OidcClient(config: oidcClientConfig)
        // Explicitly typed as the non-async signature: an unqualified call here would resolve to
        // the async overload instead (Swift prefers `async` when calling from an `async` context),
        // defeating the point of this test.
        let syncGenerateAuthorizeUrl: ([String: String]?) throws -> URL = oidcClient.generateAuthorizeUrl
        let url = try syncGenerateAuthorizeUrl(nil)

        let urlString = url.absoluteString
        XCTAssertTrue(urlString.contains(MockAPIEndpoint.authorization.url.absoluteString), "Sync overload should build the standard authorize URL")
        XCTAssertTrue(urlString.contains("code_challenge="), "Sync overload should never use PAR, even when par = true")
        XCTAssertFalse(urlString.contains("request_uri="), "Sync overload should never use PAR, even when par = true")

        // Only the discovery request from oidcInitialize() above should have been made — the sync
        // overload itself must never hit the PAR endpoint.
        XCTAssertEqual(MockURLProtocol.requestHistory.count, 1, "Sync overload must not hit the PAR endpoint")
    }

    func testPopulateRequestPARWithAdditionalOidcParameters() async throws {
        oidcClientConfig.par = true
        oidcClientConfig.acrValues = "urn:acr:test"
        oidcClientConfig.loginHint = "user@example.com"
        oidcClientConfig.nonce = "test-nonce"
        
        MockURLProtocol.requestHandler = { [self] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.discovery.url.path:
                return (try mockResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, headers: MockResponse.headers), OidcClientPARTests.openIdConfigurationWithPAR)
            case OidcClientPARTests.parEndpointURL.path:
                return (try mockResponse(url: OidcClientPARTests.parEndpointURL, statusCode: 201, headers: MockResponse.headers), OidcClientPARTests.parResponse)
            default:
                return try unexpectedResponse(for: request)
            }
        }
        
        try await oidcClientConfig.oidcInitialize()
        
        let pkce = Pkce.generate()
        let httpClient = try XCTUnwrap(oidcClientConfig.httpClient, "HTTP client should be configured")
        var request = httpClient.request()
        
        request = try await oidcClientConfig.populateRequest(request: request, pkce: pkce, responseMode: "pi.flow")
        
        // Verify additional OIDC params are sent in the PAR POST body (not on the URL)
        let parRequest = MockURLProtocol.requestHistory[1]
        let parBody = String(data: bodyData(from: parRequest), encoding: .utf8) ?? ""
        XCTAssertTrue(parBody.contains("acr_values="), "PAR body should contain acr_values")
        XCTAssertTrue(parBody.contains("login_hint="), "PAR body should contain login_hint")
        XCTAssertTrue(parBody.contains("nonce=test-nonce"), "PAR body should contain nonce")
        
        // Verify the authorize URL only has the minimal params
        let authorizeUrl = try XCTUnwrap(request.url, "Populated request should have a URL")
        XCTAssertFalse(authorizeUrl.contains("acr_values="), "Authorize URL should NOT contain acr_values when PAR is used")
        XCTAssertFalse(authorizeUrl.contains("login_hint="), "Authorize URL should NOT contain login_hint when PAR is used")
        XCTAssertFalse(authorizeUrl.contains("nonce="), "Authorize URL should NOT contain nonce when PAR is used")
    }
    
    // MARK: - state parameter behavior
    
    /// Standard (non-PAR) flow: `state` must be present on the authorize URL,
    /// defaulting to the PKCE-generated state when the integrator did not set
    /// `OidcClientConfig.state` explicitly.
    func testStandardFlowAlwaysSendsStateDefaultingToPkceState() async throws {
        MockURLProtocol.requestHandler = { [self] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.discovery.url.path:
                return (try mockResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, headers: MockResponse.headers), OidcClientPARTests.openIdConfigurationWithPAR)
            default:
                return try unexpectedResponse(for: request)
            }
        }
        
        try await oidcClientConfig.oidcInitialize()
        
        let pkce = Pkce.generate()
        let httpClient = try XCTUnwrap(oidcClientConfig.httpClient, "HTTP client should be configured")
        var request = httpClient.request()
        request = try await oidcClientConfig.populateRequest(request: request, pkce: pkce, responseMode: "pi.flow")
        
        let authorizeUrl = try XCTUnwrap(request.url, "Populated request should have a URL")
        XCTAssertTrue(authorizeUrl.contains("state=\(pkce.state)"), "Authorize URL should contain state=<pkce.state>")
    }
    
    /// Standard (non-PAR) flow: an integrator-supplied `OidcClientConfig.state`
    /// takes precedence over `pkce.state`.
    func testStandardFlowConfigStateOverridesPkceState() async throws {
        oidcClientConfig.state = "integrator-state"
        
        MockURLProtocol.requestHandler = { [self] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.discovery.url.path:
                return (try mockResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, headers: MockResponse.headers), OidcClientPARTests.openIdConfigurationWithPAR)
            default:
                return try unexpectedResponse(for: request)
            }
        }
        
        try await oidcClientConfig.oidcInitialize()
        
        let pkce = Pkce.generate()
        let httpClient = try XCTUnwrap(oidcClientConfig.httpClient, "HTTP client should be configured")
        var request = httpClient.request()
        request = try await oidcClientConfig.populateRequest(request: request, pkce: pkce, responseMode: "pi.flow")
        
        let authorizeUrl = try XCTUnwrap(request.url, "Populated request should have a URL")
        XCTAssertTrue(authorizeUrl.contains("state=integrator-state"), "Authorize URL should use integrator-supplied state")
        XCTAssertFalse(authorizeUrl.contains("state=\(pkce.state)"), "Authorize URL should NOT fall back to pkce.state when config.state is set")
    }
    
    /// PAR flow: `state` must be present in the PAR POST body, defaulting to
    /// the PKCE-generated state.
    func testPARFlowSendsStateInPARBodyDefaultingToPkceState() async throws {
        oidcClientConfig.par = true
        
        MockURLProtocol.requestHandler = { [self] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.discovery.url.path:
                return (try mockResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, headers: MockResponse.headers), OidcClientPARTests.openIdConfigurationWithPAR)
            case OidcClientPARTests.parEndpointURL.path:
                return (try mockResponse(url: OidcClientPARTests.parEndpointURL, statusCode: 201, headers: MockResponse.headers), OidcClientPARTests.parResponse)
            default:
                return try unexpectedResponse(for: request)
            }
        }
        
        try await oidcClientConfig.oidcInitialize()
        
        let pkce = Pkce.generate()
        let httpClient = try XCTUnwrap(oidcClientConfig.httpClient, "HTTP client should be configured")
        var request = httpClient.request()
        request = try await oidcClientConfig.populateRequest(request: request, pkce: pkce, responseMode: "pi.flow")
        
        let parRequest = MockURLProtocol.requestHistory[1]
        let parBody = String(data: bodyData(from: parRequest), encoding: .utf8) ?? ""
        XCTAssertTrue(parBody.contains("state=\(pkce.state)"), "PAR body should contain state=<pkce.state>")
        
        // The authorize URL after PAR carries only request_uri/client_id/response_mode,
        // so state should NOT leak into it.
        let authorizeUrl = try XCTUnwrap(request.url, "Populated request should have a URL")
        XCTAssertFalse(authorizeUrl.contains("state="), "Authorize URL should NOT contain state when PAR is used")
    }
}
