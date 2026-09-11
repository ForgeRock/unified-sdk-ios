//
//  OidcClientTests.swift
//  OidcTests
//
//  Copyright (c) 2024 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingOidc
@testable import PingNetwork
@testable import PingStorage

final class OidcClientTests: XCTestCase {
    var oidcClientConfig: OidcClientConfig!
    var oidcClient: OidcClient!
    
    override func setUp() {
        super.setUp()
        oidcClientConfig = OidcClientConfig()
        let agent = MockAgent()
        oidcClientConfig.updateAgent(agent)
        oidcClientConfig.discoveryEndpoint = MockAPIEndpoint.discovery.url.absoluteString
        oidcClientConfig.storage = MockStorage<Token>()
        oidcClientConfig.clientId = "test-client-id"
        oidcClientConfig.httpClient = makeClient()
        oidcClient = OidcClient(config: oidcClientConfig)
        
        MockURLProtocol.startInterceptingRequests()
        
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
            case MockAPIEndpoint.token.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.token.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.token)
            case MockAPIEndpoint.userinfo.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.userinfo.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.userinfo)
            case MockAPIEndpoint.revocation.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.revocation.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, Data())
            case MockAPIEndpoint.endSession.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.endSession.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, Data())
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
    }
    
    override func tearDown() {
        MockURLProtocol.stopInterceptingRequests()
        
        oidcClient = nil
        oidcClientConfig = nil
        super.tearDown()
    }
    
    // TestRailCase(22118)
    func testFailedToLookupDiscoveryEndpoint() async throws {
        
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: MockResponse.headers)!, Data())
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        let result = await oidcClient.token()
        
        switch result {
        case .success(_):
            XCTFail("Should have failed with error")
        case .failure(let failure):
            switch failure {
            case .apiError(let code, _):
                XCTAssertEqual(code, 500)
            case .authorizeError, .networkError, .configurationError, .unknown:
                XCTFail("Should have failed with .apiError")
            }
        }
    }
    
    // TestRailCase(22085)
    func testAccessTokenShouldReturnCachedTokenIfNotExpired() async throws {
        let result = await oidcClient.token()
        switch result {
        case .success( _):
            break
        case .failure(_):
            XCTFail("Should have succeeded")
        }
        let cached = await oidcClient.token()
        switch cached {
        case .success( let token):
            XCTAssertEqual(token.accessToken, "Dummy AccessToken")
            XCTAssertEqual(token.tokenType, "Dummy Token Type")
            XCTAssertEqual(token.refreshToken, "Dummy RefreshToken")
            XCTAssertEqual(token.idToken, "Dummy IdToken")
            XCTAssertEqual(token.scope, "openid email address")
            break
        case .failure(let error):
            XCTFail("Should have succeeded, but failed with error \(error.errorMessage)")
        }
        
        XCTAssertEqual(MockURLProtocol.requestHistory.count, 2)
    }
    
    // TestRailCase(22086)
    func testAccessTokenShouldRefreshTokenIfExpired() async throws {
        let result = await oidcClient.token()
        switch result {
        case .success( _):
            break
        case .failure(_):
            XCTFail("Should have succeeded")
            return
        }
        
        // Advance time by 1 second
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        _ = await oidcClient.token()
        
        // auto refresh has been triggered
        XCTAssertEqual(MockURLProtocol.requestHistory.count, 3)
        XCTAssertEqual(Int(MockURLProtocol.requestHistory.last!.value(forHTTPHeaderField: "Content-Length")!), "grant_type=refresh_token&refresh_token=Dummy%20RefreshToken&client_id=test-client-id".count)
    }
    
    // TestRailCase(24712)
    func testRevokeShouldDeleteTokenFromStorage() async throws {
        // First, get an access token
        let result = await oidcClient.token()
        switch result {
        case .success( _):
            break
        case .failure(_):
            XCTFail("Should have succeeded")
        }
        
        // Then, revoke the access token
        await oidcClient.revoke()
        
        // Check that the token is no longer in storage
        let tokenInStorage = try await oidcClientConfig.storage.get()
        XCTAssertNil(tokenInStorage)
    }
    
    // TestRailCase(22087)
    func testUserinfoShouldReturnUserInfo() async throws {
        let result = await oidcClient.userinfo()
        switch result {
        case .success(let userinfo):
            XCTAssertEqual(userinfo["sub"] as? String, "test-sub")
            XCTAssertEqual(userinfo["name"] as? String, "test-name")
        case .failure(_):
            XCTFail("Should have succeeded")
        }
    }
    
    // TestRailCase(22088)
    func testEndSessionShouldEndSessionAndRevokeToken() async throws {
        // First, get an access token
        let result = await oidcClient.token()
        switch result {
        case .success( _):
            break
        case .failure(_):
            XCTFail("Should have succeeded")
        }
        
        // Then, end the session
        let endSessionResult = await oidcClient.endSession()
        XCTAssertTrue(endSessionResult)
        
        // Check that the token is no longer in storage
        let tokenInStorage = try await oidcClientConfig.storage.get()
        XCTAssertNil(tokenInStorage)
        
        let revokeCalled = MockURLProtocol.requestHistory.contains(where: { request in
            request.url?.path == MockAPIEndpoint.revocation.url.path
        })
        
        XCTAssertTrue(revokeCalled, "The /revoke endpoint was not called.")
        
        let signOffCalled = MockURLProtocol.requestHistory.contains(where:  { request in
            request.url?.path == MockAPIEndpoint.endSession.url.path
        })
        XCTAssertTrue(signOffCalled, "The /signoff endpoint was not called.")
    }
    
    // TestRailCase(22091)
    func testFailedToRetrieveAccessToken() async throws {
        
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
            case MockAPIEndpoint.token.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.token.url, statusCode: 400, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.tokenErrorResponse)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        let result = await oidcClient.token()
        switch result {
        case .success(_):
            XCTFail("Should have failed with error")
        case .failure(let failure):
            switch failure {
            case .apiError(let code, _):
                XCTAssertEqual(code, 400)
            case .authorizeError, .networkError, .configurationError, .unknown:
                XCTFail("Should have failed with .apiError(400)")
            }
        }
    }
    
    // TestRailCase(22092)
    func testFailedToInjectAccessTokenToUserinfo() async throws {
        
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
            case MockAPIEndpoint.token.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.token.url, statusCode: 400, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.tokenErrorResponse)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        let result = await oidcClient.userinfo()
        switch result {
        case .success(_):
            XCTFail("Should have failed with error")
        case .failure(let failure):
            switch failure {
            case .apiError(let code, _):
                XCTAssertEqual(code, 400)
            case .authorizeError, .networkError, .configurationError, .unknown:
                XCTFail("Should have failed with .apiError(400)")
            }
        }
    }
    
    // TestRailCase(22093)
    func testFailedToRetrieveUserinfo() async throws {
        
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
            case MockAPIEndpoint.token.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.token.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.token)
            case MockAPIEndpoint.userinfo.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.userinfo.url, statusCode: 401, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.tokenErrorResponse)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        let result = await oidcClient.userinfo()
        switch result {
        case .success(_):
            XCTFail("Should have failed with error")
        case .failure(let failure):
            switch failure {
            case .apiError(let code, _):
                XCTAssertEqual(code, 401)
            case .authorizeError, .networkError, .configurationError, .unknown:
                XCTFail("Should have failed with .apiError(401)")
            }
        }
    }
    
    // TestRailCase(22094)
    func testFailedToRefreshTokenAfterTokenExpired() async throws {
        
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
            case MockAPIEndpoint.token.url.path:
                // as httpBody is not available here (it is nil), we will check the `Content-Length` header value to see if the `grant_type` is `refresh_token'
                if Int(request.value(forHTTPHeaderField: "Content-Length")!) == "grant_type=refresh_token&refresh_token=Dummy%20RefreshToken&client_id=test-client-id".count {
                    return (HTTPURLResponse(url: MockAPIEndpoint.token.url, statusCode: 400, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.tokenErrorResponse)
                } else {
                    return (HTTPURLResponse(url: MockAPIEndpoint.token.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.token)
                }
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        let result = await oidcClient.token()
        switch result {
        case .success( _):  break
        case .failure( _): XCTFail("Should have succeeded")
        }
        
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        let refreshResult = await oidcClient.token()
        switch refreshResult {
        case .success( _):  break
        case .failure( _): XCTFail("Should have succeeded")
        }
        
        let revokeCalled = MockURLProtocol.requestHistory.contains(where: { request in
            request.url?.path == "/revoke"
        })
        
        XCTAssertTrue(revokeCalled, "The /revoke endpoint was not called.")
    }
    
    // TestRailCase — SDKS-5172 recovery path: corrupted token triggers delete + re-auth
    func testTokenRecoveryOnDecryptionFailure() async throws {
        // Arrange: storage that throws EncryptorError.failedToDecrypt on the first get()
        let throwingStorage = ThrowingMockStorage<Token>()
        await throwingStorage.throwingMock.set(throwOnGet: true)
        oidcClientConfig.storage = throwingStorage

        // MockURLProtocol is already configured in setUp() to return valid discovery + token
        // responses, so re-authentication will succeed after the corrupted token is cleared.

        // Act
        let result = await oidcClient.token()

        // Assert: re-authentication succeeded
        switch result {
        case .success(let token):
            XCTAssertEqual(token.accessToken, "Dummy AccessToken")
        case .failure(let error):
            XCTFail("Expected success after recovery but got failure: \(error)")
        }

        // Assert: the corrupted token was deleted before re-authenticating
        let deleted = await throwingStorage.throwingMock.deleteWasCalled
        XCTAssertTrue(deleted, "delete() should have been called to clear the corrupted token")
    }

    // TestRailCase — SDKS-5301: `oidcInitialize()` failures are re-wrapped in `token()`, and the
    // re-wrap must preserve a typed `OidcError` rather than collapsing it into `.unknown`.
    func testTokenSurfacesConfigurationErrorFromOidcInitialize() async throws {
        oidcClientConfig.discoveryEndpoint = ""

        let result = await oidcClient.token()

        switch result {
        case .success:
            XCTFail("Expected failure when neither openId nor discoveryEndpoint is configured")
        case .failure(let error):
            if case .configurationError(let message) = error {
                XCTAssertTrue(message.contains("discoveryEndpoint"))
                XCTAssertTrue(message.contains("openId"))
            } else {
                XCTFail("Expected .configurationError but got \(error)")
            }
        }
    }

    // TestRailCase — SDKS-5172: if delete() fails during recovery, token() must surface a
    // failure rather than re-authenticating and looping forever on the same corrupted token.
    func testTokenRecoveryFailsWhenDeleteFails() async throws {
        let throwingStorage = ThrowingMockStorage<Token>()
        await throwingStorage.throwingMock.set(throwOnGet: true)        // EncryptorError on get()
        await throwingStorage.throwingMock.set(throwOnDelete: true)     // delete() cannot clear it
        oidcClientConfig.storage = throwingStorage

        let result = await oidcClient.token()

        switch result {
        case .success:
            XCTFail("Expected failure when the corrupted token cannot be cleared")
        case .failure(let error):
            // Should be the authorizeError wrapping the delete failure, not a silent re-auth.
            if case .authorizeError = error {
                // expected
            } else {
                XCTFail("Expected .authorizeError but got \(error)")
            }
        }
    }

    // TestRailCase — SDKS-5172: a non-EncryptorError/non-DecodingError from get() is transient
    // and must NOT trigger recovery (no delete, no re-auth) — it surfaces as a failure with the
    // stored token left intact.
    func testTokenDoesNotRecoverOnTransientStorageError() async throws {
        let throwingStorage = ThrowingMockStorage<Token>()
        await throwingStorage.throwingMock.set(getError: TransientStorageError.interactionNotAllowed)
        await throwingStorage.throwingMock.set(throwOnGet: true)
        oidcClientConfig.storage = throwingStorage

        let result = await oidcClient.token()

        switch result {
        case .success:
            XCTFail("Expected failure on a transient storage error")
        case .failure:
            break
        }

        // The transient error must not have deleted the (potentially valid) token.
        let deleted = await throwingStorage.throwingMock.deleteWasCalled
        XCTAssertFalse(deleted, "delete() must not be called on a transient storage error")
    }

    // TestRailCase — SDKS-5172: revoke() with a transient read error must leave the stored token
    // intact (it may be valid) rather than deleting it.
    func testRevokeLeavesTokenIntactOnTransientStorageError() async throws {
        let throwingStorage = ThrowingMockStorage<Token>()
        await throwingStorage.throwingMock.set(getError: TransientStorageError.interactionNotAllowed)
        await throwingStorage.throwingMock.set(throwOnGet: true)
        oidcClientConfig.storage = throwingStorage

        await oidcClient.revoke()

        let deleted = await throwingStorage.throwingMock.deleteWasCalled
        XCTAssertFalse(deleted, "revoke() must not delete the token on a transient storage error")
    }

    // TestRailCase — SDKS-5301: the scenario `OidcInitializationCoordinator`'s cancellation
    // isolation actually protects. `PingJourney`'s `journeyUser()` (and similar APIs) can hand
    // independent callers an `OidcClient`/`OidcUser` that all wrap the SAME live, not-yet-
    // initialized `OidcClientConfig` — e.g. a token-refresh interceptor and a UI screen both
    // calling `.token()` before discovery has completed once for that config. Cancelling one
    // caller's own task (the UI screen's `.task` when the user navigates away) must not fail the
    // other caller's unrelated, never-cancelled `token()` call.
    func testCancellingOneOidcClientsTokenCallDoesNotFailAnotherOidcClientSharingTheSameConfig() async throws {
        let fakeClient = DiscoveryGatedHttpClient()
        oidcClientConfig.httpClient = fakeClient

        // Two independent `OidcClient`s wrapping the same shared, not-yet-initialized config —
        // exactly how independent callers of `journeyUser()` would each get their own client.
        let firstClient = OidcClient(config: oidcClientConfig)
        let secondClient = OidcClient(config: oidcClientConfig)

        let firstTask = Task { await firstClient.token() }
        let secondTask = Task { await secondClient.token() }

        while await fakeClient.requestCount == 0 {
            await Task.yield()
        }

        firstTask.cancel()

        let firstResult = await firstTask.value
        switch firstResult {
        case .success:
            XCTFail("Expected the cancelled client's token() call to fail")
        case .failure:
            break
        }

        // The shared discovery `firstClient` and `secondClient` were both waiting on is never
        // itself cancelled by `firstClient`'s cancellation: releasing it lets it complete normally.
        await fakeClient.release()

        let secondResult = await secondTask.value
        switch secondResult {
        case .success:
            break
        case .failure(let error):
            XCTFail("The client that never cancelled must still get its token, unaffected by the other client's cancellation: \(error)")
        }

        let finalRequestCount = await fakeClient.requestCount
        XCTAssertEqual(finalRequestCount, 1, "Both clients must have shared a single discovery request")
    }

    private func makeClient(config: HttpClientConfig = HttpClientConfig()) -> URLSessionHttpClient {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)
        return URLSessionHttpClient(config: config, session: session, delegate: nil)
    }
}

/// Deterministic `HttpClientProtocol` fake that gates only the discovery request behind
/// `RequestGate` (shared with `OidcClientConfigTests`, which is cancellation-aware — a caller
/// whose own task is cancelled while waiting throws `CancellationError` immediately, matching
/// real `URLSession` behavior); every other request (token exchange, etc.) is answered
/// immediately, so a caller that is never cancelled can complete its full `token()` flow once
/// discovery is released — see
/// `testCancellingOneOidcClientsTokenCallDoesNotFailAnotherOidcClientSharingTheSameConfig`.
private final class DiscoveryGatedHttpClient: HttpClientProtocol, @unchecked Sendable {
    private let gate = RequestGate()

    var requestCount: Int {
        get async { await gate.requestCount }
    }

    func release() async {
        await gate.release()
    }

    func request() -> HttpRequest {
        URLSessionHttpRequest()
    }

    func request(request: HttpRequest) async throws -> HttpResponse {
        if request.url == MockAPIEndpoint.discovery.url.absoluteString {
            try await gate.recordAndWait()
            return GatedDiscoveryHttpResponse(request: request, status: 200, body: MockResponse.openIdConfiguration)
        }
        if request.url == MockAPIEndpoint.token.url.absoluteString {
            return GatedDiscoveryHttpResponse(request: request, status: 200, body: MockResponse.token)
        }
        return GatedDiscoveryHttpResponse(request: request, status: 500, body: Data())
    }

    func request(builder: @escaping @Sendable (HttpRequest) -> Void) async throws -> HttpResponse {
        let req = request()
        builder(req)
        return try await request(request: req)
    }

    func close() {}
}
