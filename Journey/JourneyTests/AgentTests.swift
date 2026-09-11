//
//  AgentTests.swift
//  JourneyTests
//
//  Copyright (c) 2025 - 2026 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingJourney
@testable import PingOidc
@testable import PingNetwork

final class AgentTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var agent: CreateAgent!
    var session: MockSession!
    var pkce: Pkce!
    var httpClient: MockHttpClient!
    var oidcConfig: OidcConfig<Void>!
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        session = MockSession()
        pkce = Pkce.generate()
        agent = CreateAgent(session: session, pkce: pkce, cookieName: "iPlanetDirectoryPro")
        
        httpClient = MockHttpClient()
        let clientConfig = OidcClientConfig()
        clientConfig.httpClient = httpClient
        clientConfig.clientId = "test-client"
        clientConfig.redirectUri = "https://example.com/callback"
        clientConfig.scopes = ["openid", "profile"]
        clientConfig.openId = OpenIdConfiguration(authorizationEndpoint: "https://auth.example.com/authorize", tokenEndpoint: "https://auth.example.com/token", userinfoEndpoint: "https://auth.example.com/userInfo", endSessionEndpoint: "https://auth.example.com/endSession", revocationEndpoint: "https://auth.example.com/revoke", pingEndsessionEndpoint: "https://auth.example.com/authorized/ping/endSession")
        oidcConfig = OidcConfig(oidcClientConfig: clientConfig, config: ())
    }
    
    // MARK: - Tests
    
    func testInitialization() {
        XCTAssertEqual(agent.cookieName, "iPlanetDirectoryPro")
        XCTAssertNotNil(agent.session)
        XCTAssertNotNil(agent.pkce)
        XCTAssertFalse(agent.used)
    }
    
    func testConfig() {
        let config = agent.config()
        // Config should return empty closure
        XCTAssertNoThrow(config())
    }
    
    func testEndSession() async {
        let result = try! await agent.endSession(oidcConfig: oidcConfig, idToken: "test-token")
        XCTAssertTrue(result)
    }
    
    func testAuthorizeWithEmptySession() async throws {
        let emptySession = MockSession(value: "")
        let agent = CreateAgent(session: emptySession, pkce: pkce, cookieName: "iPlanetDirectoryPro")
        
        do {
            _ = try await agent.authorize(oidcConfig: oidcConfig)
            XCTFail("Should throw error for empty session")
        } catch {
            XCTAssertTrue(error is OidcError)
            let oidcError = error as! OidcError
            XCTAssertEqual(oidcError.errorMessage, "Authorization error: Please start Journey to authenticate.")
        }
    }
    
    func testSuccessfulAuthorize() async throws {
        let successResponse = HTTPURLResponse(
            url: URL(string: "https://auth.example.com/authorize")!,
            statusCode: 302,
            httpVersion: nil,
            headerFields: ["Location": "https://example.com/callback?code=test-auth-code"]
        )!
        httpClient.mockResponse = (Data(), successResponse)
        
        let authCode = try await agent.authorize(oidcConfig: oidcConfig)
        
        XCTAssertEqual(authCode.code, "test-auth-code")
        XCTAssertNotNil(authCode.codeVerifier)
        XCTAssertTrue(agent.used)
        
        // Verify request parameters
        guard let request = httpClient.lastRequest else {
            XCTFail("request should not be nil")
            return
        }
        
        guard let urlString = request.url else {
            XCTFail("request url should not be nil")
            return
        }
        let url = URL(string: urlString)
        let baseURLString = "\(url?.scheme ?? "")://\(url?.host ?? "")\(url?.path ?? "")"
        XCTAssertEqual(baseURLString, "https://auth.example.com/authorize")
        XCTAssertEqual(request.getHeader(name: "Accept-API-Version"), "resource=2.1, protocol=1.0")
        XCTAssertEqual(request.getHeader(name: "iPlanetDirectoryPro"), "test-session")
    }
    
    func testAuthorizeWithNon302Response() async throws {
        let errorResponse = HTTPURLResponse(
            url: URL(string: "https://auth.example.com/authorize")!,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil
        )!
        httpClient.mockResponse = (Data("Error".utf8), errorResponse)
        
        do {
            _ = try await agent.authorize(oidcConfig: oidcConfig)
            XCTFail("Should throw error for non-302 response")
        } catch {
            XCTAssertTrue(error is OidcError)
            XCTAssertTrue(error.localizedDescription.contains("API error"))
        }
    }
    
    func testAuthorizeWithInvalidRedirect() async throws {
        let invalidResponse = HTTPURLResponse(
            url: URL(string: "https://auth.example.com/authorize")!,
            statusCode: 302,
            httpVersion: nil,
            headerFields: ["Location": "https://example.com/callback"]
        )!
        httpClient.mockResponse = (Data(), invalidResponse)
        
        do {
            _ = try await agent.authorize(oidcConfig: oidcConfig)
            XCTFail("Should throw error for invalid redirect")
        } catch {
            XCTAssertTrue(error is OidcError)
            let oidcError = error as! OidcError
            XCTAssertTrue(oidcError.errorMessage.contains("Code not found in redirect"))
        }
    }
    
    // MARK: - Session Extension Tests
    
    func testSessionAuthCode() {
        let code = "test-code"
        let authCode = session.authCode(pkce: pkce, code: code)
        
        XCTAssertEqual(authCode.code, code)
        XCTAssertEqual(authCode.codeVerifier, pkce.codeVerifier)
    }
    
    func testSessionAuthCodeWithoutPkce() {
        let code = "test-code"
        let authCode = session.authCode(pkce: nil, code: code)
        
        XCTAssertEqual(authCode.code, code)
        XCTAssertNil(authCode.codeVerifier)
    }
}
