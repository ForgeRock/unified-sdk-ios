//
//  Agent.swift
//  PingDavinci
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingOidc
import PingOrchestrate

internal class CreateAgent: Agent {
    typealias T = Void
    
    let session: Session
    let pkce: Pkce?
    var used = false
    
    init(session: Session, pkce: Pkce?) {
        self.session = session
        self.pkce = pkce
    }
    
    func config() -> () -> T {
        return {}
    }
    
    func endSession(oidcConfig: OidcConfig<T>, idToken: String) async throws -> Bool {
        // Since we don't have the Session token, let DaVinci handle the sign-off
        return true
    }
    
    func authorize(oidcConfig: OidcConfig<T>) async throws -> AuthCode {
        // We don't get the state; The state may not be returned since this is primarily for
        // CSRF in redirect-based interactions, and pi.flow doesn't use redirect.
        guard !session.value().isEmpty else {
            throw OidcError.authorizeError(message: "Please start DaVinci flow to authenticate.")
        }
        guard !used else {
            throw OidcError.authorizeError(message: "Auth code already used, please start DaVinci flow again.")
        }
        
        used = true
        return session.authCode(pkce: pkce)
    }
    
}

extension Session {
    func authCode(pkce: Pkce?) -> AuthCode {
        // parse the response and return the auth code
        return AuthCode(code: value(), codeVerifier: pkce?.codeVerifier)
    }
}
