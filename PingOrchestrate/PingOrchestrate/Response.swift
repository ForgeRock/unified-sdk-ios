//
//  SampleRequest.swift
//  PingOrchestrate
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// Struct for a Response. A Response represents a response received from a network request.
/// - property data: The data  received from the network request.
/// - response The URLResponse received from the network request.
public struct Response {
    public let data: Data
    public let response: URLResponse
    
    /// Returns the body of the response.
    /// - Returns: The body of the response as a String.
    public func body() -> String {
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    /// Returns the body of the response as a JSON object.
    /// - Parameter data: The data to convert to a JSON object.
    /// - Returns: The body of the response as a JSON object.
    public func json(data: Data) throws -> [String: Any] {
        return (try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]) ?? [:]
    }
    
    ///  Returns the status code of the response.
    /// - Returns: The status code of the response as an Int.
    public func status() -> Int {
        return (response as? HTTPURLResponse)?.statusCode ?? 0
    }
    
    ///  Returns the value of a specific header from the response.
    /// - Parameter name: The name of the header.
    /// - Returns: The value of the header as a String.
    public func header(name: String) -> String? {
        return (response as? HTTPURLResponse)?.allHeaderFields[name] as? String
    }
    
    /// Returns the cookies from the response.
    /// - Returns: The cookies from the response as an array of HTTPCookie.
    public func getCookies() -> [HTTPCookie] {
        if let response = (response as? HTTPURLResponse),
           let allHeaders = response.allHeaderFields as? [String : String],
           let url = response.url {
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: allHeaders, for: url)
            return cookies
        }
        return []
    }
}
