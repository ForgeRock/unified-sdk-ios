//
//  MockAPIEndpoint.swift
//  PingDavinciTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

enum MockAPIEndpoint {
    static let baseURL = "https://auth.test-one-pingone.com"
    
    case authorization
    case token
    case userinfo
    case endSession
    case revocation
    case discovery
    case customHTMLTemplate
    
    var url: URL {
        switch self {
        case .authorization:
            return URL(string: "\(MockAPIEndpoint.baseURL)/authorize")!
        case .token:
            return URL(string: "\(MockAPIEndpoint.baseURL)/token")!
        case .userinfo:
            return URL(string: "\(MockAPIEndpoint.baseURL)/userinfo")!
        case .endSession:
            return URL(string: "\(MockAPIEndpoint.baseURL)/signoff")!
        case .revocation:
            return URL(string: "\(MockAPIEndpoint.baseURL)/revoke")!
        case .discovery:
            return URL(string: "\(MockAPIEndpoint.baseURL)/.well-known/openid-configuration")!
        case .customHTMLTemplate:
            return URL(string: "\(MockAPIEndpoint.baseURL)/customHTMLTemplate")!
        }
    }
}
