//
//  PkceTests.swift
//  PingOidcTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingOidc

final class PkceTests: XCTestCase {
    
    func testGeneratePkce() {
        let pkce = Pkce.generate()
        
        XCTAssertFalse(pkce.codeVerifier.isEmpty, "Code verifier should not be empty")
        XCTAssertFalse(pkce.codeChallenge.isEmpty, "Code challenge should not be empty")
        XCTAssertEqual(pkce.codeChallengeMethod, "S256", "Code challenge method should be 'S256'")
    }
    
    func testGenerateDifferentPkce() {
        let pkce1 = Pkce.generate()
        let pkce2 = Pkce.generate()
        
        XCTAssertTrue(pkce1.codeVerifier != pkce2.codeVerifier, "Code verifier should be different")
        XCTAssertTrue(pkce1.codeChallenge != pkce2.codeChallenge, "Code challenge should be different")
    }
}
