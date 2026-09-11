//
//  OidcClientConfigTests.swift
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
@testable import PingLogger
@testable import PingStorage

final class OidcClientConfigTests: XCTestCase {
    
    var oidcClientConfig: OidcClientConfig!
    
    override func setUp() {
        super.setUp()
        oidcClientConfig = OidcClientConfig()
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
    
    // TestRailCase(22106)
    func testDefaultInitialization() {
        oidcClientConfig = OidcClientConfig()
        
        XCTAssertNil(oidcClientConfig.openId)
        XCTAssertEqual(oidcClientConfig.refreshThreshold, 0)
        XCTAssertNil(oidcClientConfig.agent)
        XCTAssertEqual(oidcClientConfig.discoveryEndpoint, "")
        XCTAssertEqual(oidcClientConfig.clientId, "")
        XCTAssertTrue(oidcClientConfig.scopes.isEmpty)
        XCTAssertEqual(oidcClientConfig.redirectUri, "")
        XCTAssertNil(oidcClientConfig.loginHint)
        XCTAssertNil(oidcClientConfig.state)
        XCTAssertNil(oidcClientConfig.nonce)
        XCTAssertNil(oidcClientConfig.display)
        XCTAssertNil(oidcClientConfig.prompt)
        XCTAssertNil(oidcClientConfig.uiLocales)
        XCTAssertNil(oidcClientConfig.acrValues)
        XCTAssertTrue(oidcClientConfig.additionalParameters.isEmpty)
        XCTAssertFalse(oidcClientConfig.par)
        XCTAssertNil(oidcClientConfig.httpClient)
    }
    
    func testUpdateAgent() {
        let agent = MockAgent()
        oidcClientConfig.updateAgent(agent)
        XCTAssertNotNil(oidcClientConfig.agent)
    }
    
    // TestRailCase(22118)
    func testScopeInsertion() {
        oidcClientConfig.scope("openid")
        XCTAssertTrue(oidcClientConfig.scopes.contains("openid"))
    }
    
    // TestRailCase(22118)
    func testOidcInitializeInvalidDiscovery() async throws {
        
        MockURLProtocol.requestHandler =  { request in
            return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.error)
        }
        
        do {
            try await oidcClientConfig.oidcInitialize()
        } catch {
            XCTAssertNotNil(error)
        }
        XCTAssertNil(oidcClientConfig.openId)
    }
    
    // TestRailCase(24720)
    func testOidcInitializeValidDiscovery() async throws {
        
        MockURLProtocol.requestHandler =  { request in
            return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
        }
        
        do {
            try await oidcClientConfig.oidcInitialize()
            XCTAssertNotNil(oidcClientConfig.openId)
            XCTAssertEqual(MockAPIEndpoint.authorization.url.absoluteString, oidcClientConfig.openId!.authorizationEndpoint)
            XCTAssertEqual(MockAPIEndpoint.token.url.absoluteString, oidcClientConfig.openId!.tokenEndpoint)
            XCTAssertEqual(MockAPIEndpoint.userinfo.url.absoluteString, oidcClientConfig.openId!.userinfoEndpoint)
            XCTAssertEqual(MockAPIEndpoint.endSession.url.absoluteString, oidcClientConfig.openId!.endSessionEndpoint)
            XCTAssertEqual(MockAPIEndpoint.revocation.url.absoluteString, oidcClientConfig.openId!.revocationEndpoint)
        } catch {
            XCTFail("Initialization failed with error: \(error)")
        }
    }
    
    // MARK: - Pre-supplied openId / openIdOverride

    /// Builds a complete `OpenIdConfiguration` pointing at the mock endpoints.
    private func makeOpenIdConfiguration() -> OpenIdConfiguration {
        OpenIdConfiguration(
            authorizationEndpoint: MockAPIEndpoint.authorization.url.absoluteString,
            tokenEndpoint: MockAPIEndpoint.token.url.absoluteString,
            userinfoEndpoint: MockAPIEndpoint.userinfo.url.absoluteString,
            endSessionEndpoint: MockAPIEndpoint.endSession.url.absoluteString,
            revocationEndpoint: MockAPIEndpoint.revocation.url.absoluteString
        )
    }

    /// A pre-supplied `openId` makes `oidcInitialize()` skip discovery entirely — it succeeds
    /// with no `discoveryEndpoint` configured and issues no network request.
    func testOidcInitializeWithPreSuppliedOpenIdSkipsDiscovery() async throws {
        MockURLProtocol.requestHistory.removeAll()
        MockURLProtocol.requestHandler = { _ in
            XCTFail("No request expected when openId is pre-supplied")
            return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
        }

        oidcClientConfig.discoveryEndpoint = ""
        let supplied = makeOpenIdConfiguration()
        oidcClientConfig.openId = supplied

        try await oidcClientConfig.oidcInitialize()

        XCTAssertEqual(oidcClientConfig.openId?.authorizationEndpoint, supplied.authorizationEndpoint)
        XCTAssertEqual(oidcClientConfig.openId?.tokenEndpoint, supplied.tokenEndpoint)
        XCTAssertEqual(oidcClientConfig.openId?.userinfoEndpoint, supplied.userinfoEndpoint)
        XCTAssertEqual(oidcClientConfig.openId?.endSessionEndpoint, supplied.endSessionEndpoint)
        XCTAssertEqual(oidcClientConfig.openId?.revocationEndpoint, supplied.revocationEndpoint)
        XCTAssertTrue(MockURLProtocol.requestHistory.isEmpty, "Discovery must not be requested when openId is pre-supplied")
    }

    /// `openIdOverride` patches a pre-supplied document, and does so exactly once even though
    /// every `OidcClient` entry point re-enters `oidcInitialize()`.
    func testOpenIdOverrideAppliedOnceToPreSuppliedOpenId() async throws {
        MockURLProtocol.requestHistory.removeAll()
        oidcClientConfig.discoveryEndpoint = ""
        oidcClientConfig.openId = makeOpenIdConfiguration()

        let counter = CallCounter()
        oidcClientConfig.openIdOverride = { openId in
            counter.count += 1
            openId.deviceAuthorizationEndpoint = MockAPIEndpoint.deviceAuthorization.url.absoluteString
        }

        try await oidcClientConfig.oidcInitialize()
        try await oidcClientConfig.oidcInitialize()

        XCTAssertEqual(counter.count, 1, "openIdOverride must be applied exactly once")
        XCTAssertEqual(oidcClientConfig.openId?.deviceAuthorizationEndpoint, MockAPIEndpoint.deviceAuthorization.url.absoluteString)
        XCTAssertTrue(MockURLProtocol.requestHistory.isEmpty)
    }

    /// `openIdOverride` patches a discovered document exactly once across repeated
    /// `oidcInitialize()` calls, and discovery itself runs only once.
    func testOpenIdOverrideAppliedOnceToDiscoveredOpenId() async throws {
        MockURLProtocol.requestHistory.removeAll()
        MockURLProtocol.requestHandler = { _ in
            return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
        }

        let counter = CallCounter()
        oidcClientConfig.openIdOverride = { openId in
            counter.count += 1
            openId.deviceAuthorizationEndpoint = MockAPIEndpoint.deviceAuthorization.url.absoluteString
        }

        try await oidcClientConfig.oidcInitialize()
        try await oidcClientConfig.oidcInitialize()

        XCTAssertEqual(counter.count, 1, "openIdOverride must be applied exactly once")
        XCTAssertEqual(oidcClientConfig.openId?.deviceAuthorizationEndpoint, MockAPIEndpoint.deviceAuthorization.url.absoluteString)
        XCTAssertEqual(MockURLProtocol.requestHistory.count, 1, "Discovery must run only once")
    }

    /// A clone of an already-initialised configuration carries the "override applied" state, so
    /// `OidcModule`'s `success` hook cannot re-run a caller's closure on a patched document.
    func testCloneDoesNotReapplyOpenIdOverride() async throws {
        MockURLProtocol.requestHistory.removeAll()
        oidcClientConfig.discoveryEndpoint = ""
        oidcClientConfig.openId = makeOpenIdConfiguration()

        let counter = CallCounter()
        oidcClientConfig.openIdOverride = { openId in
            counter.count += 1
            openId.tokenEndpoint += "?applied=\(counter.count)"
        }

        try await oidcClientConfig.oidcInitialize()
        XCTAssertEqual(counter.count, 1)

        let cloned = oidcClientConfig.clone()
        try await cloned.oidcInitialize()

        XCTAssertEqual(counter.count, 1, "clone() must not re-run openIdOverride")
        XCTAssertEqual(cloned.openId?.tokenEndpoint, oidcClientConfig.openId?.tokenEndpoint)
        XCTAssertEqual(cloned.openId?.tokenEndpoint, "\(MockAPIEndpoint.token.url.absoluteString)?applied=1")
    }

    /// Regression guard: with `openId` left `nil`, discovery still runs against `discoveryEndpoint`.
    func testOidcInitializeRunsDiscoveryWhenOpenIdIsNil() async throws {
        MockURLProtocol.requestHistory.removeAll()
        MockURLProtocol.requestHandler = { _ in
            return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
        }

        XCTAssertNil(oidcClientConfig.openId)

        try await oidcClientConfig.oidcInitialize()

        XCTAssertNotNil(oidcClientConfig.openId)
        XCTAssertEqual(MockURLProtocol.requestHistory.count, 1)
        XCTAssertEqual(MockURLProtocol.requestHistory.first?.url, MockAPIEndpoint.discovery.url)
    }

    // MARK: - Unusable configuration

    /// Neither `openId` nor a usable `discoveryEndpoint`: `oidcInitialize()` fails fast with an
    /// actionable `configurationError` naming both properties, instead of silently leaving
    /// `openId` nil for a vague "OpenID configuration not found" four call frames later.
    func testOidcInitializeWithoutOpenIdOrDiscoveryEndpointThrowsConfigurationError() async throws {
        MockURLProtocol.requestHistory.removeAll()
        MockURLProtocol.requestHandler = { _ in
            XCTFail("No request expected when discoveryEndpoint is blank")
            return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
        }

        oidcClientConfig.discoveryEndpoint = ""

        do {
            try await oidcClientConfig.oidcInitialize()
            XCTFail("Expected oidcInitialize() to throw when neither openId nor discoveryEndpoint is configured")
        } catch let error as OidcError {
            if case .configurationError(let message) = error {
                XCTAssertTrue(message.contains("discoveryEndpoint"), "Message must name discoveryEndpoint: \(message)")
                XCTAssertTrue(message.contains("openId"), "Message must name openId: \(message)")
                XCTAssertEqual(error.errorMessage, "Configuration error: \(message)")
            } else {
                XCTFail("Expected OidcError.configurationError, got \(error)")
            }
        }

        XCTAssertNil(oidcClientConfig.openId, "A failed discovery must leave openId nil so a later call can retry")
        XCTAssertTrue(MockURLProtocol.requestHistory.isEmpty, "No discovery request must be attempted")
    }

    /// A `discoveryEndpoint` that cannot be parsed as a URL is reported the same way as a blank one.
    func testOidcInitializeWithMalformedDiscoveryEndpointThrowsConfigurationError() async throws {
        MockURLProtocol.requestHistory.removeAll()
        MockURLProtocol.requestHandler = { _ in
            XCTFail("No request expected when discoveryEndpoint is malformed")
            return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
        }

        let malformed = "ht^tp://example.com/.well-known/openid-configuration"
        XCTAssertNil(URL(string: malformed), "Precondition: the endpoint must not parse as a URL")
        oidcClientConfig.discoveryEndpoint = malformed

        do {
            try await oidcClientConfig.oidcInitialize()
            XCTFail("Expected oidcInitialize() to throw on a malformed discoveryEndpoint")
        } catch let error as OidcError {
            if case .configurationError(let message) = error {
                XCTAssertTrue(message.contains(malformed), "Message must echo the offending endpoint: \(message)")
            } else {
                XCTFail("Expected OidcError.configurationError, got \(error)")
            }
        }

        XCTAssertNil(oidcClientConfig.openId)
        XCTAssertTrue(MockURLProtocol.requestHistory.isEmpty)
    }

    /// A reachable discovery endpoint that answers with an error status is a server failure, not a
    /// configuration failure — it must stay an `apiError` and not be re-labelled.
    func testOidcInitializeWithServerErrorThrowsApiError() async throws {
        MockURLProtocol.requestHandler = { _ in
            return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.error)
        }

        do {
            try await oidcClientConfig.oidcInitialize()
            XCTFail("Expected oidcInitialize() to throw on a 500 discovery response")
        } catch let error as OidcError {
            if case .apiError(let code, _) = error {
                XCTAssertEqual(code, 500)
            } else {
                XCTFail("Expected OidcError.apiError, got \(error)")
            }
        }

        XCTAssertNil(oidcClientConfig.openId)
    }

    /// A failed discovery is not sticky: `openId` stays nil, so the next `oidcInitialize()` retries
    /// and succeeds once the endpoint recovers.
    func testOidcInitializeRetriesDiscoveryAfterFailure() async throws {
        MockURLProtocol.requestHandler = { _ in
            return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.error)
        }

        do {
            try await oidcClientConfig.oidcInitialize()
            XCTFail("Expected the first oidcInitialize() to throw")
        } catch {
            XCTAssertNil(oidcClientConfig.openId)
        }

        MockURLProtocol.requestHandler = { _ in
            return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
        }

        try await oidcClientConfig.oidcInitialize()

        XCTAssertNotNil(oidcClientConfig.openId)
        XCTAssertEqual(oidcClientConfig.openId?.tokenEndpoint, MockAPIEndpoint.token.url.absoluteString)
    }

    // MARK: - Concurrent oidcInitialize()

    /// Two concurrent first-use calls on the same instance must coalesce into one discovery
    /// request and one `openIdOverride` application, rather than each independently discovering
    /// and patching the document.
    func testConcurrentOidcInitializeSharesOneDiscoveryAndOneOverride() async throws {
        let config: OidcClientConfig = oidcClientConfig
        let fakeClient = GatedDiscoveryHttpClient()
        config.httpClient = fakeClient

        let counter = CallCounter()
        config.openIdOverride = { openId in
            counter.count += 1
            openId.deviceAuthorizationEndpoint = MockAPIEndpoint.deviceAuthorization.url.absoluteString
        }

        // Bind to a local `config` (rather than capturing `self.oidcClientConfig` directly) so
        // these closures don't implicitly send the non-Sendable test-case `self` into the new
        // concurrent child tasks.
        async let firstResult: Void = config.oidcInitialize()
        async let secondResult: Void = config.oidcInitialize()

        // The coordinator's check-then-create is atomic (no suspension in between), so no
        // matter how long we wait here, at most one request can ever be recorded: whichever
        // call creates the shared task always registers it before either call can reach the
        // network. This loop yields — never sleeps — until that first (and only) request lands.
        while await fakeClient.requestCount == 0 {
            await Task.yield()
        }
        await fakeClient.release()

        try await firstResult
        try await secondResult

        let finalRequestCount = await fakeClient.requestCount
        XCTAssertEqual(finalRequestCount, 1, "Two concurrent oidcInitialize() calls must share a single discovery request")
        XCTAssertEqual(counter.count, 1, "openIdOverride must be applied exactly once across concurrent callers")
        XCTAssertEqual(oidcClientConfig.openId?.deviceAuthorizationEndpoint, MockAPIEndpoint.deviceAuthorization.url.absoluteString)
    }

    /// A discovery failure shared by concurrent callers leaves `openId` nil for all of them, and
    /// a later call — with a fresh, successful client — starts a brand-new discovery and succeeds.
    func testConcurrentOidcInitializeSharedFailureAllowsLaterRetry() async throws {
        let config: OidcClientConfig = oidcClientConfig
        let failingClient = GatedDiscoveryHttpClient(status: 500, responseBody: MockResponse.error)
        config.httpClient = failingClient

        // See `testConcurrentOidcInitializeSharesOneDiscoveryAndOneOverride()` for why these
        // bind to a local `config` rather than capturing `self.oidcClientConfig` directly.
        async let firstResult: Void = config.oidcInitialize()
        async let secondResult: Void = config.oidcInitialize()

        while await failingClient.requestCount == 0 {
            await Task.yield()
        }
        await failingClient.release()

        var firstThrew = false
        do { try await firstResult } catch { firstThrew = true }
        var secondThrew = false
        do { try await secondResult } catch { secondThrew = true }

        XCTAssertTrue(firstThrew, "The first caller must observe the shared discovery failure")
        XCTAssertTrue(secondThrew, "The second caller must observe the same shared discovery failure")
        let failureRequestCount = await failingClient.requestCount
        XCTAssertEqual(failureRequestCount, 1, "The shared failure must come from a single discovery request")
        XCTAssertNil(oidcClientConfig.openId)

        oidcClientConfig.httpClient = MockURLProtocol.makeClient()
        MockURLProtocol.requestHandler = { _ in
            (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
        }

        try await oidcClientConfig.oidcInitialize()

        XCTAssertNotNil(oidcClientConfig.openId, "A later call must start a fresh discovery and succeed")
    }

    /// Cancelling a lone caller's own task returns that caller promptly with `CancellationError` —
    /// the coordinator's contract (see `OidcInitializationCoordinator`) never cancels the shared
    /// discovery itself, so this only proves prompt *local* cancellation. It deliberately does not
    /// assert that the discovery is aborted — under this contract it is not; releasing the gate
    /// afterwards proves the shared discovery kept running and can still complete normally. See
    /// `testOidcInitializeCancellationOfOneCallerDoesNotAbortSharedOperationForOthers` for the other
    /// half of the contract, proven with a second, never-cancelled caller.
    func testOidcInitializeCancellationOfLoneCallerIsPromptWithoutAbortingSharedDiscovery() async throws {
        let config: OidcClientConfig = oidcClientConfig
        let fakeClient = GatedDiscoveryHttpClient()
        config.httpClient = fakeClient

        let initializeTask = Task { try await config.oidcInitialize() }

        while await fakeClient.requestCount == 0 {
            await Task.yield()
        }

        initializeTask.cancel()

        var threwCancellation = false
        do {
            try await initializeTask.value
        } catch is CancellationError {
            threwCancellation = true
        }

        XCTAssertTrue(threwCancellation, "A cancelled caller must observe its own cancellation promptly, rather than waiting for the shared discovery to finish")

        // The shared discovery that this now-gone caller kicked off is never itself cancelled (see
        // `OidcInitializationCoordinator`): releasing it lets it complete normally, and a subsequent
        // call succeeds rather than being poisoned by the earlier cancellation.
        await fakeClient.release()
        try await config.oidcInitialize()

        XCTAssertNotNil(config.openId, "The shared discovery must be able to complete normally after a caller cancels only its own wait on it")
    }

    /// The coordinator's contract: cancelling one of several callers sharing an in-flight
    /// operation fails only that caller, promptly — it never cancels the shared operation itself,
    /// so any other caller currently sharing it is unaffected and still completes normally once
    /// the operation finishes. See `OidcInitializationCoordinator`.
    func testOidcInitializeCancellationOfOneCallerDoesNotAbortSharedOperationForOthers() async throws {
        let config: OidcClientConfig = oidcClientConfig
        let fakeClient = GatedDiscoveryHttpClient()
        config.httpClient = fakeClient

        let firstTask = Task { try await config.oidcInitialize() }
        let secondTask = Task { try await config.oidcInitialize() }

        while await fakeClient.requestCount == 0 {
            await Task.yield()
        }

        firstTask.cancel()

        var firstThrew = false
        do { try await firstTask.value } catch { firstThrew = true }

        XCTAssertTrue(firstThrew, "The caller that cancelled must observe the failure")

        // The shared discovery `firstTask` and `secondTask` were both waiting on is never itself
        // cancelled by `firstTask`'s cancellation: releasing it lets it complete normally.
        await fakeClient.release()
        try await secondTask.value

        XCTAssertNotNil(config.openId, "The caller that never cancelled must complete normally, unaffected by the other caller's cancellation")

        let finalRequestCount = await fakeClient.requestCount
        XCTAssertEqual(finalRequestCount, 1, "Still only one discovery request should have been issued")
    }

    // MARK: - apply(json:) reconfiguration

    /// Reapplying JSON with a different `openId` sub-object replaces the JSON-derived override
    /// layer wholesale (not nested under the prior JSON layer), while a programmatic override set
    /// directly on `openIdOverride` survives and reruns against the newly materialized document.
    ///
    /// JSON A and JSON B deliberately patch *different* endpoint keys (`deviceAuthorizationEndpoint`
    /// vs. `pushedAuthorizationRequestEndpoint`). If B merely nested on top of A's closure instead
    /// of replacing it, A's key would still show A's value after B is applied; asserting that it
    /// reverts to the freshly-discovered value is what actually proves wholesale replacement.
    func testApplyJsonReplacesJsonOverrideAndPreservesProgrammaticOverride() async throws {
        let programmaticCounter = CallCounter()
        oidcClientConfig.openIdOverride = { openId in
            programmaticCounter.count += 1
            openId.userinfoEndpoint = "https://example.com/programmatic-userinfo"
        }

        let jsonA: [String: Any] = [
            "clientId": "client-a",
            "discoveryEndpoint": MockAPIEndpoint.discovery.url.absoluteString,
            "scopes": ["openid"],
            "redirectUri": "https://example.com/callback",
            "openId": ["deviceAuthorizationEndpoint": "https://example.com/device-a"]
        ]
        try oidcClientConfig.apply(json: jsonA)

        MockURLProtocol.requestHandler = { _ in
            (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
        }
        try await oidcClientConfig.oidcInitialize()

        XCTAssertEqual(oidcClientConfig.openId?.deviceAuthorizationEndpoint, "https://example.com/device-a")
        XCTAssertEqual(oidcClientConfig.openId?.userinfoEndpoint, "https://example.com/programmatic-userinfo")
        XCTAssertEqual(programmaticCounter.count, 1)

        let jsonB: [String: Any] = [
            "clientId": "client-b",
            "discoveryEndpoint": MockAPIEndpoint.discovery.url.absoluteString,
            "scopes": ["openid"],
            "redirectUri": "https://example.com/callback",
            "openId": ["pushedAuthorizationRequestEndpoint": "https://example.com/par-b"]
        ]
        try oidcClientConfig.apply(json: jsonB)

        XCTAssertNil(oidcClientConfig.openId, "A successful apply(json:) must invalidate the previously materialized document")

        try await oidcClientConfig.oidcInitialize()

        XCTAssertNil(oidcClientConfig.openId?.deviceAuthorizationEndpoint, "JSON A's override must not survive nested under JSON B's — it must be replaced wholesale")
        XCTAssertEqual(oidcClientConfig.openId?.pushedAuthorizationRequestEndpoint, "https://example.com/par-b", "JSON B's own override must be applied")
        XCTAssertEqual(oidcClientConfig.openId?.userinfoEndpoint, "https://example.com/programmatic-userinfo", "The programmatic override must survive reapplication")
        XCTAssertEqual(programmaticCounter.count, 2, "The programmatic override must run again against the newly materialized document")
    }

    /// `clone()` (via `update(with:)`) must copy the JSON-derived override layer, not just the
    /// programmatic layer — a config that was configured from JSON but never yet initialized must
    /// still apply that JSON's endpoint override once its clone is initialized.
    func testCloneCopiesJsonOpenIdOverrideLayer() async throws {
        let json: [String: Any] = [
            "clientId": "client",
            "discoveryEndpoint": MockAPIEndpoint.discovery.url.absoluteString,
            "scopes": ["openid"],
            "redirectUri": "https://example.com/callback",
            "openId": ["deviceAuthorizationEndpoint": "https://example.com/device-json"]
        ]
        try oidcClientConfig.apply(json: json)

        // Clone before initialization, so the clone's own oidcInitialize() call exercises
        // whichever override state clone() copied, rather than an already-materialized document.
        let cloned = oidcClientConfig.clone()

        MockURLProtocol.requestHandler = { _ in
            (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
        }
        try await cloned.oidcInitialize()

        XCTAssertEqual(cloned.openId?.deviceAuthorizationEndpoint, "https://example.com/device-json", "clone() must copy the JSON-derived override layer, not just the programmatic layer")
    }

    /// Valid JSON that omits `openId` leaves a programmatic override intact.
    func testApplyJsonWithoutOpenIdPreservesProgrammaticOverride() async throws {
        let counter = CallCounter()
        oidcClientConfig.openIdOverride = { openId in
            counter.count += 1
            openId.userinfoEndpoint = "https://example.com/programmatic-userinfo"
        }

        let json: [String: Any] = [
            "clientId": "client",
            "discoveryEndpoint": MockAPIEndpoint.discovery.url.absoluteString,
            "scopes": ["openid"],
            "redirectUri": "https://example.com/callback"
        ]
        try oidcClientConfig.apply(json: json)

        MockURLProtocol.requestHandler = { _ in
            (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
        }
        try await oidcClientConfig.oidcInitialize()

        XCTAssertEqual(oidcClientConfig.openId?.userinfoEndpoint, "https://example.com/programmatic-userinfo")
        XCTAssertEqual(counter.count, 1)
    }

    /// Invalid JSON must leave an already-initialized configuration completely unchanged: no
    /// mutated fields, no cleared `openId`, and no reset override-applied marker.
    func testApplyInvalidJsonLeavesInitializedConfigurationUnchanged() async throws {
        MockURLProtocol.requestHandler = { _ in
            (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
        }
        try await oidcClientConfig.oidcInitialize()

        let tokenEndpointBefore = oidcClientConfig.openId?.tokenEndpoint
        let discoveryEndpointBefore = oidcClientConfig.discoveryEndpoint
        let clientIdBefore = oidcClientConfig.clientId

        let invalidJson: [String: Any] = [
            "clientId": "client",
            "discoveryEndpoint": "https://example.com/new",
            "scopes": [1, 2, 3],
            "redirectUri": "https://example.com/callback"
        ]

        XCTAssertThrowsError(try oidcClientConfig.apply(json: invalidJson))

        XCTAssertEqual(oidcClientConfig.openId?.tokenEndpoint, tokenEndpointBefore, "Invalid JSON must not touch the materialized document")
        XCTAssertEqual(oidcClientConfig.discoveryEndpoint, discoveryEndpointBefore)
        XCTAssertEqual(oidcClientConfig.clientId, clientIdBefore)

        MockURLProtocol.requestHistory.removeAll()
        try await oidcClientConfig.oidcInitialize()
        XCTAssertTrue(MockURLProtocol.requestHistory.isEmpty, "A rejected apply(json:) call must not have invalidated the materialized document")
    }

    // TestRailCase(22081)
    func testClone() {
        oidcClientConfig.refreshThreshold = 100
        oidcClientConfig.agent = AgentDelegate(agent: MockAgent(), agentConfig: (), oidcClientConfig: oidcClientConfig)
        oidcClientConfig.logger = LogManager.standard
        oidcClientConfig.storage = MockStorage<Token>()
        oidcClientConfig.discoveryEndpoint = "https://example.com"
        oidcClientConfig.clientId = "clientId"
        oidcClientConfig.scopes.insert("openid")
        oidcClientConfig.redirectUri = "http://localhost/callback"
        oidcClientConfig.loginHint = "loginHint"
        oidcClientConfig.nonce = "nonce"
        oidcClientConfig.display = "display"
        oidcClientConfig.prompt = "prompt"
        oidcClientConfig.uiLocales = "uiLocales"
        oidcClientConfig.acrValues = "acrValues"
        oidcClientConfig.additionalParameters = ["param": "value"]
        oidcClientConfig.httpClient = MockURLProtocol.makeClient()
        oidcClientConfig.par = true
        
        let clonedConfig = oidcClientConfig.clone()
        
        XCTAssertEqual(oidcClientConfig.openId.debugDescription, clonedConfig.openId.debugDescription)
        XCTAssertEqual(oidcClientConfig.refreshThreshold, clonedConfig.refreshThreshold)
        XCTAssertEqual(oidcClientConfig.agent.debugDescription, clonedConfig.agent.debugDescription)
        XCTAssertEqual(oidcClientConfig.discoveryEndpoint, clonedConfig.discoveryEndpoint)
        XCTAssertEqual(oidcClientConfig.clientId, clonedConfig.clientId)
        XCTAssertEqual(oidcClientConfig.scopes, clonedConfig.scopes)
        XCTAssertEqual(oidcClientConfig.redirectUri, clonedConfig.redirectUri)
        XCTAssertEqual(oidcClientConfig.loginHint, clonedConfig.loginHint)
        XCTAssertEqual(oidcClientConfig.nonce, clonedConfig.nonce)
        XCTAssertEqual(oidcClientConfig.display, clonedConfig.display)
        XCTAssertEqual(oidcClientConfig.prompt, clonedConfig.prompt)
        XCTAssertEqual(oidcClientConfig.uiLocales, clonedConfig.uiLocales)
        XCTAssertEqual(oidcClientConfig.acrValues, clonedConfig.acrValues)
        XCTAssertEqual(oidcClientConfig.additionalParameters, clonedConfig.additionalParameters)
        XCTAssertEqual(oidcClientConfig.httpClient.debugDescription, clonedConfig.httpClient.debugDescription)
        XCTAssertEqual(oidcClientConfig.par, clonedConfig.par)
    }
    
    // TestRailCase(24719)
    func testUpdate() {
        let otherConfig = OidcClientConfig()
        otherConfig.agent = AgentDelegate(agent: MockAgent(), agentConfig: (), oidcClientConfig: oidcClientConfig)
        otherConfig.logger = LogManager.standard
        otherConfig.storage = MockStorage<Token>()
        otherConfig.discoveryEndpoint = "https://example.com"
        otherConfig.clientId = "clientId"
        otherConfig.scopes.insert("openid")
        otherConfig.redirectUri = "http://localhost/callback"
        otherConfig.loginHint = "loginHint"
        otherConfig.nonce = "nonce"
        otherConfig.display = "display"
        otherConfig.prompt = "prompt"
        otherConfig.uiLocales = "uiLocales"
        otherConfig.acrValues = "acrValues"
        otherConfig.additionalParameters = ["param": "value"]
        otherConfig.httpClient = MockURLProtocol.makeClient()
        otherConfig.par = true
        
        oidcClientConfig.update(with: otherConfig)
        
        XCTAssertEqual(otherConfig.openId.debugDescription, oidcClientConfig.openId.debugDescription)
        XCTAssertEqual(otherConfig.agent.debugDescription, oidcClientConfig.agent.debugDescription)
        XCTAssertEqual(otherConfig.discoveryEndpoint, oidcClientConfig.discoveryEndpoint)
        XCTAssertEqual(otherConfig.clientId, oidcClientConfig.clientId)
        XCTAssertEqual(otherConfig.scopes, oidcClientConfig.scopes)
        XCTAssertEqual(otherConfig.redirectUri, oidcClientConfig.redirectUri)
        XCTAssertEqual(otherConfig.loginHint, oidcClientConfig.loginHint)
        XCTAssertEqual(otherConfig.nonce, oidcClientConfig.nonce)
        XCTAssertEqual(otherConfig.display, oidcClientConfig.display)
        XCTAssertEqual(otherConfig.prompt, oidcClientConfig.prompt)
        XCTAssertEqual(otherConfig.uiLocales, oidcClientConfig.uiLocales)
        XCTAssertEqual(otherConfig.acrValues, oidcClientConfig.acrValues)
        XCTAssertEqual(otherConfig.additionalParameters, oidcClientConfig.additionalParameters)
        XCTAssertEqual(otherConfig.httpClient.debugDescription, oidcClientConfig.httpClient.debugDescription)
        XCTAssertEqual(otherConfig.par, oidcClientConfig.par)
    }
}

/// Reference-typed counter so `openIdOverride` closures can record how often they ran.
final class CallCounter: @unchecked Sendable {
    var count = 0
}

// MARK: - Deterministic concurrency test doubles

/// Actor-backed gate used by `GatedDiscoveryHttpClient` so concurrency tests can prove exactly
/// how many discovery requests were issued before responses become available, without a
/// `MockURLProtocol` global or a fixed `Task.sleep`. Not file-private: reused by
/// `OidcClientTests`'s own gated fake to test cancellation isolation across independent
/// `OidcClient`s sharing one `OidcClientConfig`.
actor RequestGate {
    private(set) var requestCount = 0
    private var released = false
    private var waiters: [CheckedContinuation<Void, any Error>] = []

    /// Records one request; suspends the caller until `release()`, unless already released.
    /// Cancellation-aware — like real `URLSession`, a caller whose own task is cancelled while
    /// waiting throws `CancellationError` immediately rather than waiting for `release()`, so
    /// tests can exercise `oidcInitialize()`'s cancellation behavior deterministically.
    func recordAndWait() async throws {
        requestCount += 1
        if released { return }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { waiters.append($0) }
        } onCancel: {
            Task { await self.cancelWaiters() }
        }
    }

    /// Resumes every request currently suspended in `recordAndWait()`. Requests recorded after
    /// this call return immediately.
    func release() {
        released = true
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }

    private func cancelWaiters() {
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume(throwing: CancellationError()) }
    }
}

/// Deterministic `HttpClientProtocol` fake for `oidcInitialize()` concurrency tests. Every
/// request is recorded by `gate` and suspends there until the test calls `release()`; once
/// released, it resolves with the configured `status`/`responseBody`.
private final class GatedDiscoveryHttpClient: HttpClientProtocol, @unchecked Sendable {
    private let gate = RequestGate()
    private let status: Int
    private let responseBody: Data

    init(status: Int = 200, responseBody: Data = MockResponse.openIdConfiguration) {
        self.status = status
        self.responseBody = responseBody
    }

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
        try await gate.recordAndWait()
        return GatedDiscoveryHttpResponse(request: request, status: status, body: responseBody)
    }

    func request(builder: @escaping @Sendable (HttpRequest) -> Void) async throws -> HttpResponse {
        let req = request()
        builder(req)
        return try await request(request: req)
    }

    func close() {}
}

/// Not file-private: reused by `OidcClientTests`'s own gated fake — see `RequestGate`.
struct GatedDiscoveryHttpResponse: HttpResponse {
    let request: HttpRequest
    let status: Int
    let body: Data?

    func getHeader(name: String) -> String? { nil }
    func getHeaders(name: String) -> [String]? { nil }
    func getCookies() -> [HTTPCookie] { [] }
    func getCookieStrings() -> [String] { [] }
    func bodyAsString() -> String {
        guard let body else { return "" }
        return String(data: body, encoding: .utf8) ?? ""
    }
}

// Mock classes for AgentDelegateProtocol, Agent, HttpClient, etc.
class MockAgent: Agent, @unchecked Sendable {
    func config() -> () -> T {
        return {}
    }
    
    func endSession(oidcConfig: PingOidc.OidcConfig<T>, idToken: String) async throws -> Bool {
        let params = [
            "client_id": oidcConfig.oidcClientConfig.clientId,
            "id_token_hint": idToken
        ]
        
        guard let httpClient = oidcConfig.oidcClientConfig.httpClient else {
            XCTFail("httpClient should not be nil")
            return false
        }
        
        _ = try await httpClient.request { request in
            request.url = MockAPIEndpoint.endSession.url.absoluteString
            request.form(parameters: params)
        }
        
        return true
    }
    
    func authorize(oidcConfig: PingOidc.OidcConfig<T>) async throws -> PingOidc.AuthCode {
        return AuthCode(code: "TestAgent", codeVerifier: "codeVerifier")
    }
    
    typealias T = Void
}
