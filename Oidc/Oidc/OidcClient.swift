//
//  OidcClient.swift
//  PingOidc
//
//  Copyright (c) 2024 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingLogger
import PingNetwork
import PingOrchestrate
import PingStorage

/// Class representing an OpenID Connect client.
/// - Property pkce: PKCE  object used for the Authorization call.
public class OidcClient {
    public var pkce: Pkce?
    private let config: OidcClientConfig
    private let logger: Logger
    
    /// OidcClient initializer.
    /// - Parameter config: The configuration for this client.
    public init(config: OidcClientConfig) {
        self.config = config
        self.logger = config.logger
    }
    
    /// Generates an OIDC authorization URL synchronously.
    ///
    /// - Warning: This synchronous variant does **not** support Pushed
    ///   Authorization Requests (PAR, RFC 9126). Even when
    ///   `OidcClientConfig.par` is set to `true`, this method will fall back
    ///   to the standard authorization flow and emit all parameters in the
    ///   URL query string. To use PAR, call the `async` overload
    ///   `generateAuthorizeUrl(customParams:) async throws -> URL` instead.
    ///
    /// - Parameter customParams: Custom parameters to include in the authorization request.
    /// - Returns: The fully-built authorization URL.
    /// - Throws: `OidcError.networkError` if the HTTP client or URL cannot be resolved.
    public func generateAuthorizeUrl(customParams: [String: String]? = nil) throws -> URL {
        guard let httpClient = config.httpClient else {
            throw OidcError.networkError(message: "HTTP client not found")
        }
        var request = httpClient.request()
        let generatedPkce = Pkce.generate()
        self.pkce = generatedPkce
        request = config.populateStandardAuthorizeRequest(request: request, pkce: generatedPkce, responseMode: OidcClient.Constants.query)
        if let customParams = customParams {
            for parameter in customParams {
                request.setParameter(name: parameter.key, value: parameter.value)
            }
        }
        guard let urlString = request.url, let url = URL(string: urlString), let redirectURI = URL(string: config.redirectUri), let _ = redirectURI.scheme else {
            throw OidcError.networkError(message: "URL not found")
        }
        
        return url
    }
    
    /// OidcClient generateAuthorizeUrl with PAR support.
    /// When PAR is enabled in the configuration, authorization parameters are pushed to the server before generating the URL.
    ///
    /// - Important: this calls `OidcClientConfig.oidcInitialize()` internally (as every other
    ///   `OidcClient` method does) so `config.openId` is guaranteed populated before PAR eligibility
    ///   is checked. Without this, a config with `par == true` but no prior discovery would silently
    ///   fall back to the standard flow — emitting every `additionalParameters` value onto the
    ///   returned URL's query string instead of the PAR POST body.
    /// - Parameter customParams: Custom parameters to include in the authorization request. These are
    ///   applied to the URL *after* PAR population, so they always end up on the front-channel query
    ///   string — never in the PAR body. Use `OidcClientConfig.additionalParameters` instead for any
    ///   value that must be kept off the URL when PAR is enabled.
    public func generateAuthorizeUrl(customParams: [String: String]? = nil) async throws -> URL {
        try await config.oidcInitialize()
        guard let httpClient = config.httpClient else {
            throw OidcError.networkError(message: "HTTP client not found")
        }
        var request = httpClient.request()
        let generatedPkce = Pkce.generate()
        self.pkce = generatedPkce
        request = try await config.populateRequest(request: request, pkce: generatedPkce, responseMode: OidcClient.Constants.query)
        if let customParams = customParams {
            for parameter in customParams {
                request.setParameter(name: parameter.key, value: parameter.value)
            }
        }
        guard let urlString = request.url, let url = URL(string: urlString), let redirectURI = URL(string: config.redirectUri), let _ = redirectURI.scheme else {
            throw OidcError.networkError(message: "URL not found")
        }
        
        return url
    }
    
    /// Extracts the code from the URL and exchanges it for an access token.
    ///  - Parameter url: The URL to extract the code from.
    public func extractCodeAndGetToken(from url: URL) async throws -> Token {
        if let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true), let code = components.queryItems?.filter({$0.name == Constants.code}).first?.value, let pcke = self.pkce {
            let authCode = AuthCode(code: code, codeVerifier: pcke.codeVerifier)
            return try await self.exchangeToken(authCode)
        } else {
            throw OidcError.authorizeError(message: "Authorization code not found")
        }
    }
    
    /// Extract the Redirect URI scheme from the configuration
    public func redirectURIScheme() -> String? {
        if let redirectURI = URL(string: config.redirectUri), let callbackURLScheme = redirectURI.scheme {
            return callbackURLScheme
        }
        return nil
    }
    
    /// Retrieves an access token. If a cached token is available and not expired, it is returned.
    /// Otherwise, a new token is fetched with refresh token if refresh grant is available.
    /// - Returns: A Result containing the access token or an error.
    public func token() async -> Result<Token, OidcError> {
        
        do {
            try await config.oidcInitialize()
        } catch {
            return .failure((error as? OidcError) ?? OidcError.unknown(cause: error))
        }
        
        config.logger.i("Getting access token")
        do {
            do {
                if let cached = try await config.storage.get() {
                    if !cached.isExpired(threshold: config.refreshThreshold) {
                        config.logger.i("Token is not expired. Returning cached token.")
                        return .success(cached)
                    }
                    config.logger.i("Token is expired. Attempting to refresh.")
                    if let cachedefreshToken = cached.refreshToken {
                        do {
                            let refreshedToken = try await refreshToken(cachedefreshToken)
                            return .success(refreshedToken)
                        } catch {
                            config.logger.e("Failed to refresh token. Revoking token and re-authenticating.", error: error)
                            await revoke(cached)
                        }
                    }
                }
            } catch let error where error is EncryptorError || error is DecodingError {
                // The cached bytes are unreadable — either the Secure Enclave key did not
                // migrate with an iCloud/Quick Start device transfer (EncryptorError), or the
                // stored payload is corrupt / from an incompatible version (DecodingError).
                // Clear the unreadable token and fall through to re-authenticate. Other errors
                // (e.g. errSecInteractionNotAllowed while the device is locked) are transient
                // and must NOT delete a potentially valid token — they propagate to the outer
                // catch unchanged.
                config.logger.w("Cached token is unreadable (device migration or corrupt payload). Clearing corrupted token and re-authenticating.", error: error)
                do {
                    try await config.storage.delete()
                } catch {
                    // If we cannot clear the corrupted token, re-authenticating would persist a
                    // new token over (or alongside) the unreadable one and the next token() call
                    // would loop on the same failure. Surface a real error instead of looping.
                    config.logger.e("Failed to clear unreadable token. Aborting to avoid a silent retry loop.", error: error)
                    return .failure(OidcError.authorizeError(cause: error))
                }
                // fall through to re-authenticate below
            }

            // Authenticate the user
            guard let agent = config.agent else {
                return .failure(OidcError.authorizeError(message: "Agent not configured"))
            }
            
            let code = try await agent.authenticate()
            let token = try await exchangeToken(code)  
            try await config.storage.save(item: token)
            return .success(token)
        } catch {
            return .failure((error as? OidcError) ?? (OidcError.authorizeError(cause: error)))
        }
    }
    
    /// Refreshes the access token.
    /// - Parameter refreshToken: The refresh token to use for refreshing the access token.
    /// - Returns: The refreshed access token.
    public func refreshToken(_ refreshToken: String) async throws -> Token {
        try await config.oidcInitialize()
        config.logger.i("Refreshing token")
        
        let params = [
            Constants.grant_type: Constants.refresh_token,
            Constants.refresh_token: refreshToken,
            Constants.client_id: config.clientId
        ]
        
        guard let httpClient = config.httpClient else {
            throw OidcError.networkError(message: "HTTP client not found")
        }
        
        guard let openId = config.openId else {
            throw OidcError.unknown(message: "OpenID configuration not found")
        }
        
        let response = try await httpClient.request { request in
            request.url = openId.tokenEndpoint
            request.form(parameters: params)
        }
        guard response.status.isSuccess() else {
            throw OidcError.apiError(code: response.status, message: response.bodyAsString())
        }
        let token = try JSONDecoder().decode(Token.self, from: response.body ?? Data())
        try await config.storage.save(item: token)
        
        return token
    }
    
    /// Revokes the access token.
    public func revoke() async {
        await revoke(nil)
    }
    
    /// Revokes a specific access token. Best effort to revoke the token.
    /// The stored token is removed regardless of the result.
    /// - Parameter token: The access token to revoke. If null, the currently stored token is revoked.
    private func revoke(_ token: Token? = nil) async {
        var accessToken = token
        if accessToken == nil {
            do {
                accessToken = try await config.storage.get()
            } catch where error is EncryptorError || error is DecodingError {
                // The stored token is permanently unreadable (Secure Enclave key did not migrate,
                // or the payload is corrupt). There is nothing to revoke on the server, so just
                // clear the dead entry.
                config.logger.w("Stored token is unreadable. Clearing corrupted token.", error: error)
                try? await config.storage.delete()
                return
            } catch {
                // Transient failure (e.g. errSecInteractionNotAllowed while the device is locked).
                // The token may well be valid — do NOT delete it. Skip this revoke attempt.
                config.logger.w("Failed to read token for revocation. Leaving stored token intact.", error: error)
                return
            }
        }
        if let token = accessToken {
            do {
                try await config.storage.delete()
                try await config.oidcInitialize()
            } catch {
                config.logger.e("Failed to delete token", error: error)
            }
            let t = token.refreshToken ?? token.accessToken
            let params = [
                Constants.client_id: config.clientId,
                Constants.token: t
            ]
            
            guard let httpClient = config.httpClient else {
                config.logger.e("HTTP client not found", error: nil)
                return
            }
            
            guard let openId = config.openId else {
                config.logger.e("OpenID configuration not found", error: nil)
                return
            }
            
            do {
                _ = try await httpClient.request{ request in
                    request.url = openId.revocationEndpoint
                    request.form(parameters: params)
                }
                
            } catch {
                config.logger.e("Failed to revoke token", error: error)
            }
        }
    }
    
    /// Ends the session. Best effort to end the session.
    /// The stored token is removed regardless of the result.
    /// - Returns:  A boolean indicating whether the session was ended successfully.
    @discardableResult
    public func endSession() async -> Bool {
        return await endSession { idToken in
            return try await self.config.agent?.endSession(idToken: idToken) ?? false
        }
    }
    
    /// Ends the session with a custom sign-off procedure.
    /// - Parameter signOff: A suspend function to perform the sign-off.
    /// - Returns: A boolean indicating whether the session was ended successfully.
    @discardableResult
    public func endSession(signOff: @escaping (String) async throws -> Bool) async -> Bool {
        do {
            try await config.oidcInitialize()
            if let accessToken = try await config.storage.get() {
                await revoke(accessToken)
                if let idToken = accessToken.idToken {
                    return try await signOff(idToken)
                }
            }
        } catch {
            config.logger.e("Failed to end session", error: error)
            return false
        }
        return true
    }
    
    /// Retrieves user information.
    /// - Returns: A Result containing the user information or an error.
    public func userinfo() async -> Result<UserInfo, OidcError> {
        do {
            try await config.oidcInitialize()
            
            guard let httpClient = config.httpClient else {
                throw OidcError.networkError(message: "HTTP client not found")
            }
            
            guard let openId = config.openId else {
                throw OidcError.unknown(message: "OpenID configuration not found")
            }
            
            switch await token() {
            case .failure(let error):
                return .failure(error)
            case .success(let token):
                let response = try await httpClient.request { request in
                    request.url = openId.userinfoEndpoint
                    request.setHeader(name: NetworkConstants.headerAuthorization, value: "Bearer \(token.accessToken)")
                }
                guard response.status.isSuccess() else {
                    throw OidcError.apiError(code: response.status, message: response.bodyAsString())
                }
                let json = try JSONSerialization.jsonObject(with: response.body ?? Data(), options: []) as? UserInfo ?? [:]
                return .success(json)
            }
        } catch {
            return .failure((error as? OidcError) ?? .unknown(cause: error))
        }
    }
    
    /// Exchanges an authorization code for an access token.
    /// - Parameter authCode: The authorization code to exchange.
    /// - Returns: The access token.
    private func exchangeToken(_ authCode: AuthCode) async throws -> Token {
        try await config.oidcInitialize()
        config.logger.i("Exchanging token")
        
        guard let httpClient = config.httpClient else {
            throw OidcError.networkError(message: "HTTP client not found")
        }
        
        guard let openId = config.openId else {
            throw OidcError.unknown(message: "OpenID configuration not found")
        }
        
        var params = [
            Constants.grant_type: Constants.authorization_code,
            Constants.code: authCode.code,
            Constants.redirect_uri: config.redirectUri,
            Constants.client_id: config.clientId,
        ]
        
        if let codeVerifier = authCode.codeVerifier {
            params[Constants.code_verifier] = codeVerifier
        }
        
        let immutableParams = params
        let response = try await httpClient.request { request in
            request.url = openId.tokenEndpoint
            request.form(parameters: immutableParams)
        }
        guard response.status.isSuccess() else {
            throw OidcError.apiError(code: response.status, message: response.bodyAsString())
        }
        let token = try JSONDecoder().decode(Token.self, from: response.body ?? Data())
        return token
    }
    
    /// Represents various constants used in OIDC requests
    public enum Constants {
        public static let client_id = "client_id"
        public static let grant_type = "grant_type"
        public static let refresh_token = "refresh_token"
        public static let token = "token"
        public static let authorization_code = "authorization_code"
        public static let redirect_uri = "redirect_uri"
        public static let code_verifier = "code_verifier"
        public static let code = "code"
        public static let id_token_hint = "id_token_hint"
        public static let request_uri = "request_uri"
    }
}

extension OidcClientConfig {
    /// Builds OIDC authorization request parameters using the provided configuration.
    /// This function populates all required and optional OAuth2/OIDC parameters for an authorization request.
    /// - Parameters:
    ///   - pkce: PKCE parameters for enhanced security.
    ///   - extraParameters: Additional parameters specific to this authorization request.
    ///   - onParam: Callback function to handle each parameter (name, value) pair.
    public func buildAuthorizeParams(
        pkce: Pkce,
        extraParameters: [String: String] = [:],
        onParam: (String, String) -> Void
    ) {
        onParam(OidcClient.Constants.client_id, clientId)
        onParam(OidcClient.Constants.response_type, OidcClient.Constants.code)
        onParam(OidcClient.Constants.scope, scopes.joined(separator: " "))
        onParam(OidcClient.Constants.redirect_uri, redirectUri)
        onParam(OidcClient.Constants.code_challenge, pkce.codeChallenge)
        onParam(OidcClient.Constants.code_challenge_method, pkce.codeChallengeMethod)
        
        if let acr = acrValues {
            onParam(OidcClient.Constants.acr_values, acr)
        }
        
        if let display = display {
            onParam(OidcClient.Constants.display, display)
        }
        
        for (key, value) in additionalParameters {
            onParam(key, value)
        }
        
        if let loginHint = loginHint {
            onParam(OidcClient.Constants.login_hint, loginHint)
        }
        
        // Always emit `state`. Prefer the integrator-supplied value on
        // `OidcClientConfig.state`; otherwise fall back to the PKCE-generated
        // state so the parameter is present for CSRF protection on
        // redirect-based flows and remains available to server-side policies.
        onParam(OidcClient.Constants.state, self.state ?? pkce.state)
        
        if let nonce = nonce {
            onParam(OidcClient.Constants.nonce, nonce)
        }
        
        if let prompt = prompt {
            onParam(OidcClient.Constants.prompt, prompt)
        }
        
        if let uiLocales = uiLocales {
            onParam(OidcClient.Constants.ui_locales, uiLocales)
        }
        
        for (key, value) in extraParameters {
            onParam(key, value)
        }
    }
    
    /// Builds a standard (non-PAR) OIDC authorization request by emitting all
    /// parameters onto the request URL's query string. Shared by the sync
    /// `OidcClient.generateAuthorizeUrl` and by the async `populateRequest`
    /// fallback path when PAR is not enabled or unavailable.
    internal func populateStandardAuthorizeRequest(
        request: Request,
        pkce: Pkce,
        responseMode: String
    ) -> Request {
        request.url = openId?.authorizationEndpoint ?? ""
        if !responseMode.isEmpty {
            request.setParameter(name: OidcClient.Constants.response_mode, value: responseMode)
        }
        buildAuthorizeParams(pkce: pkce) { key, value in
            request.setParameter(name: key, value: value)
        }
        return request
    }
    
    /// Populates an OIDC authorization request handling both standard and PAR (RFC 9126) flows.
    ///
    /// **Standard Flow:** Builds authorization URL with all parameters in the query string.
    /// **PAR Flow:** POSTs parameters to the PAR endpoint, then uses the returned `request_uri` in the authorization request.
    ///
    /// - Parameters:
    ///   - request: The request to populate.
    ///   - pkce: PKCE parameters for enhanced security.
    ///   - responseMode: The response mode to use.
    /// - Returns: The populated request ready for execution.
    public func populateRequest(
        request: Request,
        pkce: Pkce,
        responseMode: String = OidcClient.Constants.piflow
    ) async throws -> Request {
        if par, let parEndpoint = openId?.pushedAuthorizationRequestEndpoint {
            // PAR flow: POST all params to PAR endpoint
            var formParams: [String: String] = [:]
            if !responseMode.isEmpty {
                formParams[OidcClient.Constants.response_mode] = responseMode
            }
            buildAuthorizeParams(pkce: pkce) { key, value in
                formParams[key] = value
            }
            
            guard let httpClient else {
                throw OidcError.networkError(message: "HTTP client not found")
            }
            
            let immutableParams = formParams
            let response = try await httpClient.request { req in
                req.url = parEndpoint
                req.form(parameters: immutableParams)
            }
            guard response.status.isSuccess() else {
                throw OidcError.apiError(code: response.status, message: "Failed to create PAR request: \(response.bodyAsString())")
            }
            
            guard let responseBody = response.body else {
                throw OidcError.authorizeError(message: "PAR response body is empty")
            }
            let json = try JSONSerialization.jsonObject(with: responseBody) as? [String: Any] ?? [:]
            guard let requestUri = json[OidcClient.Constants.request_uri] as? String else {
                throw OidcError.authorizeError(message: "PAR response missing required 'request_uri' field")
            }
            
            // Build authorize URL with only request_uri and client_id
            request.url = openId?.authorizationEndpoint ?? ""
            if !responseMode.isEmpty {
                request.setParameter(name: OidcClient.Constants.response_mode, value: responseMode)
            }
            request.setParameter(name: OidcClient.Constants.request_uri, value: requestUri)
            request.setParameter(name: OidcClient.Constants.client_id, value: clientId)
        } else {
            // Standard flow: all params on the authorization URL
            _ = populateStandardAuthorizeRequest(request: request, pkce: pkce, responseMode: responseMode)
        }
        return request
    }
}


public extension OidcClient.Constants {
    static let response_mode = "response_mode"
    static let response_type = "response_type"
    static let scope = "scope"
    static let code_challenge = "code_challenge"
    static let code_challenge_method = "code_challenge_method"
    static let acr_values = "acr_values"
    static let display = "display"
    static let nonce = "nonce"
    static let prompt = "prompt"
    static let ui_locales = "ui_locales"
    static let login_hint = "login_hint"
    static let state = "state"
    static let piflow = "pi.flow"
    static let query = "query"
    static let userCodeSnake = "user_code"
    static let userCodeCamel = "userCode"
    static let asDeviceAuthorizationPath = "/as/device_authorization"
}
