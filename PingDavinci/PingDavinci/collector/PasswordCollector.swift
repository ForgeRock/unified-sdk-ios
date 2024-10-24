//
//  PasswordCollector.swift
//  PingDavinci
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingOrchestrate

/// Class representing a PasswordCollector.
/// This class inherits from the FieldCollector class and implements the Closeable and Collector protocols.
/// It is used to collect password data.
public class PasswordCollector: FieldCollector, Closeable, @unchecked Sendable  {
    public var clearPassword: Bool = true
    
    /// Overrides the close function from the Closeable protocol.
    /// It is used to clear the value of the password field when the collector is closed.
    public func close() {
        if clearPassword {
            value = ""
        }
    }
}
