//
//  User.swift
//  PingDavinci
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import PingOidc
import PingOrchestrate

extension DaVinci {
    /// Retrieve the user.
    /// If cookies are available, it prepares a new user and returns it.
    /// If no user is found and no cookies are available, it returns nil.
    /// - Returns: The user if found, otherwise nil.
    public func user() async -> User? {
        try? await initialize()
        
        if let cachedUser = self.sharedContext.get(key: SharedContext.Keys.userKey) as? User {
            return cachedUser
        }
        
        if await hasCookies() {
            if let oidcClientConfig = self.sharedContext.get(key: SharedContext.Keys.oidcClientConfigKey) as? OidcClientConfig {
                return await prepareUser(daVinci: self, user: OidcUser(config: oidcClientConfig))
            }
        }
        return nil
    }
    
    /// Alias for the DaVinci.user() method.
    /// - Returns: The user if found, otherwise nil.
    public func daVinciUser() async -> User? {
        return await user()
    }
    
    /// Method to prepare the user.
    /// This Method creates a new UserDelegate instance and caches it in the context.
    /// - Parameters:
    ///   - daVinci: The DaVinci instance.
    ///   - user: The user.
    ///   - session: The session.
    /// - Returns: The prepared user.
    func prepareUser(
        daVinci: DaVinci,
        user: User,
        session: Session = EmptySession()
    ) async -> UserDelegate {
        let userDelegate = UserDelegate(daVinci: daVinci, user: user, session: session)
        // Cache the user in the context
        self.sharedContext.set(key: SharedContext.Keys.userKey, value: userDelegate)
        return userDelegate
    }
}

/// Extension property for SuccessNodet o cast the `SuccessNode.session` to a User.
extension SuccessNode {
    var user: User? {
        return session as? User
    }
}

/// Struct representing a UserDelegate.
/// This struct is a delegate for the User and Session interfaces.
/// It overrides the logout function to remove the cached user from the context and sign off the user.
/// - property daVinci: The DaVinci instance.
/// - property user: The user.
/// - property session: The session.
struct UserDelegate: User, Session {
    private let daVinci: DaVinci
    private let user: User
    private let session: Session
    
    init(daVinci: DaVinci, user: User, session: Session) {
        self.daVinci = daVinci
        self.user = user
        self.session = session
    }
    
    /// Method to log out the user.
    /// This method removes the cached user from the context and signs off the user.
    func logout() async {
        // remove the cached user from the context
        _ = daVinci.sharedContext.removeValue(forKey: SharedContext.Keys.userKey)
        // instead of calling `OidcClient.endSession` directly, we call `DaVinci.signOff` to sign off the user
        _ = await daVinci.signOff()
    }
    
    func token() async -> Result<Token, OidcError> {
        return await user.token()
    }
    
    func revoke() async {
        await user.revoke()
    }
    
    func userinfo(cache: Bool) async -> Result<UserInfo, OidcError> {
        await user.userinfo(cache: cache)
    }
    
    func value() -> String {
        return session.value()
    }
}
