//
//  OidcError.swift
//  PingOidc
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// enum fopr class for OIDC errors.
public enum OidcError: LocalizedError {
    case authorizeError(cause: Error? = nil, message: String? = nil)
    case networkError(cause: Error? = nil, message: String? = nil)
    case apiError(code: Int, message: String)
    case unknown(cause: Error? = nil, message: String? = nil)
    
    var errorMessage: String {
        switch self {
        case .authorizeError(cause: let cause, message: let message):
            return "Authorization error: \(message ?? cause?.localizedDescription ?? "Unknown")"
        case .networkError(cause: let cause, message: let message):
            return "Network error: \(message ?? cause?.localizedDescription ?? "Unknown")"
        case .apiError(code: let code, message: let message):
            return "API error: \(code) \(message)"
        case .unknown(cause: let cause, message: let message):
            return "Error: \(message ?? cause?.localizedDescription ?? "Unknown")"
        }
    }
}
