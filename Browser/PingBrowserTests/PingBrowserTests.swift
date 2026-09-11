//
//  PingBrowserTests.swift
//  PingBrowserTests
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingBrowser
@testable import PingExternalIdP
@testable import PingOrchestrate
@testable import PingNetwork
@testable import PingLogger
// MARK: - BrowserType Tests

@MainActor
final class BrowserTypeTests: XCTestCase {
    
    func testBrowserTypeRawValues() {
        XCTAssertEqual(BrowserType.authSession.rawValue, 0)
        XCTAssertEqual(BrowserType.nativeBrowserApp.rawValue, 1)
        XCTAssertEqual(BrowserType.sfViewController.rawValue, 2)
        XCTAssertEqual(BrowserType.ephemeralAuthSession.rawValue, 3)
    }
    
    func testBrowserTypeInitFromRawValue() {
        XCTAssertEqual(BrowserType(rawValue: 0), .authSession)
        XCTAssertEqual(BrowserType(rawValue: 1), .nativeBrowserApp)
        XCTAssertEqual(BrowserType(rawValue: 2), .sfViewController)
        XCTAssertEqual(BrowserType(rawValue: 3), .ephemeralAuthSession)
        XCTAssertNil(BrowserType(rawValue: 99))
    }
}

// MARK: - BrowserError Tests

@MainActor
final class BrowserErrorTests: XCTestCase {
    
    func testBrowserErrorEquality() {
        XCTAssertEqual(BrowserError.externalUserAgentFailure, BrowserError.externalUserAgentFailure)
        XCTAssertEqual(BrowserError.externalUserAgentAuthenticationInProgress, BrowserError.externalUserAgentAuthenticationInProgress)
        XCTAssertEqual(BrowserError.externalUserAgentCancelled, BrowserError.externalUserAgentCancelled)
    }
    
    func testBrowserErrorIsError() {
        let error: Error = BrowserError.externalUserAgentFailure
        XCTAssertNotNil(error)
    }

    func testHttpsCallbackUnsupportedOSHasNonEmptyDescription() {
        let description = BrowserError.httpsCallbackUnsupportedOS.errorDescription
        XCTAssertNotNil(description)
        XCTAssertFalse(description?.isEmpty ?? true)
    }

    func testInvalidHTTPSRedirectConfigurationHasNonEmptyDescription() {
        let description = BrowserError.invalidHTTPSRedirectConfiguration.errorDescription
        XCTAssertNotNil(description)
        XCTAssertFalse(description?.isEmpty ?? true)
    }
}

// MARK: - httpsCallbackComponents Tests

@MainActor
final class HttpsCallbackComponentsTests: XCTestCase {

    func testHttpsUrlWithPathReturnsHostAndPath() {
        let result = BrowserLauncher.httpsCallbackComponents(from: "https://www.mouser.com/auth/callback")
        XCTAssertEqual(result?.host, "www.mouser.com")
        XCTAssertEqual(result?.path, "/auth/callback")
    }

    func testHttpsUrlWithNoPathNormalizesToSlash() {
        let result = BrowserLauncher.httpsCallbackComponents(from: "https://example.com")
        XCTAssertEqual(result?.host, "example.com")
        XCTAssertEqual(result?.path, "/")
    }

    func testCustomSchemeReturnsNil() {
        XCTAssertNil(BrowserLauncher.httpsCallbackComponents(from: "myapp://callback"))
    }

    func testHttpSchemeReturnsNil() {
        XCTAssertNil(BrowserLauncher.httpsCallbackComponents(from: "http://example.com/cb"))
    }

    func testHttpsWithNoHostReturnsNil() {
        XCTAssertNil(BrowserLauncher.httpsCallbackComponents(from: "https://"))
    }

    func testNilRedirectUriReturnsNil() {
        XCTAssertNil(BrowserLauncher.httpsCallbackComponents(from: nil))
    }

    // The parsed overload is what `asWebAuthenticationSession` uses, so the string-based
    // classification above must stay equivalent to feeding it a single pre-parsed value.

    func testParsedOverloadMatchesStringOverload() {
        for redirectUri in ["https://www.mouser.com/auth/callback", "https://example.com", "myapp://callback", "http://example.com/cb", "https://"] {
            let fromString = BrowserLauncher.httpsCallbackComponents(from: redirectUri)
            let fromParsed = BrowserLauncher.httpsCallbackComponents(fromParsed: URLComponents(string: redirectUri))
            XCTAssertEqual(fromString?.host, fromParsed?.host, "host mismatch for \(redirectUri)")
            XCTAssertEqual(fromString?.path, fromParsed?.path, "path mismatch for \(redirectUri)")
        }
    }

    func testParsedOverloadWithNilComponentsReturnsNil() {
        XCTAssertNil(BrowserLauncher.httpsCallbackComponents(fromParsed: nil))
    }
}

// MARK: - BrowserMode Tests

@MainActor
final class BrowserModeTests: XCTestCase {

    func testBrowserModeValues() {
        let loginMode: BrowserMode = .login
        let logoutMode: BrowserMode = .logout
        let customMode: BrowserMode = .custom

        XCTAssertNotNil(loginMode)
        XCTAssertNotNil(logoutMode)
        XCTAssertNotNil(customMode)
    }

    func testCustomModeIsDistinctFromLoginAndLogout() {
        XCTAssertNotEqual(BrowserMode.custom, BrowserMode.login)
        XCTAssertNotEqual(BrowserMode.custom, BrowserMode.logout)
        XCTAssertNotEqual(BrowserMode.login, BrowserMode.logout)
    }
}

// MARK: - Present-only mode Tests
//
// `isPresentOnlyMode(_:)` and `isActiveSessionToken(_:activeToken:)` are the two pieces of the
// present-only (`browserMode: .custom`) behavior that are testable headless, mirroring
// `HttpsCallbackComponentsTests`. The latter is the actual decision logic behind the trickiest part
// of this feature — telling a late `ASWebAuthenticationSession` callback for a stale/replaced
// session apart from a present-only session's own eventual terminal callback — extracted specifically
// so it has direct coverage here rather than living only inside an untestable closure. Real
// "presentation success" coverage for `.sfViewController`/`.authSession`/`.ephemeralAuthSession`
// against the concrete `BrowserLauncher` class would still require either a live foreground
// window/scene plus a real, non-deterministically-dismissable OS sheet, or a dependency-injection
// seam that doesn't exist today (`state`/`loginContinuation` are `private`, no test-only accessor) —
// this is a pre-existing gap, not one present-only mode introduces: `BrowserLauncherTests` below
// already only exercises `reset()`/`handleAppActivation()` on an idle instance for the same reason,
// and none of the existing `.login`/`.logout` failure branches are unit-tested against the real
// class either. The present-only branches only add a new success-tail *after* presentation already
// succeeds — they don't touch any existing failure `guard`, and structurally can't leave a dangling
// continuation for `.sfViewController`/`.nativeBrowserApp` (the continuation is simply never
// constructed on that path).

@MainActor
final class PresentOnlyModeTests: XCTestCase {

    func testCustomModeIsPresentOnly() {
        XCTAssertTrue(BrowserLauncher.isPresentOnlyMode(.custom))
    }

    func testLoginModeIsNotPresentOnly() {
        XCTAssertFalse(BrowserLauncher.isPresentOnlyMode(.login))
    }

    func testLogoutModeIsNotPresentOnly() {
        XCTAssertFalse(BrowserLauncher.isPresentOnlyMode(.logout))
    }
}

// MARK: - Session token Tests

@MainActor
final class SessionTokenTests: XCTestCase {

    func testMatchingTokenIsActive() {
        let token = UUID()
        XCTAssertTrue(BrowserLauncher.isActiveSessionToken(token, activeToken: token))
    }

    func testDifferentTokenIsNotActive() {
        XCTAssertFalse(BrowserLauncher.isActiveSessionToken(UUID(), activeToken: UUID()))
    }

    func testNilActiveTokenIsNeverActive() {
        // Mirrors the state after `cleanup()`: any late callback for a session that has already
        // fully finished (or was never the active one) must be treated as stale, not active.
        XCTAssertFalse(BrowserLauncher.isActiveSessionToken(UUID(), activeToken: nil))
    }
}

// MARK: - OpenURLMonitor Tests

@MainActor
final class OpenURLMonitorTests: XCTestCase {
    
    func testOpenURLMonitorSharedInstance() {
        let monitor1 = OpenURLMonitor.shared
        let monitor2 = OpenURLMonitor.shared
        XCTAssertTrue(monitor1 === monitor2)
    }
    
    func testOpenURLMonitorHandleURLReturnsTrue() {
        let url = URL(string: "myapp://callback?code=123")!
        let result = OpenURLMonitor.shared.handleOpenURL(url)
        XCTAssertTrue(result)
    }
}

// MARK: - BrowserLauncher Tests

@MainActor
final class BrowserLauncherTests: XCTestCase {
    
    func testBrowserLauncherCurrentBrowserExists() {
        let browser = BrowserLauncher.currentBrowser
        XCTAssertNotNil(browser)
    }
    
    func testBrowserLauncherIsNotInProgressInitially() {
        let browser = BrowserLauncher()
        XCTAssertFalse(browser.isInProgress)
    }
    
    func testBrowserLauncherResetWhenIdle() {
        let browser = BrowserLauncher()
        // Should not crash when reset is called in idle state
        browser.reset()
        XCTAssertFalse(browser.isInProgress)
    }
    
    func testBrowserLauncherHandleAppActivationWhenIdle() {
        let browser = BrowserLauncher()
        // Should not crash when called in idle state
        browser.handleAppActivation()
        XCTAssertFalse(browser.isInProgress)
    }
}

/// Tests for the BrowserHandler class.
@MainActor
final class PingBrowserTests: XCTestCase {
    
    // Hold a reference to the original browser so that we can restore it in tearDown.
    var originalBrowser: BrowserLauncherProtocol!
    var mockBrowser: MockBrowserLauncher!
    var connector: TestContinueNode!
    let continueURL = "https://example.com/continue"
    
    override func setUp() async throws {
        Task {
            try await super.setUp()
        }
        // Save the original BrowserLauncher and replace it with our mock.
        // (Assumes that BrowserLauncher.currentBrowser is mutable and of type BrowserLauncherProtocol.)
        originalBrowser = BrowserLauncher.currentBrowser
        mockBrowser = MockBrowserLauncher()
        BrowserLauncher.currentBrowser = mockBrowser
        
        // Create a mock ContinueNode with the expected _links structure.
        let mockWorkflow = WorkflowMock(config: WorkflowConfig())
        let mockContext = FlowContextMock(flowContext: SharedContext())
        let mockNode = NodeMock()
        
        mockWorkflow.nextReturnValue = mockNode
        
        
        connector = TestContinueNode(context: mockContext, workflow: mockWorkflow, input: [
            NetworkConstants._links: [
                NetworkConstants.continue: [
                    NetworkConstants.href: continueURL
                ]
            ]
        ], actions: [])
    }
    
    override func tearDown() async throws {
        // Restore the original BrowserLauncher.
        BrowserLauncher.currentBrowser = originalBrowser
        originalBrowser = nil
        mockBrowser = nil
        connector =  nil
        Task {
            try await super.tearDown()
        }
    }
    
    func testCurrentBrowser() throws {
        let browser = BrowserLauncher.currentBrowser
        XCTAssertNotNil(browser)
        XCTAssertFalse(browser.isInProgress)
    }
    
    /// Tests that a successful authorization produces a Request with the correct URL, header, and body.
    func testAuthorizeSuccess() async throws {
        // Arrange
        let continueToken = "abc123"
        // Simulate the browser launcher returning a URL that includes the continueToken in the query.
        let browserReturnURL = URL(string: "myapp://callback?continueToken=\(continueToken)")!
        mockBrowser.launchHandler = { url, browserType, callbackURLScheme in
            return browserReturnURL
        }
        
        let handler = BrowserHandler(continueNode: connector, callbackURLScheme: "myapp")
        let url = URL(string: "https://auth.example.com")!
        
        // Act
        let request = try await handler.authorize(url: url)
        
        // Assert
        XCTAssertEqual(request.url, continueURL)
        XCTAssertEqual(request.getHeader(name: NetworkConstants.headerAuthorization), "Bearer \(continueToken)")
        XCTAssertEqual(request.getMethod(), HttpMethod.post)
    }
    
    
    /// Tests that calling authorize with a nil URL throws an illegalArgumentException.
    func testAuthorizeNilURL() async {
        // Arrange
        let handler = BrowserHandler(continueNode: connector, callbackURLScheme: "myapp")
        // Act & Assert
        do {
            let url: URL? = nil
            _ = try await handler.authorize(url: url)
            XCTFail("Expected an exception when URL is nil.")
        } catch let error as IdpExceptions {
            XCTAssertEqual(error.errorMessage, "illegalArgumentException Idp Exception: continueUrl not found")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    /// Tests that if the BrowserLauncher fails (throws an error), authorize throws an illegalStateException.
    func testAuthorizeBrowserLauncherFailure() async {
        // Arrange
        mockBrowser.launchHandler = { url, browserType, callbackURLScheme in
            throw BrowserError.externalUserAgentFailure
        }
        
        let handler = BrowserHandler(continueNode: connector, callbackURLScheme: "myapp")
        let url = URL(string: "https://auth.example.com")!
        
        // Act & Assert
        do {
            _ = try await handler.authorize(url: url)
            XCTFail("Expected an exception due to BrowserLauncher failure.")
        } catch let error as IdpExceptions {
            XCTFail("Unexpected error type: \(error)")
        } catch  let error as BrowserError {
            XCTAssertEqual(error, BrowserError.externalUserAgentFailure)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    /// Tests that if the browser returns a URL without query items, authorize throws an illegalStateException.
    func testAuthorizeMissingQueryItems() async {
        // Arrange: the browser returns a URL with no query items.
        let browserReturnURL = URL(string: "myapp://callback")!
        mockBrowser.launchHandler = { url, browserType, callbackURLScheme in
            return browserReturnURL
        }
        
        let handler = BrowserHandler(continueNode: connector, callbackURLScheme: "myapp")
        let url = URL(string: "https://auth.example.com")!
        
        // Act & Assert
        do {
            _ = try await handler.authorize(url: url)
            XCTFail("Expected an exception due to missing query items in the response URL.")
        } catch let error as IdpExceptions {
            XCTAssertEqual(error.errorMessage, "illegalStateException Idp Exception: Could not read response URL")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    /// Tests that if the continueToken parameter is missing from the browser response URL, authorize throws an illegalStateException.
    func testAuthorizeMissingContinueToken() async {
        // Arrange: the browser returns a URL with a query parameter that is not continueToken.
        let browserReturnURL = URL(string: "myapp://callback?otherParam=value")!
        mockBrowser.launchHandler = { url, browserType, callbackURLScheme in
            return browserReturnURL
        }
        
        let handler = BrowserHandler(continueNode: connector, callbackURLScheme: "myapp")
        let url = URL(string: "https://auth.example.com")!
        
        // Act & Assert
        do {
            _ = try await handler.authorize(url: url)
            XCTFail("Expected an exception due to missing continueToken in the URL query items.")
        } catch let error as IdpExceptions {
            XCTAssertEqual(error.errorMessage, "illegalStateException Idp Exception: Could not read continueToken")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}

/// Supporting Test Classes
class WorkflowMock: Workflow, @unchecked Sendable {
    var nextReturnValue: Node?
    override func next(_ context: FlowContext, _ current: ContinueNode) async -> Node {
        return NodeMock()
    }
}

class FlowContextMock: FlowContext, @unchecked Sendable {}

final class NodeMock: Node {}

class TestContinueNode: ContinueNode, @unchecked Sendable {
    override func asRequest() -> Request {
        let request = RequestMock()
        request.url = "https://openam.example.com"
        return request
    }
}

class RequestMock: URLSessionHttpRequest, @unchecked Sendable {}

/// A mock BrowserLauncher that you can control in tests.
class MockBrowserLauncher: BrowserLauncherProtocol {
    func handleAppActivation() {
        // No-op for mock
    }
    
    func reset() {
        self.isInProgress = false
    }
    
    var isInProgress: Bool = false

    /// A closure that will be called when `launch` is invoked.
    var launchHandler: ((URL, BrowserType, String) async throws -> URL)?

    /// Records the `browserMode` most recently passed to `launch`, independent of `launchHandler`
    /// (whose closure signature predates `browserMode` and doesn't carry it), so tests can assert
    /// on it without changing `launchHandler`'s signature for every existing caller.
    var capturedBrowserMode: BrowserMode?

    func launch(url: URL, customParams: [String : String]?, browserType: PingBrowser.BrowserType, browserMode: PingBrowser.BrowserMode, callbackURLScheme: String, logger: Logger = LogManager.logger) async throws -> URL {
        capturedBrowserMode = browserMode
        if let handler = launchHandler {
            return try await handler(url, browserType, callbackURLScheme)
        }
        throw NSError(domain: "MockBrowserLauncher", code: 0, userInfo: nil)
    }
}

// MARK: - BrowserLauncherProtocol backward-compat Tests

/// Verifies that a conformer implementing ONLY the legacy 6-arg `launch` (`MockBrowserLauncher`)
/// still satisfies `BrowserLauncherProtocol`, and that invoking the 7-arg `redirectUri`-aware
/// overload on it forwards to the 6-arg implementation via the protocol's default implementation.
@MainActor
final class BrowserLauncherProtocolBackwardCompatTests: XCTestCase {

    func testSevenArgOverloadForwardsToSixArgViaDefaultImplementation() async throws {
        let mock = MockBrowserLauncher()
        var capturedURL: URL?
        var capturedBrowserType: BrowserType?
        var capturedCallbackURLScheme: String?
        let expectedURL = URL(string: "https://auth.example.com")!
        let expectedReturnURL = URL(string: "myapp://callback?code=abc")!

        mock.launchHandler = { url, browserType, callbackURLScheme in
            capturedURL = url
            capturedBrowserType = browserType
            capturedCallbackURLScheme = callbackURLScheme
            return expectedReturnURL
        }

        // `mock` only implements the 6-arg requirement; the 7-arg call below resolves to the
        // protocol extension's default implementation, which drops `redirectUri` and forwards.
        let launcher: BrowserLauncherProtocol = mock
        let result = try await launcher.launch(
            url: expectedURL,
            customParams: nil,
            browserType: .authSession,
            browserMode: .login,
            callbackURLScheme: "myapp",
            redirectUri: "https://host/path",
            logger: LogManager.logger
        )

        XCTAssertEqual(result, expectedReturnURL)
        XCTAssertEqual(capturedURL, expectedURL)
        XCTAssertEqual(capturedBrowserType, .authSession)
        XCTAssertEqual(capturedCallbackURLScheme, "myapp")
    }

    /// Confirms the protocol-level default implementation forwards `browserMode: .custom`
    /// untouched, with no protocol-level special-casing introduced for present-only mode.
    func testCustomBrowserModeForwardsThroughDefaultImplementation() async throws {
        let mock = MockBrowserLauncher()
        var capturedURL: URL?
        let expectedURL = URL(string: "https://auth.example.com")!
        let expectedReturnURL = URL(string: "https://auth.example.com")!

        mock.launchHandler = { url, browserType, callbackURLScheme in
            capturedURL = url
            return expectedReturnURL
        }

        let launcher: BrowserLauncherProtocol = mock
        let result = try await launcher.launch(
            url: expectedURL,
            customParams: nil,
            browserType: .sfViewController,
            browserMode: .custom,
            callbackURLScheme: "myapp",
            redirectUri: nil,
            logger: LogManager.logger
        )

        XCTAssertEqual(result, expectedReturnURL)
        XCTAssertEqual(capturedURL, expectedURL)
        XCTAssertEqual(mock.capturedBrowserMode, .custom)
    }
}
