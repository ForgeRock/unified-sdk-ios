//
//  MockResponse.swift
//  PingOidcTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

struct MockResponse {
    static let headers = ["Content-Type": "application/json"]
    
    static var openIdConfiguration: Data {
        """
    {
      "authorization_endpoint" : "\(MockAPIEndpoint.authorization.url.absoluteString)",
      "token_endpoint" : "\(MockAPIEndpoint.token.url.absoluteString)",
      "userinfo_endpoint" : "\(MockAPIEndpoint.userinfo.url.absoluteString)",
      "end_session_endpoint" : "\(MockAPIEndpoint.endSession.url.absoluteString)",
      "revocation_endpoint" : "\(MockAPIEndpoint.revocation.url.absoluteString)"
    }
    """.data(using: .utf8)!
    }
    
    static var token: Data {
         """
    {
      "access_token" : "Dummy AccessToken",
      "token_type" : "Dummy Token Type",
      "scope" : "openid email address",
      "refresh_token" : "Dummy RefreshToken",
      "expires_in" : 2,
      "id_token" : "Dummy IdToken"
    }
    """.data(using: .utf8)!
    }
    
    static var userinfo: Data {
         """
    {
      "sub" : "test-sub",
      "name" : "test-name",
      "email" : "test-email",
      "phone_number" : "test-phone_number",
      "address" : "test-address"
    }
    """.data(using: .utf8)!
    }
    
    static var tokenErrorResponse: Data {
         """
    {
      "error" : "Invalid Grant"
    }
    """.data(using: .utf8)!
    }
    
    static var error: Data {
         """
    {
      "error" : "Internal Server Error"
    }
    """.data(using: .utf8)!
    }
}
