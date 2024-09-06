//
//  Request.swift
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

extension OidcClientConfig {
    internal func populateRequest(
        request: Request,
        pkce: Pkce
    ) -> Request {
        request.url(openId?.authorizationEndpoint ?? "")
        request.parameter(name: OidcClient.Constants.response_mode, value: "pi.flow")
        request.parameter(name: OidcClient.Constants.client_id, value: clientId)
        request.parameter(name: OidcClient.Constants.response_type, value: OidcClient.Constants.code)
        request.parameter(name: OidcClient.Constants.scope, value: scopes.joined(separator: " "))
        request.parameter(name: OidcClient.Constants.redirect_uri, value: redirectUri)
        request.parameter(name: OidcClient.Constants.code_challenge, value: pkce.codeChallenge)
        request.parameter(name: OidcClient.Constants.code_challenge_method, value: pkce.codeChallengeMethod)
        
        if let acr = acrValues {
            request.parameter(name: OidcClient.Constants.acr_values, value: acr)
        }
        
        if let display = display {
            request.parameter(name: OidcClient.Constants.display, value: display)
        }
        
        for (key, value) in additionalParameters {
            request.parameter(name: key, value: value)
        }
        
        if let loginHint = loginHint {
            request.parameter(name: OidcClient.Constants.login_hint, value: loginHint)
        }
        
        if let nonce = nonce {
            request.parameter(name: OidcClient.Constants.nonce, value: nonce)
        }
        
        if let prompt = prompt {
            request.parameter(name: OidcClient.Constants.prompt, value: prompt)
        }
        
        if let uiLocales = uiLocales {
            request.parameter(name: OidcClient.Constants.ui_locales, value: uiLocales)
        }
        
        return request
    }
}

extension OidcClient.Constants {
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
    static let piflow = "pi.flow"
}
