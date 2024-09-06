//
//  PKCE.swift
//  PingOidc
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import CryptoKit

/// Struct for PKCE (Proof Key for Code Exchange).
/// - property codeVerifier: The code verifier for the PKCE.
/// - property codeChallenge: The code challenge for the PKCE.
/// - property codeChallengeMethod: The code challenge method for the PKCE.
public struct Pkce {
    public let codeVerifier: String
    public let codeChallenge: String
    public let codeChallengeMethod: String
    
    /// Generates a new PKCE.
    /// - Returns: A new PKCE.
    public static func generate() -> Pkce {
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(codeVerifier: codeVerifier)
        return Pkce(codeVerifier: codeVerifier, codeChallenge: codeChallenge, codeChallengeMethod: "S256")
    }
    
    /// Generates a new code verifier for the PKCE.
    /// - returns: A new code verifier.
    private static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString() // remove padding as per https://tools.ietf.org/html/rfc7636#section-4.1
    }
    
    /// Generates a new code challenge for the PKCE.
    /// - Parameter codeVerifier: The code verifier for the PKCE.
    /// - Returns:  A new code challenge.
    private static func generateCodeChallenge(codeVerifier: String) -> String {
        guard let data = codeVerifier.data(using: .utf8) else {
            fatalError("Unable to convert code verifier to data")
        }
        let digest = SHA256.hash(data: data)
        return Data(digest).base64URLEncodedString() // remove padding as per https://tools.ietf.org/html/rfc7636#section-4.1
    }
}

extension Data {
    func base64URLEncodedString() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}
