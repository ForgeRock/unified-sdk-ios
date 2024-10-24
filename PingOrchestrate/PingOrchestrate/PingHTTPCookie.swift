//
//  PingHTTPCookie.swift
//  PingOrchestrate
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

public struct PingHTTPCookie: Codable, Sendable {
    var version: Int
    var name: String?
    var value: String?
    var expiresDate: Date?
    var isSessionOnly: Bool
    var domain: String?
    var path: String?
    var isSecure: Bool
    var isHTTPOnly: Bool
    var comment: String?
    var commentURL: URL?
    var portList: [Int]?
    var sameSitePolicy: String?
    
    enum CodingKeys: String, CodingKey {
        case version
        case name
        case value
        case expiresDate
        case isSessionOnly
        case domain
        case path
        case isSecure
        case isHTTPOnly
        case comment
        case commentURL
        case portList
        case sameSitePolicy
    }
    
    public init(from cookie: HTTPCookie) {
        self.version = cookie.version
        self.name = cookie.name
        self.value = cookie.value
        self.expiresDate = cookie.expiresDate
        self.isSessionOnly = cookie.isSessionOnly
        self.domain = cookie.domain
        self.path = cookie.path
        self.isSecure = cookie.isSecure
        self.isHTTPOnly = cookie.isHTTPOnly
        self.comment = cookie.comment
        self.commentURL = cookie.commentURL
        self.portList = cookie.portList?.map { $0.intValue }
        self.sameSitePolicy = cookie.sameSitePolicy?.rawValue
    }
    
    public func toHTTPCookie() -> HTTPCookie? {
        var properties = [HTTPCookiePropertyKey: Any]()
        properties[.version] = self.version
        properties[.name] = self.name
        properties[.value] = self.value
        properties[.expires] = self.expiresDate
        properties[.discard] = self.isSessionOnly ? Constants.true : nil
        properties[.domain] = self.domain
        properties[.path] = self.path
        properties[.secure] = self.isSecure ? Constants.true : nil
        properties[HTTPCookiePropertyKey(Constants.httpOnly)] = self.isHTTPOnly ? Constants.true : nil
        properties[.comment] = self.comment
        properties[.commentURL] = self.commentURL
        properties[.port] = self.portList?.map { NSNumber(value: $0) }
        
        if let sameSitePolicyValue = self.sameSitePolicy {
            properties[HTTPCookiePropertyKey.sameSitePolicy] = HTTPCookieStringPolicy(rawValue: sameSitePolicyValue)
        }
        
        return HTTPCookie(properties: properties)
    }
    
    enum Constants {
        static let `true` = "TRUE"
        static let httpOnly = "HttpOnly"
    }
}
