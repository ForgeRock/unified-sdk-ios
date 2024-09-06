//
//  OidcClient.swift
//  PingOidc
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingLogger
import PingOrchestrate

/// Class representing an OpenID Connect client.
public class OidcClient {
    private let config: OidcClientConfig
    private let logger: Logger
    
    /// OidcClient initializer.
    /// - Parameter config: The configuration for this client.
    public init(config: OidcClientConfig) {
        self.config = config
        self.logger = config.logger
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
        if let cached = try? await config.storage.get() {
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
        
        // Authenticate the user
        do {
            let code = try await config.agent?.authenticate()
            if let unWrappedcode = code {
                let token = try await exchangeToken(unWrappedcode)
                try await config.storage.save(item: token)
                return .success(token)
            } else {
                return .failure(OidcError.authorizeError(message: "Authorization code not found"))
            }
            
        } catch {
            return .failure((error as? OidcError) ?? (OidcError.authorizeError(cause: error)))
        }
    }
    
    /// Refreshes the access token.
    /// - Parameter refreshToken: The refresh token to use for refreshing the access token.
    /// - Returns: The refreshed access token.
    private func refreshToken(_ refreshToken: String) async throws -> Token {
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
        
        let request = Request()
        request.url(openId.tokenEndpoint)
        request.form(formData: params)
        
        let (data, response) = try await httpClient.sendRequest(request: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OidcError.apiError(code: (response as? HTTPURLResponse)?.statusCode ?? 0, message: String(decoding: data, as: UTF8.self))
        }
        let token = try JSONDecoder().decode(Token.self, from: data)
        
        try await config.storage.save(item: token)
        
        return token
    }
    
    /// Revokes the access token.
    func revoke() async {
        await revoke(nil)
    }
    
    /// Revokes a specific access token. Best effort to revoke the token.
    /// The stored token is removed regardless of the result.
    /// - Parameter token: The access token to revoke. If null, the currently stored token is revoked.
    private func revoke(_ token: Token? = nil) async {
        var accessToken = token
        if accessToken == nil {
            accessToken = try? await config.storage.get()
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
            
            let request = Request()
            request.url(openId.revocationEndpoint)
            request.form(formData: params)
            do {
                let (_, _) = try await httpClient.sendRequest(request: request)
            } catch {
                config.logger.e("Failed to revoke token", error: error)
            }
        }
    }
    
    /// Ends the session. Best effort to end the session.
    /// The stored token is removed regardless of the result.
    /// - Returns:  A boolean indicating whether the session was ended successfully.
    func endSession() async -> Bool {
        return await endSession { idToken in
            return try await self.config.agent?.endSession(idToken: idToken) ?? false
        }
    }
    
    /// Ends the session with a custom sign-off procedure.
    /// - Parameter signOff: A suspend function to perform the sign-off.
    /// - Returns: A boolean indicating whether the session was ended successfully.
    public func endSession(signOff: @escaping (String) async throws -> Bool) async -> Bool {
        do {
            try await config.oidcInitialize()
            if let accessToken =  try await config.storage.get() {
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
    func userinfo() async -> Result<UserInfo, OidcError> {
        do {
            try await config.oidcInitialize()
            
            guard let httpClient = config.httpClient else {
                throw OidcError.networkError(message: "HTTP client not found")            }
            
            guard let openId = config.openId else {
                throw OidcError.unknown(message: "OpenID configuration not found")
            }
            
            switch await token() {
            case .failure(let error):
                return .failure(error)
            case .success(let token):
                let request = Request()
                request.url(openId.userinfoEndpoint)
                request.header(name: "Authorization", value: "Bearer \(token.accessToken)")
                let (data, response) = try await httpClient.sendRequest(request: request)
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw OidcError.apiError(code: (response as? HTTPURLResponse)?.statusCode ?? 0, message: String(decoding: data, as: UTF8.self))
                }
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? UserInfo ?? [:]
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
        
        let request = Request()
        request.url(openId.tokenEndpoint)
        request.form(formData: params)
        let (data, response) = try await httpClient.sendRequest(request: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OidcError.apiError(code: (response as? HTTPURLResponse)?.statusCode ?? 0, message: String(decoding: data, as: UTF8.self))
        }
        let token = try JSONDecoder().decode(Token.self, from: data)
        return token
    }
    
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
    }
}
