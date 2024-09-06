//
//  AuthCode.swift
//  PingOidc
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

public struct AuthCode: Codable {
    let code: String
    let codeVerifier: String?

    public init(code: String = "", codeVerifier: String? = nil) {
        self.code = code
        self.codeVerifier = codeVerifier
    }
}
