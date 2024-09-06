//
//  TokenTests.swift
//  PingOidcTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingOidc

final class TokenTests: XCTestCase {
    
    func testInitialization() {
        let token = Token(
            accessToken: "testAccessToken",
            tokenType: "Bearer",
            scope: "testScope",
            expiresIn: 3600,
            refreshToken: "testRefreshToken",
            idToken: "testIdToken"
        )
        
        XCTAssertEqual(token.accessToken, "testAccessToken")
        XCTAssertEqual(token.tokenType, "Bearer")
        XCTAssertEqual(token.scope, "testScope")
        XCTAssertEqual(token.expiresIn, 3600)
        XCTAssertEqual(token.refreshToken, "testRefreshToken")
        XCTAssertEqual(token.idToken, "testIdToken")
        XCTAssertFalse(token.isExpired)
    }
    
    func testEncodingDecoding() throws {
        let token = Token(
            accessToken: "testAccessToken",
            tokenType: "Bearer",
            scope: "testScope",
            expiresIn: 3600,
            refreshToken: "testRefreshToken",
            idToken: "testIdToken"
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(token)
        let decodedToken = try decoder.decode(Token.self, from: data)
        
        XCTAssertEqual(decodedToken.accessToken, "testAccessToken")
        XCTAssertEqual(decodedToken.tokenType, "Bearer")
        XCTAssertEqual(decodedToken.scope, "testScope")
        XCTAssertEqual(decodedToken.expiresIn, 3600)
        XCTAssertEqual(decodedToken.refreshToken, "testRefreshToken")
        XCTAssertEqual(decodedToken.idToken, "testIdToken")
        XCTAssertEqual(decodedToken.expiresAt, token.expiresAt)
    }
    
    func testIsExpired() {
        let token = Token(
            accessToken: "testAccessToken",
            tokenType: "Bearer",
            scope: "testScope",
            expiresIn: -1,
            refreshToken: "testRefreshToken",
            idToken: "testIdToken"
        )
        
        XCTAssertTrue(token.isExpired)
    }
    
    func testIsExpiredWithThreshold() {
        let token = Token(
            accessToken: "testAccessToken",
            tokenType: "Bearer",
            scope: "testScope",
            expiresIn: 3600,
            refreshToken: "testRefreshToken",
            idToken: "testIdToken"
        )
        
        XCTAssertTrue(token.isExpired(threshold: 3601))
        XCTAssertFalse(token.isExpired(threshold: 3599))
    }
}
