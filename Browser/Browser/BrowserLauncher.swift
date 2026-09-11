//
//  Browser.swift
//  Browser
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import AuthenticationServices
import PingLogger
#if canImport(UIKit)
import SafariServices
import Combine
import UIKit
#endif

// MARK: - Enums
/// BrowserType enum to specify the type of external user-agent;
/// ASWebAuthenticationSession, Native Browser App,  SFSafariViewController,
/// or ASWebAuthenticationSession with prefersEphemeralWebBrowserSession set to true
public enum BrowserType: Int, Sendable {
    case authSession = 0
    case nativeBrowserApp = 1
    case sfViewController = 2
    case ephemeralAuthSession = 3
}

/// BrowserError enum to specify the error that may occur during external user-agent process
public enum BrowserError: Error, LocalizedError, Sendable {
    case externalUserAgentFailure
    case externalUserAgentAuthenticationInProgress
    case externalUserAgentCancelled
    case httpsCallbackUnsupportedOS
    case invalidHTTPSRedirectConfiguration

    public var errorDescription: String? {
        switch self {
        case .externalUserAgentFailure:
            return "The external user agent failed to launch or complete authentication."
        case .externalUserAgentAuthenticationInProgress:
            return "An authentication session is already in progress."
        case .externalUserAgentCancelled:
            return "The authentication was cancelled by the user."
        case .httpsCallbackUnsupportedOS:
            return "An https redirect URI requires iOS 17.4+ or macOS 14.4+ to be intercepted by ASWebAuthenticationSession. On earlier OS versions, register a custom-scheme redirect URI with the identity provider as a fallback. (For .sfViewController or .nativeBrowserApp browser types, https Universal Link redirects are already supported on iOS 16.0-17.3 via OpenURLMonitor; this error is specific to .authSession and .ephemeralAuthSession.)"
        case .invalidHTTPSRedirectConfiguration:
            return "The https redirect URI does not contain a host and cannot be used to construct an OS-brokered callback."
        }
    }
}

/// BrowserMode enum to specify the mode of the browser
public enum BrowserMode: Sendable {
    case login
    case logout
    case custom
}

// MARK: - Protocol
/// A protocol to abstract the BrowserLauncher functionality (if not already provided).
/// (If your project already has a protocol that BrowserLauncher conforms to, you can use it.)
@MainActor
public protocol BrowserLauncherProtocol: Sendable {
    var isInProgress: Bool { get }
    func launch(url: URL, customParams: [String: String]?,
                browserType: BrowserType, browserMode: BrowserMode, callbackURLScheme: String, logger: Logger) async throws -> URL
    func launch(url: URL, customParams: [String: String]?,
                browserType: BrowserType, browserMode: BrowserMode, callbackURLScheme: String, redirectUri: String?, logger: Logger) async throws -> URL
    func reset()
    func handleAppActivation()
}

// MARK: - BrowserLauncherProtocol default implementation

extension BrowserLauncherProtocol {
    /// Default implementation of the `redirectUri`-aware `launch` overload.
    ///
    /// Conformers that only implement the legacy 6-arg `launch` continue to compile and behave
    /// identically: `redirectUri` is dropped and the call is forwarded to the existing method.
    public func launch(url: URL, customParams: [String: String]?,
                        browserType: BrowserType, browserMode: BrowserMode, callbackURLScheme: String, redirectUri: String?, logger: Logger) async throws -> URL {
        return try await launch(url: url, customParams: customParams, browserType: browserType, browserMode: browserMode, callbackURLScheme: callbackURLScheme, logger: logger)
    }
}

// MARK: - BrowserLauncher

#if canImport(UIKit)
/// BrowserLauncher class to launch external user-agent for web requests
@MainActor
public final class BrowserLauncher: NSObject, BrowserLauncherProtocol {
    
    // MARK: Internal State
    private enum State {
        case idle
        case launching
        case authenticating(session: Any) // Holds ASWebAuthenticationSession or SFSafariViewController
        case closing
    }
    
    // MARK: Properties
    
    /// Static shared instance
    public static var currentBrowser: BrowserLauncherProtocol = BrowserLauncher()
    
    public var isInProgress: Bool {
        if case .idle = state { return false }
        return true
    }
    
    private var state: State = .idle
    private var browserType: BrowserType = .authSession
    private var browserMode: BrowserMode = .login
    private var logger: Logger = LogManager.logger
    
    // Concurrency & Combine
    private var loginContinuation: CheckedContinuation<URL, Error>?
    private var cancellable: AnyCancellable?

    /// Identifies the `ASWebAuthenticationSession` currently held by `state`, so the session's own
    /// `completion` closure can tell a late callback for a stale/replaced session (ignore, exactly as
    /// `reset()` already expects) apart from this session's own eventual terminal callback (must
    /// still finalize via `cleanup()`, so `state` doesn't leak). A value-type token is used instead
    /// of capturing the `ASWebAuthenticationSession` instance itself in `completion`, because
    /// `ASWebAuthenticationSession` retains its `completionHandler` — capturing the session back
    /// from inside that same handler would create a retain cycle (session -> completion -> session).
    private var activeAuthSessionToken: UUID?
    
    // MARK: - Public Methods
    
    /// Handles app activation event
    public func handleAppActivation() {
        // If we are using the Native Browser (jumping out of app), and the app comes back
        // to foreground without a URL callback, we assume the user cancelled/switched back manually.
        if case .authenticating(let session) = state, session is String { // "String" marker used for Native Browser
            logger.i("App became active during native browser authentication. Cancelling.")
            reset()
        }
    }
    
    /// Resets the browser state, cancels continuations, and dismisses controllers.
    public func reset() {
        logger.i("Resetting the browser. Current state: \(state)")
        
        guard case .authenticating(let session) = state else {
            // If we are launching or closing, we still might need to clean up continuation
            if loginContinuation != nil {
                forceCancelContinuation()
                cleanup()
            } else {
                logger.w("Browser is not in a state that requires reset.", error: nil)
            }
            return
        }
        
        state = .closing
        
        // 1. Capture and Nil the continuation to prevent double-resume
        let pendingContinuation = self.loginContinuation
        self.loginContinuation = nil
        
        // 2. Resume with cancellation error immediately
        pendingContinuation?.resume(throwing: BrowserError.externalUserAgentCancelled)
        
        // 3. Handle Session Cleanup
        if let sfViewController = session as? SFSafariViewController {
            logger.i("Dismissing SFSafariViewController")
            sfViewController.dismiss(animated: false) { [weak self] in
                self?.cleanup()
            }
        } else if let asAuthSession = session as? ASWebAuthenticationSession {
            logger.i("Cancelling ASWebAuthenticationSession")
            // This triggers the completion handler, but we nilled the continuation above, so it's safe.
            asAuthSession.cancel()
            cleanup()
        } else {
            // Native browser or unknown
            logger.i("Resetting non-UI session")
            cleanup()
        }
    }
    
    /// Launches external user-agent for web requests
    /// - Parameters:
    ///   - url: URL to follow for the external user-agent
    ///   - customParams: Any custom URL query parameters to be passed as URL parameters in the request
    ///   - browserType: BrowserType enum to specify the type of external user-agent
    ///   - browserMode: BrowserMode enum to specify the mode of the browser; login, logout, or custom
    ///   - callbackURLScheme: The callbackURLScheme to be used for returning to the app. Used in ASWebAuthenticationSession modes
    ///   - Returns: URL of the external user-agent
    ///   - Throws: BrowserError
    public func launch(url: URL, customParams: [String: String]? = nil,
                       browserType: BrowserType = .authSession, browserMode: BrowserMode = .login, callbackURLScheme: String, logger: Logger = LogManager.logger) async throws -> URL {
        return try await launch(url: url, customParams: customParams, browserType: browserType, browserMode: browserMode, callbackURLScheme: callbackURLScheme, redirectUri: nil, logger: logger)
    }

    /// Launches external user-agent for web requests
    /// - Parameters:
    ///   - url: URL to follow for the external user-agent
    ///   - customParams: Any custom URL query parameters to be passed as URL parameters in the request
    ///   - browserType: BrowserType enum to specify the type of external user-agent
    ///   - browserMode: BrowserMode enum to specify the mode of the browser; login, logout, or custom
    ///   - callbackURLScheme: The callbackURLScheme to be used for returning to the app. Used in ASWebAuthenticationSession modes
    ///   - redirectUri: The full redirect URI, used to determine whether an OS-brokered https callback can be used. Used in ASWebAuthenticationSession modes
    ///   - Returns: URL of the external user-agent
    ///   - Throws: BrowserError
    public func launch(url: URL, customParams: [String: String]? = nil,
                       browserType: BrowserType = .authSession, browserMode: BrowserMode = .login, callbackURLScheme: String, redirectUri: String?, logger: Logger = LogManager.logger) async throws -> URL {
        self.logger = logger

        guard case .idle = state else {
            logger.e("Attempted to launch browser while another session is in progress", error: nil)
            throw BrowserError.externalUserAgentAuthenticationInProgress
        }

        state = .launching
        self.browserType = browserType
        self.browserMode = browserMode

        // Prepare URL
        let finalUrl = appendCustomParams(to: url, params: customParams)

        logger.i("Launching browser type: \(browserType) for URL: \(finalUrl.absoluteString)")

        return try await performLaunch(url: finalUrl, browserType: browserType, browserMode: browserMode, callbackURLScheme: callbackURLScheme, redirectUri: redirectUri)
    }
    
    // MARK: - Private Helpers
    
    private func appendCustomParams(to url: URL, params: [String: String]?) -> URL {
        guard let params = params, !params.isEmpty else { return url }
        
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
        let queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        if var existingItems = urlComponents?.queryItems {
            existingItems.append(contentsOf: queryItems)
            urlComponents?.queryItems = existingItems
        } else {
            urlComponents?.queryItems = queryItems
        }
        
        return urlComponents?.url ?? url
    }

    /// Whether `browserMode` indicates present-only ("resolve on presentation, never wait for a
    /// callback") behavior. Centralized so all three presentation paths agree on the same semantics.
    /// - Parameter browserMode: The mode passed to `launch()`.
    /// - Returns: `true` for `.custom`; `false` for `.login`/`.logout`.
    static func isPresentOnlyMode(_ browserMode: BrowserMode) -> Bool {
        browserMode == .custom
    }

    /// Classifies a redirect URI for use as an OS-brokered `ASWebAuthenticationSession` https callback.
    ///
    /// This is pure string/URL classification logic with no OS-availability dependency, so it is
    /// fully testable headless. It does not reference `ASWebAuthenticationSession.Callback`.
    /// - Parameter redirectUri: The full redirect URI configured for the OIDC/web flow, if any.
    /// - Returns: `(host, path)` when `redirectUri` is a parseable `https` URL with a host
    ///   (an empty path is normalized to `"/"`); `nil` for a `nil` input, a non-parseable string,
    ///   a custom scheme, an `http` scheme, or an `https` URL with no host.
    static func httpsCallbackComponents(from redirectUri: String?) -> (host: String, path: String)? {
        guard let redirectUri = redirectUri else { return nil }
        return httpsCallbackComponents(fromParsed: URLComponents(string: redirectUri))
    }

    /// Classifies an already-parsed redirect URI for use as an OS-brokered
    /// `ASWebAuthenticationSession` https callback.
    ///
    /// Callers that also need the scheme can parse `URLComponents` once and feed it to both checks,
    /// avoiding a second parse of the same string (and any risk of two parsers disagreeing).
    /// - Parameter components: The parsed redirect URI, if it was parseable.
    /// - Returns: `(host, path)` when `components` describes an `https` URL with a host
    ///   (an empty path is normalized to `"/"`); `nil` for `nil`, a custom scheme, an `http`
    ///   scheme, or an `https` URL with no host.
    static func httpsCallbackComponents(fromParsed components: URLComponents?) -> (host: String, path: String)? {
        guard let components = components,
              components.scheme?.lowercased() == "https",
              let host = components.host, !host.isEmpty else {
            return nil
        }

        let path = components.path.isEmpty ? "/" : components.path
        return (host: host, path: path)
    }

    /// Performs the launch based on the specified browser type
    /// - Parameters:
    ///  - url: The URL to be opened
    ///  - browserType: The type of browser to be used
    ///  - browserMode: BrowserMode enum to specify the mode of the browser; login, logout, or custom (present-only)
    ///  - callbackURLScheme: The callback URL scheme for the app
    ///  - redirectUri: The full redirect URI, used to determine whether an OS-brokered https callback can be used
    ///  - Returns: The URL after authentication is complete
    ///  - Throws: An error if the launch fails
    private func performLaunch(url: URL, browserType: BrowserType, browserMode: BrowserMode, callbackURLScheme: String, redirectUri: String?) async throws -> URL {
        switch browserType {
        case .nativeBrowserApp:
            return try await loginWithNativeBrowser(url: url, callbackURLScheme: callbackURLScheme, browserMode: browserMode)
        case .sfViewController:
            return try await loginWithSFViewController(url: url, callbackURLScheme: callbackURLScheme, browserMode: browserMode)
        case .authSession:
            return try await asWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme, redirectUri: redirectUri, browserMode: browserMode, prefersEphemeralWebBrowserSession: false)
        case .ephemeralAuthSession:
            return try await asWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme, redirectUri: redirectUri, browserMode: browserMode, prefersEphemeralWebBrowserSession: true)
        }
    }
    
    /// Performs authentication through /authorize endpoint using SFSafariViewController
    /// - Parameters:
    ///   - url: URL of /authorize including all URL query parameter
    /// - Returns: URL after authentication is complete
    /// - Throws: BrowserError if the view controller cannot be presented
    private func forceCancelContinuation() {
        if let continuation = loginContinuation {
            continuation.resume(throwing: BrowserError.externalUserAgentCancelled)
            loginContinuation = nil
        }
    }
    
    // Cleans up the cancelables and continuations
    private func cleanup() {
        cancellable?.cancel()
        cancellable = nil
        loginContinuation = nil // Ensure nil
        activeAuthSessionToken = nil
        state = .idle
        logger.i("Browser session cleaned up.")
    }

    /// Whether `token` matches the currently active `ASWebAuthenticationSession`'s token — i.e.
    /// whether a callback carrying `token` belongs to the session `state` currently holds, rather
    /// than a stale/replaced one. Pure and headless-testable, mirroring `httpsCallbackComponents`.
    /// - Parameters:
    ///   - token: The token captured by a specific `asWebAuthenticationSession` invocation's `completion` closure.
    ///   - activeToken: `activeAuthSessionToken` at the time the callback fires.
    /// - Returns: `true` if `token` still matches `activeToken`.
    static func isActiveSessionToken(_ token: UUID, activeToken: UUID?) -> Bool {
        token == activeToken
    }
    
    // MARK: - Specific Browser Implementations
    
    /// Performs authentication through /authorize endpoint using Native Browser
    /// - Parameters:
    ///   - url: URL of /authorize including all URL query parameter
    ///   - callbackURLScheme: Callback URL Scheme to return to the app
    ///   - browserMode: BrowserMode enum to specify the mode of the browser; login, logout, or custom (present-only)
    /// - Returns: URL after authentication is complete
    /// - Throws: BrowserError if authentication fails
    private func loginWithNativeBrowser(url: URL, callbackURLScheme: String, browserMode: BrowserMode) async throws -> URL {
        let opened = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            UIApplication.shared.open(url, options: [:]) { success in
                cont.resume(returning: success)
            }
        }

        guard opened else {
            state = .idle
            throw BrowserError.externalUserAgentFailure
        }

        if BrowserLauncher.isPresentOnlyMode(browserMode) {
            // Present-only: control has already left our app for a different app (Safari). There's
            // no in-app UI element for us to retain, so resolve to idle immediately rather than
            // waiting on a callback that, for this mode, is never coming — leaving `state` at
            // `.authenticating` here would also make `handleAppActivation()`'s native-browser-cancel
            // heuristic misfire the next time the app foregrounds.
            logger.i("Present-only native browser launch succeeded; resolving without waiting for a callback.")
            cleanup()
            return url
        }

        state = .authenticating(session: "Native Browser")

        return try await withCheckedThrowingContinuation { continuation in
            self.loginContinuation = continuation
            self.observeCallback(scheme: callbackURLScheme)
        }
    }
    
    /// Performs authentication through /authorize endpoint using SFViewController
    /// - Parameters:
    ///   - url: URL of /authorize including all URL query parameter
    ///   - callbackURLScheme: Callback URL Scheme to return to the app
    ///   - browserMode: BrowserMode enum to specify the mode of the browser; login, logout, or custom (present-only)
    /// - Returns: URL after authentication is complete
    /// - Throws: BrowserError if authentication fails
    private func loginWithSFViewController(url: URL, callbackURLScheme: String, browserMode: BrowserMode) async throws -> URL {
        let safariVC = SFSafariViewController(url: url)
        safariVC.delegate = self
        safariVC.modalPresentationStyle = .fullScreen

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            logger.e("Fail to launch SFSafariViewController; missing presenting ViewController", error: nil)
            state = .idle
            throw BrowserError.externalUserAgentFailure
        }
        var presentingVC = root
        while let presented = presentingVC.presentedViewController,
              !presented.isBeingDismissed,
              !(presented is UIAlertController) {
            presentingVC = presented
        }

        // We set state BEFORE presenting to prevent race conditions
        state = .authenticating(session: safariVC)
        presentingVC.present(safariVC, animated: true)

        if BrowserLauncher.isPresentOnlyMode(browserMode) {
            // Present-only: the UI is now shown; resolve without waiting for a callback. No
            // continuation is ever created, so nothing can leak. `state` stays
            // `.authenticating(session: safariVC)`, keeping `safariVC` retained (so the sheet's own
            // dismiss still works via `safariViewControllerDidFinish` -> `reset()`) and `isInProgress`
            // `true` for as long as the sheet is shown.
            logger.i("Present-only SFSafariViewController presented; resolving without waiting for a callback.")
            return url
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.loginContinuation = continuation
            
            // For SFVC, we also listen for the URL callback via the Monitor
            self.cancellable = OpenURLMonitor.shared.urlPublisher
                .filter { $0.scheme == callbackURLScheme }
                .first()
                .sink { [weak self] url in
                    guard let self = self else { return }
                    
                    // SFVC flow successful
                    if let activeContinuation = self.loginContinuation {
                        activeContinuation.resume(returning: url)
                        self.loginContinuation = nil // Consumed
                    }
                    
                    self.state = .closing
                    
                    // Close the UI
                    safariVC.dismiss(animated: true) { [weak self] in
                        self?.cleanup()
                    }
                }
        }
    }
    
    /// Performs authentication through /authorize endpoint using ASWebAuthenticationSession
    /// - Parameters:
    ///   - url: URL of /authorize including all URL query parameter
    ///   - callbackURLScheme: Callback URL Scheme to return to the app
    ///   - redirectUri: The full redirect URI, used to determine whether an OS-brokered https callback can be used
    ///   - browserMode: BrowserMode enum to specify the mode of the browser; login, logout, or custom (present-only)
    ///   - prefersEphemeralWebBrowserSession: Set to true to use ephemeral web browser session
    /// - Returns: URL after authentication is complete
    /// - Throws: BrowserError if authentication fails
    private func asWebAuthenticationSession(url: URL, callbackURLScheme: String, redirectUri: String?,
                                            browserMode: BrowserMode, prefersEphemeralWebBrowserSession: Bool) async throws -> URL {

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(throwing: BrowserError.externalUserAgentFailure)
                return
            }

            self.loginContinuation = continuation

            // Identifies THIS invocation's session without ever capturing the session object itself
            // in `completion` below — see `activeAuthSessionToken`'s doc comment for why capturing
            // the object would create a retain cycle. A plain `let`, captured normally (by value,
            // like `self` further below): no forward-reference concerns, unlike the session itself.
            let sessionToken = UUID()

            // Shared completion handler, reused verbatim by both the legacy
            // `callbackURLScheme:` initializer and the (future) `Callback.https` initializer.
            // `@MainActor` because it touches `logger`/`loginContinuation`/`state`/`cleanup()`,
            // all isolated to this class's actor; `@Sendable` per the codebase convention of
            // explicitly annotating stored/escaping closures (a MainActor-isolated closure is
            // safely Sendable since its captured state is protected by actor isolation).
            let completion: @MainActor @Sendable (URL?, Error?) -> Void = { [weak self] callbackURL, error in
                guard let self = self else { return }

                self.logger.i("ASWebAuthenticationSession callback received")

                // Distinguish "a different/later session already replaced this one in `state`"
                // (reset()-then-stale-callback — must no-op, exactly as before) from "this session
                // is still the active one, but `loginContinuation` was already resolved early by
                // present-only mode" (must still finalize via cleanup(), so `state` doesn't leak).
                // Continuation presence alone can't distinguish these two cases.
                guard BrowserLauncher.isActiveSessionToken(sessionToken, activeToken: self.activeAuthSessionToken) else {
                    self.logger.i("Late ASWebAuthenticationSession callback for a session that is no longer active. Ignoring.")
                    return
                }

                let activeContinuation = self.loginContinuation
                self.loginContinuation = nil // Consume it, if present
                self.state = .closing

                if let activeContinuation {
                    if let error = error {
                        // Check for User Cancel
                        let nsError = error as NSError
                        if nsError.domain == ASWebAuthenticationSessionError.errorDomain,
                           nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                            activeContinuation.resume(throwing: BrowserError.externalUserAgentCancelled)
                        } else {
                            activeContinuation.resume(throwing: error)
                        }
                    } else if let url = callbackURL {
                        activeContinuation.resume(returning: url)
                    } else {
                        activeContinuation.resume(throwing: BrowserError.externalUserAgentFailure)
                    }
                } else {
                    self.logger.i("Present-only session finished with no pending continuation (already resolved on presentation).")
                }

                self.cleanup()
            }

            // Classify the redirect URI to decide which ASWebAuthenticationSession initializer to
            // use. Only a `https` scheme is eligible for the OS-brokered `Callback.https`
            // interception; a custom scheme, `http`, or a nil/non-parseable `redirectUri` all take
            // the legacy `callbackURLScheme:` initializer, byte-for-byte unchanged from today.
            // Parse once and derive both the scheme check and the callback components from the same
            // `URLComponents` value, so the two classifications can never disagree.
            let redirectComponents = redirectUri.flatMap { URLComponents(string: $0) }
            let rawScheme = redirectComponents?.scheme?.lowercased()
            let httpsComponents = BrowserLauncher.httpsCallbackComponents(fromParsed: redirectComponents)

            // Both branches below construct a plain `ASWebAuthenticationSession` instance —
            // `Callback.https` is an initializer overload, not a subclass — so `reset()`'s
            // `session as? ASWebAuthenticationSession` cast (see `reset()` above) is type-safe
            // and requires no change regardless of which initializer produced the session.
            let authSession: ASWebAuthenticationSession

            if rawScheme == "https" {
                if let (host, path) = httpsComponents {
                    if #available(iOS 17.4, macOS 14.4, *) {
                        self.logger.i("https redirect URI detected; using OS-brokered Callback.https")
                        authSession = ASWebAuthenticationSession(url: url, callback: .https(host: host, path: path), completionHandler: completion)
                    } else {
                        // https redirect with a derivable host, but the OS-brokered `Callback.https`
                        // API requires iOS 17.4+/macOS 14.4+. Fail fast rather than falling back to
                        // the legacy `callbackURLScheme:"https"` initializer, which cannot intercept
                        // an https redirect and would silently reproduce the SDKS-5239 hang.
                        // Mirrors the start()-fail exit below: resume, then nil the continuation,
                        // then log, then cleanup(). Never assign `.authenticating` or call `start()`.
                        self.loginContinuation?.resume(throwing: BrowserError.httpsCallbackUnsupportedOS)
                        self.loginContinuation = nil
                        self.logger.e("https redirect URI requires iOS 17.4+/macOS 14.4+ for .authSession/.ephemeralAuthSession", error: nil)
                        self.state = .closing
                        self.cleanup()
                        return
                    }
                } else {
                    // https redirect URI with no derivable host: cannot construct an OS-brokered
                    // callback. Fail fast before presenting any sheet, same discipline as above.
                    self.loginContinuation?.resume(throwing: BrowserError.invalidHTTPSRedirectConfiguration)
                    self.loginContinuation = nil
                    self.logger.e("https redirect URI has no derivable host; cannot construct an OS-brokered callback", error: nil)
                    self.state = .closing
                    self.cleanup()
                    return
                }
            } else {
                authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme, completionHandler: completion)
            }

            authSession.presentationContextProvider = self
            authSession.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession

            self.activeAuthSessionToken = sessionToken
            self.state = .authenticating(session: authSession)

            if !authSession.start() {
                self.logger.e("Failed to start ASWebAuthenticationSession", error: nil)
                self.state = .closing
                // Resume immediately on failure
                self.loginContinuation?.resume(throwing: BrowserError.externalUserAgentFailure)
                self.loginContinuation = nil
                self.cleanup()
            } else if BrowserLauncher.isPresentOnlyMode(browserMode) {
                // Present-only: presentation started successfully. Resolve now rather than waiting
                // for `completion`. Deliberately do NOT call cleanup()/dismiss here: `state` holds
                // the only strong reference to `authSession`, and releasing it would immediately
                // auto-dismiss the sheet, defeating the "stays open" requirement. `completion`
                // (above) finalizes `cleanup()` later, whenever the OS reports this session finished.
                self.logger.i("Present-only ASWebAuthenticationSession presented; resolving without waiting for a callback.")
                self.loginContinuation?.resume(returning: url)
                self.loginContinuation = nil
            }
        }
    }
    
    private func observeCallback(scheme: String) {
        // Used for Native Browser mode
        self.cancellable = OpenURLMonitor.shared.urlPublisher
            .filter { $0.scheme == scheme }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] url in
                guard let self = self, let continuation = self.loginContinuation else { return }
                continuation.resume(returning: url)
                self.loginContinuation = nil
                self.cleanup()
            }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension BrowserLauncher: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Fix: Return the actual window, not a new instance
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        
        return window ?? ASPresentationAnchor()
    }
}

// MARK: - SFSafariViewControllerDelegate

extension BrowserLauncher: SFSafariViewControllerDelegate {
    nonisolated public func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        Task { @MainActor [weak self] in
            self?.logger.i("User cancelled SFSafariViewController by closing the window")
            self?.reset()
        }
    }
    
    nonisolated public func safariViewController(_ controller: SFSafariViewController, initialLoadDidRedirectTo URL: URL) {}
}

// MARK: - OpenURLMonitor

/// A singleton that publishes all URLs your app is asked to open.
@MainActor
public final class OpenURLMonitor: NSObject {
    
    public static let shared = OpenURLMonitor()
    
    public let urlPublisher = PassthroughSubject<URL, Never>()
    
    private override init() {
        super.init()
    }
    
    @discardableResult
    public func handleOpenURL(_ url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        urlPublisher.send(url)
        return true
    }
}
#endif
