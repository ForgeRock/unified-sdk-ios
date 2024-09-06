//
//  CustomHeader.swift
//  PingOrchestrate
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

//// Configuration class for CustomHeader.
/// Allows adding custom headers to be injected into requests.
public class CustomHeaderConfig {
    internal var headers = [(String, String)]()
    
    /// Adds a custom header to the configuration.
    /// - Parameters:
    ///   - name: The name of the header.
    ///   - value: The value of the header.
    public func header(name: String, value: String) {
        headers.append((name, value))
    }
}

/// Module for injecting custom headers into requests.
public class CustomHeader {
    
    public init() {}
    
    public static let config: Module<CustomHeaderConfig> = Module.of({ CustomHeaderConfig() }) { setup in
        setup.start { flowContext, request in
            setup.config.headers.forEach { name, value in
                request.header(name: name, value: value)
            }
            return request
        }
        
        setup.next { flowContext, _, request in
            setup.config.headers.forEach { name, value in
                request.header(name: name, value: value)
            }
            return request
        }
    }
}
