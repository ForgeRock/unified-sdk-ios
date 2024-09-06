//
//  OpenIdConfiguration.swift
//  PingOidc
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

public struct OpenIdConfiguration: Codable {
    // Define properties corresponding to the serialized names
    public let authorizationEndpoint: String
    public let tokenEndpoint: String
    public let userinfoEndpoint: String
    public let endSessionEndpoint: String
    public let revocationEndpoint: String
    
    // Define CodingKeys enum to map serialized names to property names
    private enum CodingKeys: String, CodingKey {
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case userinfoEndpoint = "userinfo_endpoint"
        case endSessionEndpoint = "end_session_endpoint"
        case revocationEndpoint = "revocation_endpoint"
    }
}
