//
//  Recognize.swift
//  PingRecognize
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Custom error type for Recognize SDK exceptions
public struct RecognizeError: Error, LocalizedError, Sendable {
    public let message: String
    public let code: Int

    /// Diagnostic information forwarded from the underlying `KeylessSDKError`, if any
    /// (e.g. `flowId`, `sessionId`, `underlyingError`, `stacktrace`).
    public let debuggingInfo: [String: String]

    /// A localized description of the error.
    public var errorDescription: String? {
        return message
    }

    public init(_ message: String, code: Int, debuggingInfo: [String: String] = [:]) {
        self.message = message
        self.code = code
        self.debuggingInfo = debuggingInfo
    }
}
