// 
//  OidcLogin.swift
//  Oidc
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingOrchestrate
import PingLogger
import PingBrowser

public typealias OidcWebClient = Workflow

/// OidcWebClientConfig is a subclass of WorkflowConfig
/// - Parameters:
///   - config: The configuration for the OIDC workflow.
///   - Returns: An instance of OidcWebClient configured for OIDC login.
public class OidcWebClientConfig: WorkflowConfig, @unchecked Sendable {
    /// Browser type used for OIDC login.
    public var browserType: BrowserType = .authSession
    /// The mode of the browser for OIDC login.
    public var browserMode: BrowserMode = .login
}

/// OidcOptions is a struct that holds additional parameters for OIDC login.
public struct OidcOptions: Sendable {
    /// Additional parameters for OIDC login.
    public var additionalParameters: [String: String] = [:]
}

public extension OidcWebClient {
    /// Creates an OIDC login instance with the provided configuration block.
    /// - Parameter block: A closure to configure the OIDC options.
    /// - Returns: An instance of OidcWebClient configured for OIDC login.
    static func createOidcWebClient(block: @Sendable (OidcWebClientConfig) -> Void = {_ in }) -> OidcWebClient {
        let config = OidcWebClientConfig()
        config.timeout = 30
        
        config.module(OidcModule.config)
        #if canImport(UIKit)
        config.module(WebModule.config)
        #endif
        // Apply custom configuration
        block(config)
        
        return OidcWebClient(config: config)
    }
    
    /// Creates an OidcWebClient instance from a JSON dictionary.
    ///
    /// This factory parses and validates a platform-neutral JSON configuration and
    /// delegates to `createOidcWebClient(block:)` with the extracted values. Unknown
    /// fields are silently ignored for forward compatibility.
    ///
    /// `discoveryEndpoint` is required unless an `openId` sub-object is supplied. When `openId` is
    /// supplied without `discoveryEndpoint` it replaces the discovery document (no network call) and
    /// `tokenEndpoint` becomes required. When both are supplied, discovery runs and `openId` patches
    /// the discovered document.
    ///
    /// - Parameter json: A `[String: Any]` dictionary conforming to the unified SDK
    ///   configuration schema (see design doc for field reference).
    /// - Returns: `.success(OidcWebClient)` on valid input, `.failure(JsonConfigError)` if a
    ///   required field is absent or a field has the wrong type.
    static func createOidcWebClient(json: [String: Any]) -> Result<OidcWebClient, Error> {
        do {
            let p = JsonConfigParser(json)
            let timeout = try p.timeoutSeconds()
            let logger  = p.logLevel()
            let oidcDict: [String: Any] = try p.required(JsonConfigKey.oidc, field: JsonConfigKey.oidc)

            let oidcConfig = try OidcClientConfig.from(oidcJson: oidcDict, logger: logger)

            let client = OidcWebClient.createOidcWebClient { webConfig in
                webConfig.timeout = timeout
                webConfig.logger = logger
                webConfig.module(OidcModule.config) { moduleOidcConfig in
                    moduleOidcConfig.update(with: oidcConfig)
                }
            }
            return .success(client)
        } catch {
            return .failure(error)
        }
    }

    /// This method initializes the OIDC client and starts the login process.
    /// - Parameter configure: A closure to configure the OIDC options.
    /// - Returns: A Result containing the User or an OidcError. When the underlying `Node` is a
    ///   `FailureNode`, the original failure's type is preserved where available (e.g. an
    ///   `OidcError.authorizeError` wrapping a `BrowserError` is returned unmodified) rather than
    ///   being collapsed into a string-only `OidcError.unknown`.
    func authorize(configure: @Sendable (inout OidcOptions) -> Void = { _ in }) async throws -> Result<User, OidcError> {
        var options = OidcOptions()
        configure(&options)
        let result = try await startOidcLogin(options: options)
        return OidcWebClient.authorizeResult(from: result)
    }
    
    /// Starts the OIDC login process.
    /// - Parameter options: The OIDC options containing additional parameters.
    /// - Returns: A Node representing the result of the login process.
    internal func startOidcLogin(options: OidcOptions) async throws -> Node {
        let request = config.httpClient.request()
        try await initialize()
        config.logger.i("Starting...")
        let currentRequest = request
        self.sharedContext.set(key: SharedContext.Keys.oidcParameters, value: options.additionalParameters)
        
        return await self.start(currentRequest)
    }

    /// Maps the `Node` produced by the workflow into a `Result<User, OidcError>`.
    ///
    /// Extracted from `authorize(configure:)` so the mapping can be unit-tested directly without
    /// driving a full `Workflow`. When `node` is a `FailureNode`, the original failure's type is
    /// preserved where available: if `failureNode.cause` is already an `OidcError` (as is the
    /// common case for browser-cancellation/unsupported-OS failures surfaced by `WebModule`'s
    /// `transport` closure), it is returned unmodified so callers can pattern-match on it (e.g.
    /// `BrowserError.externalUserAgentCancelled`). Otherwise, the fallback wraps the original
    /// `cause` in `OidcError.unknown` rather than discarding it into a string-only message.
    /// - Parameter node: The `Node` returned by the workflow.
    /// - Returns: A `Result` containing the `User` on success, or an `OidcError` on failure.
    internal static func authorizeResult(from node: Node) -> Result<User, OidcError> {
        switch node {
        case let failureNode as FailureNode:
            if let oidcError = failureNode.cause as? OidcError {
                return Result<User, OidcError>.failure(oidcError)
            }
            return Result<User, OidcError>.failure(OidcError.unknown(cause: failureNode.cause, message: nil))
        case let successNode as SuccessNode:
            guard let user = successNode.session as? User else {
                // This should never happen, but just in case
                return Result<User, OidcError>.failure(OidcError.unknown(message: "Unexpected result: Failed to get User"))
            }
            return Result<User, OidcError>.success(user)
        default:
            return Result<User, OidcError>.failure(OidcError.unknown(message: "Unexpected result"))
        }
    }

    /// Method to return the OIDC user.
    /// This method checks if the OIDC client is initialized and sets up the necessary configurations.
    /// - Returns: The user if found, otherwise nil.
    func user() async -> User? {
        try? await initialize()
        
        if let cachedUser = self.sharedContext.get(key: SharedContext.Keys.userKey) as? User {
            return cachedUser
        }
        
        if let oidcClientConfig = self.sharedContext.get(key: SharedContext.Keys.oidcClientConfigKey) as? OidcClientConfig {
            return await prepareUser(oidcLogin: self, user: OidcUser(config: oidcClientConfig))
        }
        
        return nil
    }
    
    /// Alias for the Browser.user() method.
    /// - Returns: The user if found, otherwise nil.
    func oidcLoginUser() async -> User? {
        return await user()
    }

    /// Method to prepare the user.
    /// This Method creates a new UserDelegate instance and caches it in the context.
    /// - Parameters:
    ///   - oidcLogin: The OidcLogin instance.
    ///   - user: The user.
    ///   - session: The session.
    /// - Returns: The prepared user.
    internal func prepareUser(
        oidcLogin: OidcWebClient,
        user: User,
        session: Session = EmptySession()
    ) async -> UserDelegate {
        let userDelegate = UserDelegate(oidcLogin: oidcLogin, user: user, session: session)
        // Cache the user in the context
        self.sharedContext.set(key: SharedContext.Keys.userKey, value: userDelegate)
        return userDelegate
    }
}

/// UserDelegate is a struct that conforms to User and Session protocols.
/// It is used to manage user sessions and provide methods for user-related operations.
/// - Parameters:
///   - oidcLogin: The OidcWebClient instance.
///   - user: The User instance.
///   - session: The Session instance
struct UserDelegate: User, Session, Sendable {
    private let oidcLogin: OidcWebClient
    private let user: User
    private let session: Session
    
    /// Initializes a new UserDelegate instance.
    /// - Parameters:
    ///  - oidcLogin: The OidcWebClient instance.
    ///  - user: The User instance.
    ///  - session: The Session instance.
    init(oidcLogin: OidcWebClient, user: User, session: Session) {
        self.oidcLogin = oidcLogin
        self.user = user
        self.session = session
    }
    
    /// Method to log out the user.
    /// This method removes the cached user from the context and signs off the user.
    func logout() async {
        // remove the cached user from the context
        _ = oidcLogin.sharedContext.removeValue(forKey: SharedContext.Keys.userKey)
        // instead of calling `OidcClient.endSession` directly, we call `DaVinci.signOff` to sign off the user
        _ = await oidcLogin.signOff()
    }
    
    /// Method to get the user Token
    /// - Returns: A Result containing the Token or an OidcError.
    func token() async -> Result<Token, OidcError> {
        return await user.token()
    }
    
    /// Method to refresh the user token.
    /// - Returns: A Result containing the refreshed Token or an OidcError.
    func refresh() async -> Result<Token, OidcError> {
        await user.refresh()
    }
    
    /// Method to revoke the user token.
    func revoke() async {
        await user.revoke()
    }
    
    /// Method to get the user info.
    /// - Parameter cache: A Boolean indicating whether to use cached user info.
    /// - Returns: A Result containing the UserInfo or an OidcError.
    func userinfo(cache: Bool) async -> Result<UserInfo, OidcError> {
        await user.userinfo(cache: cache)
    }
    
    /// Method to get the session value.
    /// - Returns: The session value as a String.
    var value: String {
        get {
            return session.value
        }
    }
}
