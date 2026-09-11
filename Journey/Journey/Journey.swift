//
//  Journey.swift
//  Journey
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingOrchestrate
import PingOidc
import PingLogger
import PingJourneyPlugin
import PingCommons
import PingNetwork

/// A typealias mapping Journey to the underlying Workflow type used by the orchestrator.
public typealias Journey = Workflow

/// Options that influence how a Journey is initiated or resumed.
///
/// - forceAuth: Forces authentication even if a valid session exists.
/// - noSession: Allows the journey to complete without creating a session.
/// - verificationUriComplete: The `verificationUriComplete` URL from an RFC 8628 device
///   authorization response. Set this when the current device is acting as the approving device.
///   `OidcModule` reads this value from the workflow's shared context and uses it to extract
///   the `user_code` and POST approval to the verification URL after a successful
///   Journey authentication.
public struct Options: Sendable {
    /// Whether to force authentication even when a valid session exists.
    public var forceAuth: Bool = false
    /// Whether to allow completion without generating a session.
    public var noSession: Bool = false
    /// The `verificationUriComplete` URL from an RFC 8628 device authorization response.
    ///
    /// When set, `OidcModule` extracts the `user_code` query parameter from this URL and
    /// POSTs it (with `decision=allow` and the SSO token as cookie) to the verification URL
    /// after the user authenticates, thereby approving the requesting device.
    public var verificationUriComplete: URL? = nil
}

/// Configuration for Journey workflows.
///
/// Conforms to `WorkflowConfig` and `Sendable`, and holds parameters required
/// to communicate with the Journey backend.
/// - Important: Provide `serverUrl` and `realm` appropriate to your deployment.
public class JourneyConfig: WorkflowConfig, @unchecked Sendable {
    /// The base URL of the server handling Journey requests, for example:
    /// https://example.am.com/am
    public var serverUrl: String?
    
    /// The realm used for authentication and callback endpoints.
    /// Defaults to the value in `JourneyConstants.realm`.
    public var realm: String = JourneyConstants.realm
    
    /// The cookie name used by the Journey backend.
    /// Defaults to `JourneyConstants.cookie`.
    public var cookie: String = JourneyConstants.cookie
}

// Define the Journey class
public extension Journey {
    /// Creates a Journey instance with sensible defaults and optional customization.
    ///
    /// This configures:
    /// - Logging and timeout
    /// - Default headers via `CustomHeader.config`
    /// - Node transformation, session management, and OIDC support modules
    /// - Callback registrations for common Journey callbacks
    ///
    /// - Parameter block: An optional configuration closure to customize `JourneyConfig` and modules.
    /// - Returns: A configured Journey.
    static func createJourney(block: @Sendable (JourneyConfig) -> Void = {_ in }) -> Journey {
        let config = JourneyConfig()
        config.logger = LogManager.logger
        config.timeout = 30
        config.module(CustomHeader.config) { customHeaderConfig in
            customHeaderConfig.header(name: NetworkConstants.headerRequestedWith, value: NetworkConstants.requestedWithValue)
            customHeaderConfig.header(name: NetworkConstants.headerRequestedPlatform, value: NetworkConstants.requestedPlatformValue)
            customHeaderConfig.header(name: NetworkConstants.headerAcceptLanguage, value: Locale.preferredLocales.toAcceptLanguage())
        }
        
        config.module(NodeTransformModule.config)
        config.module(SessionModule.config)
        config.module(OidcModule.config)
        
        Task {
            await CallbackRegistry.shared.register(type: JourneyConstants.booleanAttributeInputCallback, callback: BooleanAttributeInputCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.choiceCallback, callback: ChoiceCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.confirmationCallback, callback: ConfirmationCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.consentMappingCallback, callback: ConsentMappingCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.hiddenValueCallback, callback: HiddenValueCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.kbaCreateCallback, callback: KbaCreateCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.metadataCallback, callback: MetadataCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.nameCallback, callback: NameCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.numberAttributeInputCallback, callback: NumberAttributeInputCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.passwordCallback, callback: PasswordCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.pollingWaitCallback, callback: PollingWaitCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.stringAttributeInputCallback, callback: StringAttributeInputCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.suspendedTextOutputCallback, callback: SuspendedTextOutputCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.termsAndConditionsCallback, callback: TermsAndConditionsCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.textInputCallback, callback: TextInputCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.textOutputCallback, callback: TextOutputCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.validatedPasswordCallback, callback: ValidatedPasswordCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.validatedUsernameCallback, callback: ValidatedUsernameCallback.self)
            
            // Optional dynamic registrations for auxiliary modules
            if let c: NSObject.Type = NSClassFromString("PingProtect.ProtectCallbacks") as? NSObject.Type {
                c.perform(Selector(("registerCallbacks")))
            }
            if let c: NSObject.Type = NSClassFromString("PingExternalIdP.IdpCallbacks") as? NSObject.Type {
                c.perform(Selector(("registerCallbacks")))
            }
            if let c: NSObject.Type = NSClassFromString("PingDeviceProfile.DeviceProfile") as? NSObject.Type {
                c.perform(Selector(("registerCallbacks")))
            }
            if let c: NSObject.Type = NSClassFromString("PingFido.CallbackInitializer") as? NSObject.Type {
                c.perform(Selector(("registerCallbacks")))
            }
            if let c: NSObject.Type = NSClassFromString("PingReCaptchaEnterprise.ReCaptchaEnterprise") as? NSObject.Type {
                c.perform(Selector(("registerCallbacks")))
            }
            if let c: NSObject.Type = NSClassFromString("PingBinding.BindingModule") as? NSObject.Type {
                c.perform(Selector(("registerCallbacks")))
            }
            if let c: NSObject.Type = NSClassFromString("PingRecognize.RecognizeCallbacks") as? NSObject.Type {
                c.perform(Selector(("registerCallbacks")))
            }
        }
        // Apply custom configuration
        block(config)
        
        return Journey(config: config)
    }
    
    /// Starts a Journey by name with optional options configuration.
    ///
    /// - Parameters:
    ///   - journeyName: The name of the Journey (auth tree) to start.
    ///   - configure: Optional closure to modify `Options` before starting.
    /// - Returns: The first `Node` returned by the Journey start.
    func start(_ journeyName: String, configure: @Sendable (inout Options) -> Void = { _ in }) async -> Node {
        var options = Options()
        configure(&options)
        guard let journeyConfig = self.config as? JourneyConfig else {
            return FailureNode(cause: ApiError.error(400, [:], "JourneyConfig missing"))
        }
        
        self.sharedContext.set(key: JourneyConstants.forceAuth, value: options.forceAuth)
        self.sharedContext.set(key: JourneyConstants.noSession, value: options.noSession)
        if let uri = options.verificationUriComplete {
            self.sharedContext.set(key: SharedContext.Keys.journeyVerificationUriCompleteKey, value: uri.absoluteString)
        } else {
            _ = self.sharedContext.removeValue(forKey: SharedContext.Keys.journeyVerificationUriCompleteKey)
        }

        let request = config.httpClient.request()
        request.populateRequest(authIndexValue: journeyName, journeyConfig: journeyConfig, options: options)
        
        return await start(request)
    }
    
    /// Resumes a Journey from a suspended URI with optional options configuration.
    ///
    /// - Parameters:
    ///   - uri: The resume URI containing the suspendedId parameter.
    ///   - configure: Optional closure to modify `Options` before resuming.
    /// - Returns: The next `Node` returned by the Journey resume, or a `FailureNode` if URI is invalid.
    func resume(_ uri: URL, configure: @Sendable (inout Options) -> Void = { _ in }) async -> Node {
        var options = Options()
        configure(&options)
        guard let journeyConfig = self.config as? JourneyConfig else {
            return FailureNode(cause: ApiError.error(400, [:], "JourneyConfig missing"))
        }
        
        self.sharedContext.set(key: JourneyConstants.forceAuth, value: options.forceAuth)
        self.sharedContext.set(key: JourneyConstants.noSession, value: options.noSession)
        
        if let components = URLComponents(url: uri, resolvingAgainstBaseURL: false),
           let suspendedId = components.queryItems?.first(where: { $0.name == JourneyConstants.suspendedId })?.value {
            let request = config.httpClient.request()
            request.populateRequest(authIndexValue: "", authIndexType: "", journeyConfig: journeyConfig, options: options)
            request.setParameter(name: JourneyConstants.suspendedId, value: suspendedId)
            return await start(request)
        } else {
            return FailureNode(cause: ApiError.error(400, [:], "Invalid URI or missing suspendedId"))
        }
    }
    
    /// Starts a Journey from an AM backchannel `redirectUri`.
    ///
    /// The `redirectUri` is returned by AM's `/authenticate/backchannel/initialize`
    /// endpoint and forwarded to the app by the federation service (gateway). It encodes
    /// `authIndexType=transaction` and `authIndexValue=<uuid>` as query parameters;
    /// this method extracts those values and drives a standard Journey authenticate call.
    ///
    /// The `redirectUri` path is ignored — the authenticate endpoint is always constructed
    /// from `JourneyConfig.serverUrl` and `JourneyConfig.realm`. The `redirectUri` host is
    /// validated against `JourneyConfig.serverUrl`'s host so a URI forwarded from an
    /// unexpected origin is rejected before its query parameters are trusted.
    ///
    /// - Parameters:
    ///   - backchannelUri: The `redirectUri` received from the gateway.
    ///   - configure: Optional closure to set `Options` (e.g. `noSession`).
    /// - Returns: The first `Node` returned by the Journey, or a `FailureNode` if the
    ///   URI's host doesn't match `JourneyConfig.serverUrl`, the URI is missing required
    ///   parameters, or `JourneyConfig` is absent.
    func start(backchannelUri: URL, configure: @Sendable (inout Options) -> Void = { _ in }) async -> Node {
        var options = Options()
        configure(&options)
        guard let journeyConfig = self.config as? JourneyConfig else {
            return FailureNode(cause: ApiError.error(400, [:], "JourneyConfig missing"))
        }

        // Hostnames are case-insensitive (RFC 3986 §3.2.2), so compare both sides lowercased.
        guard let serverHost = journeyConfig.serverUrl.flatMap({ URL(string: $0)?.host }),
              backchannelUri.host?.lowercased() == serverHost.lowercased()
        else {
            return FailureNode(cause: ApiError.error(400, [:], "backchannelUri host does not match JourneyConfig.serverUrl"))
        }

        guard let components = URLComponents(url: backchannelUri, resolvingAgainstBaseURL: false),
              let authIndexType = components.queryItems?.first(where: { $0.name == JourneyConstants.authIndexType })?.value,
              !authIndexType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let authIndexValue = components.queryItems?.first(where: { $0.name == JourneyConstants.authIndexValue })?.value,
              !authIndexValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return FailureNode(cause: ApiError.error(400, [:], "Invalid URI or missing authIndexType/authIndexValue"))
        }

        self.sharedContext.set(key: JourneyConstants.forceAuth, value: options.forceAuth)
        self.sharedContext.set(key: JourneyConstants.noSession, value: options.noSession)

        let request = config.httpClient.request()
        request.populateRequest(authIndexValue: authIndexValue, authIndexType: authIndexType, journeyConfig: journeyConfig, options: options)
        return await start(request)
    }

    /// Signs off the Journey session and performs any configured cleanup.
    ///
    /// - Returns: `.success(())` on success or `.failure(Error)` if sign-off fails.
    func journeySignOff() async -> Result<Void, Error> {
        return await signOff()
    }
    
    /// Creates a Journey instance from a JSON dictionary.
    ///
    /// This factory parses and validates a platform-neutral JSON configuration and
    /// delegates to `createJourney(block:)` with the extracted values. Unknown fields
    /// are silently ignored for forward compatibility.
    ///
    /// - Parameter json: A `[String: Any]` dictionary conforming to the unified SDK
    ///   configuration schema (see design doc for field reference).
    /// - Returns: `.success(Journey)` on valid input, `.failure(JsonConfigError)` if a
    ///   required field is absent or a field has the wrong type.
    static func createJourney(json: [String: Any]) -> Result<Journey, Error> {
        do {
            let p = JsonConfigParser(json)
            let journeyDict: [String: Any] = try p.required(JsonConfigKey.journey, field: JsonConfigKey.journey)
            let jp = JsonConfigParser(journeyDict)
            let serverUrl: String = try jp.required(JsonConfigKey.serverUrl, field: "\(JsonConfigKey.journey).\(JsonConfigKey.serverUrl)")
            let realm      = try jp.optional(JsonConfigKey.realm,      field: "\(JsonConfigKey.journey).\(JsonConfigKey.realm)",      default: JourneyConstants.realm)
            let cookieName = try jp.optional(JsonConfigKey.cookieName, field: "\(JsonConfigKey.journey).\(JsonConfigKey.cookieName)", default: JourneyConstants.cookie)
            let timeout    = try p.timeoutSeconds()
            let logger     = p.logLevel()
            let oidcDict: [String: Any]? = try p.optionalValue(JsonConfigKey.oidc, field: JsonConfigKey.oidc)

            let oidcConfig: OidcClientConfig? = try oidcDict.map {
                try OidcClientConfig.from(oidcJson: $0, logger: logger)
            }

            let journey = Journey.createJourney { journeyConfig in
                journeyConfig.serverUrl = serverUrl
                journeyConfig.realm = realm
                journeyConfig.cookie = cookieName
                journeyConfig.timeout = timeout
                journeyConfig.logger = logger
                if let oidcConfig {
                    journeyConfig.module(OidcModule.config) { moduleOidcConfig in
                        moduleOidcConfig.update(with: oidcConfig)
                    }
                }
            }
            return .success(journey)
        } catch {
            return .failure(error)
        }
    }

    /// Sends a request using the configured HTTP client and wraps the response.
    ///
    /// - Parameter request: The request to send.
    /// - Returns: A `Response` containing the raw data and `HTTPURLResponse`.
    private func send(_ request: Request) async throws -> Response {
        return try await config.httpClient.request(request: request)
    }
}
