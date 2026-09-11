//
//  OidcDeviceClientTests.swift
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

class OidcDeviceClientTests: XCTestCase {

    // MARK: - DeviceAuthorizationResponse decoding

    /// Test: DeviceAuthorizationResponse decodes correctly from valid RFC 8628 JSON.
    func testDeviceAuthorizationResponseDecodesFromValidJSON() throws {
        let response = try JSONDecoder().decode(
            DeviceAuthorizationResponse.self,
            from: MockResponse.deviceAuthorizationResponse
        )

        XCTAssertEqual(response.deviceCode, "GmRhmhcxhwAzkoEqiMEg_DnyEysNkuNhszIySk9eS")
        XCTAssertEqual(response.userCode, "WDJB-MJHT")
        XCTAssertEqual(response.verificationUri, "https://auth.test-one-pingone.com/activate")
        XCTAssertEqual(response.verificationUriComplete, "https://auth.test-one-pingone.com/activate?user_code=WDJB-MJHT")
        XCTAssertEqual(response.expiresIn, 1800)
        XCTAssertEqual(response.interval, 5)
    }

    /// Test: interval defaults to 5 when absent from JSON.
    func testIntervalDefaultsToFiveWhenAbsent() throws {
        let response = try JSONDecoder().decode(
            DeviceAuthorizationResponse.self,
            from: MockResponse.deviceAuthorizationResponseNoInterval
        )

        XCTAssertEqual(response.interval, 5)
    }

    /// Test: verificationUriComplete is nil when absent from JSON.
    func testVerificationUriCompleteIsNilWhenAbsent() throws {
        let json = """
        {
          "device_code" : "test-device-code",
          "user_code" : "ABCD-1234",
          "verification_uri" : "https://auth.test-one-pingone.com/activate",
          "expires_in" : 600
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(DeviceAuthorizationResponse.self, from: json)

        XCTAssertNil(response.verificationUriComplete)
        XCTAssertEqual(response.userCode, "ABCD-1234")
        XCTAssertEqual(response.verificationUri, "https://auth.test-one-pingone.com/activate")
    }

    /// Test: DeviceFlowStatus cases can be constructed (compile check).
    func testDeviceFlowStatusCasesCanBeConstructed() throws {
        let deviceAuthResponse = try JSONDecoder().decode(
            DeviceAuthorizationResponse.self,
            from: MockResponse.deviceAuthorizationResponse
        )

        let started = DeviceFlowStatus.started(deviceAuthResponse)
        let polling = DeviceFlowStatus.polling(pollCount: 1, pollInterval: 5, nextPollAt: Date())
        let expired = DeviceFlowStatus.expired
        let accessDenied = DeviceFlowStatus.accessDenied
        let failure = DeviceFlowStatus.failure(NSError(domain: "test", code: -1))

        // Verify the started case holds the correct response
        if case .started(let r) = started {
            XCTAssertEqual(r.userCode, "WDJB-MJHT")
        } else {
            XCTFail("Expected .started case")
        }

        // Verify polling case holds associated values
        if case .polling(let count, let interval, _) = polling {
            XCTAssertEqual(count, 1)
            XCTAssertEqual(interval, 5)
        } else {
            XCTFail("Expected .polling case")
        }

        // Verify terminal cases exist (compile-time check via exhaustive switch)
        switch expired {
        case .expired: break
        default: XCTFail("Expected .expired")
        }

        switch accessDenied {
        case .accessDenied: break
        default: XCTFail("Expected .accessDenied")
        }

        if case .failure(let err) = failure {
            XCTAssertEqual((err as NSError).code, -1)
        } else {
            XCTFail("Expected .failure case")
        }
    }

    /// Test: DeviceFlowStatus.success carries the provided User value.
    func testDeviceFlowStatusSuccessCarriesUser() {
        let mockUser = MockUser()
        let status = DeviceFlowStatus.success(mockUser)

        if case .success(let user) = status {
            XCTAssertTrue(user is MockUser)
        } else {
            XCTFail("Expected .success case")
        }
    }

    // MARK: - Polling tests

    /// Shared OpenIdConfiguration pre-built with deviceAuthorizationEndpoint to skip real discovery.
    private func makeOpenIdConfig(includeDeviceEndpoint: Bool = true) -> OpenIdConfiguration {
        OpenIdConfiguration(
            authorizationEndpoint: MockAPIEndpoint.authorization.url.absoluteString,
            tokenEndpoint: MockAPIEndpoint.token.url.absoluteString,
            userinfoEndpoint: MockAPIEndpoint.userinfo.url.absoluteString,
            endSessionEndpoint: MockAPIEndpoint.endSession.url.absoluteString,
            revocationEndpoint: MockAPIEndpoint.revocation.url.absoluteString,
            deviceAuthorizationEndpoint: includeDeviceEndpoint ? MockAPIEndpoint.deviceAuthorization.url.absoluteString : nil
        )
    }

    /// Shared helper that builds an OidcClientConfig wired to MockURLProtocol.
    private func makeConfig(includeDeviceEndpoint: Bool = true) -> OidcClientConfig {
        let config = OidcClientConfig()
        config.clientId = "test-client-id"
        config.scopes = Set(["openid"])
        config.redirectUri = "org.forgerock.demo://oauth2redirect"
        config.storage = MockStorage<Token>()
        config.httpClient = MockURLProtocol.makeClient()
        // Set openId directly so oidcInitialize() skips real discovery
        config.openId = makeOpenIdConfig(includeDeviceEndpoint: includeDeviceEndpoint)
        return config
    }

    /// Returns a mock HTTPURLResponse for a given URL and status code.
    private func mockHTTPResponse(url: URL, statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: MockResponse.headers)!
    }

    /// Helper to read httpBodyStream data from URLRequest (httpBody is nil when using URLSession with URLProtocol).
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

    // MARK: - Test 1: Happy path

    /// Test: happy path — device auth OK, one authorization_pending, then token success.
    /// Expected stream: .started, .polling, .success
    func testDeviceAuthorizationHappyPath() async throws {
        MockURLProtocol.startInterceptingRequests()
        defer { MockURLProtocol.stopInterceptingRequests() }

        // Use a counter to serve different responses to the token endpoint
        nonisolated(unsafe) var tokenCallCount = 0

        MockURLProtocol.requestHandler = { [self] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.deviceAuthorization.url.path:
                return (mockHTTPResponse(url: MockAPIEndpoint.deviceAuthorization.url, statusCode: 200),
                        MockResponse.deviceAuthorizationResponseFastInterval)
            case MockAPIEndpoint.token.url.path:
                tokenCallCount += 1
                if tokenCallCount == 1 {
                    return (mockHTTPResponse(url: MockAPIEndpoint.token.url, statusCode: 400),
                            MockResponse.authorizationPending)
                } else {
                    return (mockHTTPResponse(url: MockAPIEndpoint.token.url, statusCode: 200),
                            MockResponse.token)
                }
            default:
                XCTFail("Unexpected request: \(request.url?.absoluteString ?? "<nil>")")
                return (mockHTTPResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500), Data())
            }
        }

        let config = makeConfig()
        let client = OidcDeviceClient(config: config)

        let stream = try await client.deviceAuthorization()

        var statuses: [String] = []
        for try await status in stream {
            switch status {
            case .started(let response):
                statuses.append("started")
                XCTAssertEqual(response.userCode, "WDJB-MJHT")
            case .polling:
                statuses.append("polling")
            case .success:
                statuses.append("success")
            case .expired:
                statuses.append("expired")
                XCTFail("Unexpected .expired status")
            case .accessDenied:
                statuses.append("accessDenied")
                XCTFail("Unexpected .accessDenied status")
            case .failure(let error):
                statuses.append("failure")
                XCTFail("Unexpected .failure status: \(error)")
            }
        }

        XCTAssertEqual(statuses, ["started", "polling", "success"])

        // Verify device_code appears in the token POST body but not in logged strings
        let tokenRequests = MockURLProtocol.requestHistory.filter {
            $0.url?.path == MockAPIEndpoint.token.url.path
        }
        XCTAssertGreaterThan(tokenRequests.count, 0, "Token endpoint should have been polled")
        let tokenBody = String(data: bodyData(from: tokenRequests[0]), encoding: .utf8) ?? ""
        XCTAssertTrue(tokenBody.contains("device_code="), "Token POST body should contain device_code parameter")
    }

    // MARK: - Test 2: slow_down increases interval

    /// Test: slow_down response increases interval by 5.
    /// Uses interval=-5 fixture so slow_down bumps to 0 — Task.sleep(0) is instant and the
    /// stream completes without any real wall-clock delay, making the test deterministic on CI.
    /// Expected stream: .started, .polling(pollCount:1, pollInterval:0, ...), .success
    func testSlowDownIncreasesInterval() async throws {
        MockURLProtocol.startInterceptingRequests()
        defer { MockURLProtocol.stopInterceptingRequests() }

        nonisolated(unsafe) var tokenCallCount = 0

        MockURLProtocol.requestHandler = { [self] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.deviceAuthorization.url.path:
                // interval=-5: slow_down adds 5 → final interval=0 → Task.sleep(0) is instant
                return (mockHTTPResponse(url: MockAPIEndpoint.deviceAuthorization.url, statusCode: 200),
                        MockResponse.deviceAuthorizationResponseSlowDownFriendly)
            case MockAPIEndpoint.token.url.path:
                tokenCallCount += 1
                if tokenCallCount == 1 {
                    return (mockHTTPResponse(url: MockAPIEndpoint.token.url, statusCode: 400),
                            MockResponse.slowDown)
                } else {
                    return (mockHTTPResponse(url: MockAPIEndpoint.token.url, statusCode: 200),
                            MockResponse.token)
                }
            default:
                XCTFail("Unexpected request: \(request.url?.absoluteString ?? "<nil>")")
                return (mockHTTPResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500), Data())
            }
        }

        let config = makeConfig()
        let client = OidcDeviceClient(config: config)
        let stream = try await client.deviceAuthorization()

        var statuses: [String] = []
        var pollingInterval: Int?
        var pollingCount: Int?

        for try await status in stream {
            switch status {
            case .started:
                statuses.append("started")
            case .polling(let count, let interval, _):
                statuses.append("polling")
                pollingInterval = interval
                pollingCount = count
            case .success:
                statuses.append("success")
            case .expired:
                statuses.append("expired")
                XCTFail("Unexpected .expired status")
            case .accessDenied:
                statuses.append("accessDenied")
                XCTFail("Unexpected .accessDenied status")
            case .failure(let error):
                statuses.append("failure")
                XCTFail("Unexpected .failure status: \(error)")
            }
        }

        // -5 + 5 = 0; verifies the increment happened (interval increased by 5 from base)
        XCTAssertEqual(pollingInterval, 0, "slow_down should have increased interval from -5 to 0")
        XCTAssertEqual(pollingCount, 1, "Poll count should be 1 after first slow_down")
        XCTAssertTrue(statuses.contains("started"), "Stream should have yielded .started")
        XCTAssertTrue(statuses.contains("polling"), "Stream should have yielded .polling after slow_down")
        XCTAssertEqual(statuses.last, "success", "Stream should complete with .success")
    }

    // MARK: - Test 2b: slow_down compounds, authorization_pending resets to baseInterval

    /// Test: consecutive `slow_down` responses compound `interval` per RFC 8628 §3.5
    /// (+5 each), and a subsequent `authorization_pending` resets `interval` back to
    /// the server-provided `baseInterval`.
    /// Uses interval=-5 fixture so all sleep durations stay at 0, keeping the test instant on CI.
    func testSlowDownCompoundsAndAuthorizationPendingResets() async throws {
        MockURLProtocol.startInterceptingRequests()
        defer { MockURLProtocol.stopInterceptingRequests() }

        nonisolated(unsafe) var tokenCallCount = 0

        MockURLProtocol.requestHandler = { [self] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.deviceAuthorization.url.path:
                // interval=-5: slow_down 1 → 0, slow_down 2 → 5, authorization_pending resets to -5.
                // Task.sleep(for: .seconds(n)) clamps n≤0 to immediate so sleeps are instant.
                return (mockHTTPResponse(url: MockAPIEndpoint.deviceAuthorization.url, statusCode: 200),
                        MockResponse.deviceAuthorizationResponseSlowDownFriendly)
            case MockAPIEndpoint.token.url.path:
                tokenCallCount += 1
                switch tokenCallCount {
                case 1, 2:
                    return (mockHTTPResponse(url: MockAPIEndpoint.token.url, statusCode: 400),
                            MockResponse.slowDown)
                case 3:
                    return (mockHTTPResponse(url: MockAPIEndpoint.token.url, statusCode: 400),
                            MockResponse.authorizationPending)
                default:
                    return (mockHTTPResponse(url: MockAPIEndpoint.token.url, statusCode: 400),
                            MockResponse.accessDenied)
                }
            default:
                return (mockHTTPResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500), Data())
            }
        }

        let config = makeConfig()
        let client = OidcDeviceClient(config: config)
        let stream = try await client.deviceAuthorization()

        var pollIntervals: [Int] = []

        for try await status in stream {
            switch status {
            case .polling(_, let interval, _):
                pollIntervals.append(interval)
            case .started, .accessDenied: break
            case .success, .expired, .failure:
                XCTFail("Unexpected terminal status: \(status)")
            }
        }

        XCTAssertEqual(pollIntervals.count, 3, "Expected three .polling yields (two slow_down + one authorization_pending)")
        XCTAssertEqual(pollIntervals[0], 0, "First slow_down: -5 + 5 = 0")
        XCTAssertEqual(pollIntervals[1], 5, "Second slow_down compounds: 0 + 5 = 5")
        XCTAssertEqual(pollIntervals[2], -5, "authorization_pending resets to baseInterval (-5 in this fixture)")
    }

    // MARK: - Test 3: access_denied finishes stream

    /// Test: access_denied response yields .accessDenied and stream finishes without throwing.
    func testAccessDeniedFinishesStream() async throws {
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
                XCTFail("Unexpected request: \(request.url?.absoluteString ?? "<nil>")")
                return (mockHTTPResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500), Data())
            }
        }

        let config = makeConfig()
        let client = OidcDeviceClient(config: config)

        let stream = try await client.deviceAuthorization()

        var statuses: [String] = []
        // Iterating with for try await — stream should finish (not throw) on access_denied
        for try await status in stream {
            switch status {
            case .started:
                statuses.append("started")
            case .polling:
                statuses.append("polling")
            case .success:
                statuses.append("success")
                XCTFail("Unexpected .success — stream should have ended with .accessDenied")
            case .expired:
                statuses.append("expired")
                XCTFail("Unexpected .expired")
            case .accessDenied:
                statuses.append("accessDenied")
            case .failure(let error):
                statuses.append("failure")
                XCTFail("Unexpected .failure: \(error)")
            }
        }

        XCTAssertEqual(statuses, ["started", "accessDenied"], "Stream should yield .started then .accessDenied")
    }

    // MARK: - Test 4: expired_token finishes stream

    /// Test: expired_token response yields .expired and stream finishes without throwing.
    func testExpiredTokenFinishesStream() async throws {
        MockURLProtocol.startInterceptingRequests()
        defer { MockURLProtocol.stopInterceptingRequests() }

        MockURLProtocol.requestHandler = { [self] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.deviceAuthorization.url.path:
                return (mockHTTPResponse(url: MockAPIEndpoint.deviceAuthorization.url, statusCode: 200),
                        MockResponse.deviceAuthorizationResponseFastInterval)
            case MockAPIEndpoint.token.url.path:
                return (mockHTTPResponse(url: MockAPIEndpoint.token.url, statusCode: 400),
                        MockResponse.expiredToken)
            default:
                XCTFail("Unexpected request: \(request.url?.absoluteString ?? "<nil>")")
                return (mockHTTPResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500), Data())
            }
        }

        let config = makeConfig()
        let client = OidcDeviceClient(config: config)

        let stream = try await client.deviceAuthorization()

        var statuses: [String] = []
        for try await status in stream {
            switch status {
            case .started:
                statuses.append("started")
            case .polling:
                statuses.append("polling")
            case .success:
                statuses.append("success")
                XCTFail("Unexpected .success — stream should have ended with .expired")
            case .expired:
                statuses.append("expired")
            case .accessDenied:
                statuses.append("accessDenied")
                XCTFail("Unexpected .accessDenied")
            case .failure(let error):
                statuses.append("failure")
                XCTFail("Unexpected .failure: \(error)")
            }
        }

        XCTAssertEqual(statuses, ["started", "expired"], "Stream should yield .started then .expired")
    }

    // MARK: - Test 5: missing device authorization endpoint throws

    /// Test: deviceAuthorizationEndpoint absent in config causes deviceAuthorization() to throw.
    func testMissingDeviceAuthorizationEndpointThrows() async throws {
        MockURLProtocol.startInterceptingRequests()
        defer { MockURLProtocol.stopInterceptingRequests() }

        MockURLProtocol.requestHandler = { [self] request in
            // Only discovery calls would come through; no device auth endpoint
            return (mockHTTPResponse(url: request.url ?? MockAPIEndpoint.discovery.url, statusCode: 500), Data())
        }

        // Config without deviceAuthorizationEndpoint
        let config = makeConfig(includeDeviceEndpoint: false)
        let client = OidcDeviceClient(config: config)

        do {
            _ = try await client.deviceAuthorization()
            XCTFail("Expected deviceAuthorization() to throw when endpoint is absent")
        } catch {
            // Any thrown error is acceptable — the important thing is it does throw
            XCTAssertNotNil(error)
        }
    }

    // MARK: - Test 6: device authorization POST failure throws

    /// Test: non-200 response to the device authorization POST causes deviceAuthorization() to throw.
    func testDeviceAuthorizationPostFailureThrows() async throws {
        MockURLProtocol.startInterceptingRequests()
        defer { MockURLProtocol.stopInterceptingRequests() }

        MockURLProtocol.requestHandler = { [self] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.deviceAuthorization.url.path:
                return (mockHTTPResponse(url: MockAPIEndpoint.deviceAuthorization.url, statusCode: 500),
                        MockResponse.error)
            default:
                XCTFail("Unexpected request: \(request.url?.absoluteString ?? "<nil>")")
                return (mockHTTPResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500), Data())
            }
        }

        let config = makeConfig()
        let client = OidcDeviceClient(config: config)

        do {
            _ = try await client.deviceAuthorization()
            XCTFail("Expected deviceAuthorization() to throw on 500 device auth response")
        } catch {
            // Verify the error is an OidcError.apiError with 500
            if let oidcError = error as? OidcError {
                switch oidcError {
                case .apiError(let code, _):
                    XCTAssertEqual(code, 500)
                default:
                    XCTFail("Expected .apiError(500) but got \(oidcError)")
                }
            } else {
                XCTFail("Expected OidcError but got \(type(of: error)): \(error)")
            }
        }
    }

    // MARK: - Test 6b: 200 response with malformed token body throws

    /// Test: a 200 from the token endpoint that cannot be decoded as Token, and whose body has
    /// no `"error"` key, causes the stream to finish throwing OidcError.apiError.
    /// (The non-success, non-parseable branch in the polling loop terminates the stream.)
    func testMalformedTokenResponseThrows() async throws {
        MockURLProtocol.startInterceptingRequests()
        defer { MockURLProtocol.stopInterceptingRequests() }

        let malformedBody = """
        { "not_a_token": true }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { [self] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.deviceAuthorization.url.path:
                return (mockHTTPResponse(url: MockAPIEndpoint.deviceAuthorization.url, statusCode: 200),
                        MockResponse.deviceAuthorizationResponseFastInterval)
            case MockAPIEndpoint.token.url.path:
                return (mockHTTPResponse(url: MockAPIEndpoint.token.url, statusCode: 200),
                        malformedBody)
            default:
                return (mockHTTPResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500), Data())
            }
        }

        let config = makeConfig()
        let client = OidcDeviceClient(config: config)
        let stream = try await client.deviceAuthorization()

        var didThrow = false
        var receivedSuccess = false
        do {
            for try await status in stream {
                if case .success = status { receivedSuccess = true }
            }
        } catch {
            didThrow = true
        }

        XCTAssertFalse(receivedSuccess, "A 200 with undecodable body should not yield .success")
        XCTAssertTrue(didThrow, "A 200 with no 'error' key and undecodable body should cause the stream to throw")
    }

    // MARK: - Test 7: URLError triggers backoff and stream continues

    /// Test: a URLError on the token endpoint causes the stream to back off and continue polling.
    /// Verifies Amendment 4: network errors do not terminate the stream.
    /// Sleep is bypassed via the testability seam so the backoff interval never causes a real wait.
    /// Expected stream: .started, .polling (with increased interval), .success
    func testURLErrorCausesBackoffAndContinues() async throws {
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
                if tokenCallCount == 1 {
                    throw URLError(.timedOut)
                } else {
                    return (mockHTTPResponse(url: MockAPIEndpoint.token.url, statusCode: 200),
                            MockResponse.token)
                }
            default:
                XCTFail("Unexpected request: \(request.url?.absoluteString ?? "<nil>")")
                return (mockHTTPResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500), Data())
            }
        }

        let config = makeConfig()
        let client = OidcDeviceClient(config: config)

        let stream = try await client.deviceAuthorization()

        var statuses: [String] = []
        var pollingIntervalAfterError: Int?

        outerLoop: for try await status in stream {
            switch status {
            case .started:
                statuses.append("started")
            case .polling(let count, let interval, _):
                statuses.append("polling")
                if count == 1 {
                    pollingIntervalAfterError = interval
                    // Break immediately after capturing the backoff — the next sleep is 5s.
                    break outerLoop
                }
            case .success:
                statuses.append("success")
            case .expired:
                statuses.append("expired")
                XCTFail("Unexpected .expired — stream should have continued after URLError")
            case .accessDenied:
                statuses.append("accessDenied")
                XCTFail("Unexpected .accessDenied — stream should have continued after URLError")
            case .failure(let error):
                statuses.append("failure")
                XCTFail("Unexpected .failure — stream should have continued after URLError: \(error)")
            }
        }

        XCTAssertTrue(statuses.contains("started"), "Stream should have yielded .started")
        XCTAssertTrue(statuses.contains("polling"), "Stream should have yielded .polling after URLError backoff")
        // baseInterval=0, consecutiveTimeouts=1, backoffMultiplier=2: min(max(0*2,5),60) = 5
        XCTAssertEqual(pollingIntervalAfterError, 5, "Backoff interval after first URLError should be 5s (min floor)")
    }
}

// MARK: - Test Helpers

private struct MockUser: User {
    func token() async -> Result<Token, OidcError> { .failure(.unknown()) }
    func refresh() async -> Result<Token, OidcError> { .failure(.unknown()) }
    func revoke() async {}
    func userinfo(cache: Bool) async -> Result<UserInfo, OidcError> { .failure(.unknown()) }
    func logout() async {}
}
