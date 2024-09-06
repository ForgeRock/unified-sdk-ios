//
//  Token.swift
//  FRAuth
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

public struct Token: Codable {
    public let accessToken: String
    public let tokenType: String?
    public let scope: String?
    public let expiresIn: Int64
    public let refreshToken: String?
    public let idToken: String?
    public let expiresAt: Int64
    
    init(accessToken: String, tokenType: String?, scope: String?, expiresIn: Int64, refreshToken: String?, idToken: String?) {
        self.accessToken = accessToken
        self.tokenType = tokenType
        self.scope = scope
        self.expiresIn = expiresIn
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.expiresAt = Int64(Date().timeIntervalSince1970) + expiresIn
    }
    
    var isExpired: Bool {
        return Int64(Date().timeIntervalSince1970) >= expiresAt
    }
    
    func isExpired(threshold: Int64) -> Bool {
        return Int64(Date().timeIntervalSince1970) >= expiresAt - threshold
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        tokenType = try container.decodeIfPresent(String.self, forKey: .tokenType)
        scope = try container.decodeIfPresent(String.self, forKey: .scope)
        expiresIn = try container.decode(Int64.self, forKey: .expiresIn)
        refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)
        idToken = try container.decodeIfPresent(String.self, forKey: .idToken)
        expiresAt = try container.decodeIfPresent(Int64.self, forKey: .expiresAt) ?? Int64(Date().timeIntervalSince1970) + expiresIn
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encode(tokenType, forKey: .tokenType)
        try container.encode(scope, forKey: .scope)
        try container.encode(expiresIn, forKey: .expiresIn)
        try container.encode(refreshToken, forKey: .refreshToken)
        try container.encode(idToken, forKey: .idToken)
        try container.encode(expiresAt, forKey: .expiresAt)
    }
}

// Define CodingKeys for the AccessToken struct
extension Token {
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case expiresAt = "expires_at"
    }
}

extension Token: CustomStringConvertible {
    public var description: String {
        "isExpired: \(isExpired)\n access_token: \(self.accessToken)\n refresh_token: \(refreshToken ?? "nil")\n id_token: \(idToken ?? "nil")\n token_type: \(tokenType ?? "nil")\n scope: \(scope ?? "nil")\n expires_in: \(String(describing: expiresIn))\n expires_at: \(String(describing: Date(timeIntervalSince1970: TimeInterval(expiresAt))))"
    }
}
