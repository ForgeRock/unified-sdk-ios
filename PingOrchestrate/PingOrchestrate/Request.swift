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
import UIKit

/// Class for a Request. A Request represents a request to be sent over the network.
public final class Request {
    
    public private(set) var urlRequest: URLRequest = URLRequest(url: URL(string: "https://")!)
    
    /// Initializes a Request with a URL.
    /// - Parameter urlString: The URL of the request.
    public init(urlString: String = "https://") {
        self.urlRequest.url = URL(string: urlString)!
    }
    
    /// Sets the URL of the request.
    /// - Parameter urlString: The URL to be set.
    public func url(_ urlString: String) {
        if let url = URL(string: urlString) {
            self.urlRequest.url = url
            // keeping Default Content type
            self.header(name: Constants.contentType, value: ContentType.json.rawValue)
        }
    }
    
    /// Adds a parameter to the request.
    /// - Parameters:
    ///   - name: The name of the parameter.
    ///   - value: The value of the parameter.
    public func parameter(name: String, value: String) {
        if let url = self.urlRequest.url {
            if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                if components.queryItems == nil {
                    components.queryItems = []
                }
                components.queryItems?.append(URLQueryItem(name: name, value: value))
                if let updatedURL = components.url {
                    self.urlRequest.url = updatedURL
                }
            }
        }
    }
    
    /// Adds a header to the request.
    /// - Parameters:
    ///   - name: The name of the header.
    ///   - value: The value of the header.
    public func header(name: String, value: String) {
        self.urlRequest.setValue(value, forHTTPHeaderField: name)
    }
    
    /// Adds cookies to the request.
    /// - Parameter cookies: The cookies to be added.
    public func cookies(cookies: [HTTPCookie]) {
        let headers = HTTPCookie.requestHeaderFields(with: cookies)
        for (key, value) in headers {
            self.urlRequest.addValue(value, forHTTPHeaderField: key)
        }
    }
    
    /// Sets the body of the request.
    /// - Parameter body: The body to be set.
    public func body(body: [String: Any]) {
        self.urlRequest.httpMethod = HTTPMethod.post.rawValue
        self.urlRequest.setValue(ContentType.json.rawValue, forHTTPHeaderField: Constants.contentType)
        self.urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
    }
    
    /// Sets the form of the request.
    /// - Parameter formData: The form to be set.
    public func form(formData: [String: String]) {
        var formString = ""
        for (key, value) in formData {
            formString += "\(key)=\(value)&"
        }
        if !formString.isEmpty {
            formString.removeLast() // Remove the last '&' character
        }
        
        self.urlRequest.httpMethod = HTTPMethod.post.rawValue
        self.urlRequest.setValue(ContentType.urlEncoded.rawValue, forHTTPHeaderField: Constants.contentType)
        self.urlRequest.httpBody = formString.data(using: .utf8)
    }
    
    public enum ContentType: String {
        case plainText = "text/plain"
        case json = "application/json"
        case urlEncoded = "application/x-www-form-urlencoded"
    }
    
    public enum HTTPMethod: String {
        case get = "GET"
        case put = "PUT"
        case post = "POST"
        case delete = "DELETE"
    }
    
    public enum Constants {
        public static let contentType = "Content-Type"
        public static let accept = "Accept"
        public static let xRequestedWith = "x-requested-with"
        public static let xRequestedPlatform = "x-requested-platform"
        public static let forgerockSdk = "forgerock-sdk"
        public static let ios = "ios"
        public static let stCookie = "ST"
        public static let stNoSsCookie = "ST-NO-SS"
    }
}
