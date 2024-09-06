//
//  OidcUser.swift
//  PingOidc
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


/// Class for an OIDC User
public class OidcUser: User {
    private var userinfo: UserInfo?
    private let oidcClient: OidcClient
    
    /// OidcUser initializer
    /// - Parameter config: The configuration for the OIDC client.
    public init(config: OidcClientConfig) {
        self.oidcClient = OidcClient(config: config)
    }
    
    /// Gets the token for the user.
    /// - Returns: The token for the user.
    public func token() async -> Result<Token, OidcError> {
        return await oidcClient.token()
    }
    
    /// Revokes the user's token.
    public func revoke() async {
        await oidcClient.revoke()
    }
    
    /// Gets the user information.
    /// - Parameter cache: Whether to cache the user information.
    /// - Returns: The user information.
    public func userinfo(cache: Bool = true) async -> Result<UserInfo, OidcError> {
        if let userinfo = self.userinfo, cache {
            return .success(userinfo)
        }
        let result = await oidcClient.userinfo()
        if case .success(let data) = result, cache {
            self.userinfo = data
        }
        return result
    }
    
    /// Logs out the user.
    public func logout() async {
        _ = await oidcClient.endSession()
    }
}
