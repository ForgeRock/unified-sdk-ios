//
//  OidcDeviceClient.swift
//  PingOidc
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingBrowser
import PingLogger

/// A client that implements the RFC 8628 Device Authorization Grant (requesting-device side).
///
/// Use `OidcDeviceClient` when the device cannot open a browser directly
/// (e.g., a smart TV or CLI tool). Call `deviceAuthorization()` to start the
/// flow and receive a stream of `DeviceFlowStatus` updates. The stream yields
/// `.started` with the `userCode` and `verificationUri` to display, then
/// `.polling` on each poll, and finally `.success`, `.accessDenied`, or
/// `.expired` when the flow resolves.
///
/// - Important: `OidcClientConfig` is marked `@unchecked Sendable` and contains mutable
///   `var` fields. Do not mutate the config after passing it to this initializer — the
///   polling loop captures the config and reads it from a background thread.
public class OidcDeviceClient: @unchecked Sendable {

    enum Constants {
        static let deviceCode = "device_code"
        static let deviceCodeGrantType = "urn:ietf:params:oauth:grant-type:device_code"
        static let error = "error"
        static let authorizationPending = "authorization_pending"
        static let slowDown = "slow_down"
        static let accessDenied = "access_denied"
        static let expiredToken = "expired_token"
    }

    private let config: OidcClientConfig
    let logger: Logger

    /// Initializes a new `OidcDeviceClient`.
    /// - Parameter config: The OIDC client configuration to use.
    public init(config: OidcClientConfig) {
        self.config = config
        self.logger = config.logger
    }

    /// Creates an `OidcDeviceClient` using the provided configuration block.
    /// - Parameter block: A closure to configure the `OidcClientConfig`.
    /// - Returns: A fully configured `OidcDeviceClient`.
    public static func createOidcDeviceClient(block: (OidcClientConfig) -> Void) -> OidcDeviceClient {
        let config = OidcClientConfig()
        block(config)
        return OidcDeviceClient(config: config)
    }

    /// Creates an `OidcDeviceClient` from a unified JSON configuration dictionary.
    ///
    /// Parses and validates the platform-neutral schema and delegates to
    /// `createOidcDeviceClient(block:)` with the extracted values. Unknown fields are
    /// silently ignored for forward compatibility.
    ///
    /// Endpoint overrides (e.g. `deviceAuthorizationEndpoint`) are expressed as an
    /// `openId` sub-object inside `oidc`, mirroring the `openIdOverride` closure on
    /// `OidcClientConfig`. `discoveryEndpoint` is required unless an `openId` sub-object is
    /// supplied. When `openId` is supplied without `discoveryEndpoint` it replaces the discovery
    /// document (no network call) and `tokenEndpoint` becomes required. When both are supplied,
    /// discovery runs and `openId` patches the discovered document.
    ///
    /// - Parameter json: A `[String: Any]` dictionary conforming to the unified SDK
    ///   configuration schema.
    /// - Returns: `.success(OidcDeviceClient)` on valid input, `.failure(JsonConfigError)`
    ///   if a required field is absent or a field has the wrong type.
    public static func createOidcDeviceClient(json: [String: Any]) -> Result<OidcDeviceClient, Error> {
        do {
            let p = JsonConfigParser(json)
            let logger = p.logLevel()
            let oidcDict: [String: Any] = try p.required(JsonConfigKey.oidc, field: JsonConfigKey.oidc)

            let oidcConfig = try OidcClientConfig.from(oidcJson: oidcDict, logger: logger)

            return .success(OidcDeviceClient(config: oidcConfig))
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Device Authorization

    /// Starts the RFC 8628 device authorization flow.
    ///
    /// 1. Calls `config.oidcInitialize()` to set up the HTTP client and discover endpoints.
    /// 2. POSTs to the `device_authorization_endpoint` to obtain a `DeviceAuthorizationResponse`.
    /// 3. Returns an `AsyncThrowingStream` that yields `.started`, then polls the token
    ///    endpoint and yields `.polling` / `.success` / `.accessDenied` / `.expired`.
    ///
    /// - Returns: An `AsyncThrowingStream<DeviceFlowStatus, Error>`.
    /// - Throws: `OidcError.unknown` if the discovered configuration does not include a
    ///   device authorization endpoint; `OidcError.apiError` if the initial POST fails.
    public func deviceAuthorization() async throws -> AsyncThrowingStream<DeviceFlowStatus, Error> {
        try await config.oidcInitialize()

        guard let deviceAuthorizationEndpoint = config.openId?.deviceAuthorizationEndpoint else {
            throw OidcError.unknown(message: "Device authorization endpoint not found in OpenID configuration")
        }

        guard let httpClient = config.httpClient else {
            throw OidcError.networkError(message: "HTTP client not found")
        }

        guard let openId = config.openId else {
            throw OidcError.unknown(message: "OpenID configuration not found")
        }

        let scopeString = config.scopes.joined(separator: " ")
        let clientId = config.clientId

        let response = try await httpClient.request { request in
            request.url = deviceAuthorizationEndpoint
            request.form(parameters: [
                OidcClient.Constants.client_id: clientId,
                OidcClient.Constants.scope: scopeString
            ])
        }

        guard response.status.isSuccess() else {
            throw OidcError.apiError(code: response.status, message: response.bodyAsString())
        }

        let deviceAuthResponse = try JSONDecoder().decode(
            DeviceAuthorizationResponse.self,
            from: response.body ?? Data()
        )

        // Capture everything needed inside the stream closure — device_code never touches logger
        let deviceCode = deviceAuthResponse.deviceCode
        let tokenEndpoint = openId.tokenEndpoint
        let storage = config.storage
        let capturedConfig = config
        let capturedLogger = logger

        return AsyncThrowingStream { continuation in
            // Cancellation is handled below via continuation.onTermination.
            let task = Task {
                continuation.yield(.started(deviceAuthResponse))

                let baseInterval = deviceAuthResponse.interval
                var interval = baseInterval
                var pollCount = 0
                var consecutiveTimeouts = 0

                while true {
                    do {
                        try await Task.sleep(for: .seconds(interval))
                    } catch {
                        continuation.finish(throwing: error)
                        return
                    }

                    do {
                        let tokenResponse = try await httpClient.request { request in
                            request.url = tokenEndpoint
                            request.form(parameters: [
                                OidcClient.Constants.grant_type: Constants.deviceCodeGrantType,
                                Constants.deviceCode: deviceCode,
                                OidcClient.Constants.client_id: clientId
                            ])
                        }

                        if tokenResponse.status.isSuccess() {
                            // Attempt to decode as a Token
                            if let token = try? JSONDecoder().decode(Token.self, from: tokenResponse.body ?? Data()) {
                                try? await storage.save(item: token)
                                continuation.yield(.success(OidcUser(config: capturedConfig)))
                                continuation.finish()
                                return
                            }
                        }

                        // Parse error response
                        if let body = tokenResponse.body,
                           let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                           let errorCode = json[Constants.error] as? String {

                            switch errorCode {
                            case Constants.authorizationPending:
                                // Network recovered — restore interval to the server-provided base (RFC 8628 §3.5).
                                consecutiveTimeouts = 0
                                interval = baseInterval
                                pollCount += 1
                                continuation.yield(.polling(
                                    pollCount: pollCount,
                                    pollInterval: interval,
                                    nextPollAt: Date().addingTimeInterval(Double(interval))
                                ))

                            case Constants.slowDown:
                                consecutiveTimeouts = 0
                                interval += 5
                                pollCount += 1
                                continuation.yield(.polling(
                                    pollCount: pollCount,
                                    pollInterval: interval,
                                    nextPollAt: Date().addingTimeInterval(Double(interval))
                                ))

                            case Constants.accessDenied:
                                continuation.yield(.accessDenied)
                                continuation.finish()
                                return

                            case Constants.expiredToken:
                                continuation.yield(.expired)
                                continuation.finish()
                                return

                            default:
                                continuation.finish(
                                    throwing: OidcError.apiError(
                                        code: tokenResponse.status,
                                        message: tokenResponse.bodyAsString()
                                    )
                                )
                                return
                            }
                        } else {
                            // Non-success, non-parseable error response
                            continuation.finish(
                                throwing: OidcError.apiError(
                                    code: tokenResponse.status,
                                    message: tokenResponse.bodyAsString()
                                )
                            )
                            return
                        }

                    } catch let urlError as URLError {
                        // Network/timeout error — apply exponential backoff and continue
                        consecutiveTimeouts += 1
                        let backoffMultiplier = 1 << min(consecutiveTimeouts, 3)
                        interval = min(max(baseInterval * backoffMultiplier, 5), 60)
                        pollCount += 1
                        capturedLogger.w("Device flow poll encountered a network error. Backing off to \(interval)s.", error: urlError)
                        continuation.yield(.polling(
                            pollCount: pollCount,
                            pollInterval: interval,
                            nextPollAt: Date().addingTimeInterval(Double(interval))
                        ))
                    } catch {
                        // Non-OidcError generic error — apply backoff and continue
                        if error is OidcError {
                            continuation.finish(throwing: error)
                            return
                        }
                        consecutiveTimeouts += 1
                        let backoffMultiplier = 1 << min(consecutiveTimeouts, 3)
                        interval = min(max(baseInterval * backoffMultiplier, 5), 60)
                        pollCount += 1
                        capturedLogger.w("Device flow poll encountered an error. Backing off to \(interval)s.", error: error)
                        continuation.yield(.polling(
                            pollCount: pollCount,
                            pollInterval: interval,
                            nextPollAt: Date().addingTimeInterval(Double(interval))
                        ))
                    }
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Browser Authorization

    /// Opens the `verificationUriComplete` URL in an `SFSafariViewController` so the user
    /// can approve the device flow on this device. Suspends until the browser is dismissed
    /// (either via the redirect callback or because the user closed it); the polling loop
    /// in `deviceAuthorization()` continues independently while this method is awaiting.
    ///
    /// - Parameter verificationUriComplete: The verification URI (including `user_code`)
    ///   returned in the `DeviceAuthorizationResponse`.
    /// - Throws: `OidcError.unknown` if `verificationUriComplete` is not a valid URL or
    ///   `config.redirectUri` has no scheme; `BrowserError.externalUserAgentCancelled` if
    ///   the user closed the browser before completing the flow, or any other error surfaced
    ///   by `BrowserLauncher`.
    public func authorize(verificationUriComplete: String) async throws {
        guard let url = URL(string: verificationUriComplete) else {
            throw OidcError.unknown(message: "authorize: invalid verificationUriComplete URL: \(verificationUriComplete)")
        }

        guard let callbackURLScheme = redirectURIScheme() else {
            throw OidcError.unknown(message: "authorize: no redirectUri scheme configured")
        }

        _ = try await BrowserLauncher.currentBrowser.launch(
            url: url,
            customParams: nil,
            browserType: .sfViewController,
            browserMode: .login,
            callbackURLScheme: callbackURLScheme,
            logger: logger
        )
    }

    // MARK: - Revoke

    /// Revokes the stored token by delegating to `OidcClient`.
    public func revoke() async {
        await OidcClient(config: config).revoke()
    }

    // MARK: - User

    /// Returns an `OidcUser` if a token exists in storage; otherwise returns `nil`.
    public func user() async -> (any User)? {
        if (try? await config.storage.get()) != nil {
            return OidcUser(config: config)
        }
        return nil
    }

    // MARK: - Private Helpers

    /// Extracts the URL scheme from `config.redirectUri`, matching the approach used
    /// by `OidcClient.redirectURIScheme()`.
    private func redirectURIScheme() -> String? {
        if let redirectURI = URL(string: config.redirectUri), let scheme = redirectURI.scheme {
            return scheme
        }
        return nil
    }
}
