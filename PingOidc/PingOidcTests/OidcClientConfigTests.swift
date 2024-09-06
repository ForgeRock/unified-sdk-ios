//
//  OidcClientConfigTests.swift
//  PingOidcTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingOidc
@testable import PingOrchestrate
@testable import PingLogger
@testable import PingStorage

final class OidcClientConfigTests: XCTestCase {
    
    var oidcClientConfig: OidcClientConfig!
    
    override func setUp() {
        super.setUp()
        oidcClientConfig = OidcClientConfig()
        oidcClientConfig.discoveryEndpoint = MockAPIEndpoint.discovery.url.absoluteString
        oidcClientConfig.storage = MockStorage<Token>()
        oidcClientConfig.httpClient = HttpClient(session: .shared)
        MockURLProtocol.startInterceptingRequests()
    }
    
    override func tearDown() {
        oidcClientConfig = nil
        MockURLProtocol.stopInterceptingRequests()
        super.tearDown()
    }
    
    func testDefaultInitialization() {
        oidcClientConfig = OidcClientConfig()
        
        XCTAssertNil(oidcClientConfig.openId)
        XCTAssertEqual(oidcClientConfig.refreshThreshold, 0)
        XCTAssertNil(oidcClientConfig.agent)
        XCTAssertEqual(oidcClientConfig.discoveryEndpoint, "")
        XCTAssertEqual(oidcClientConfig.clientId, "")
        XCTAssertTrue(oidcClientConfig.scopes.isEmpty)
        XCTAssertEqual(oidcClientConfig.redirectUri, "")
        XCTAssertNil(oidcClientConfig.loginHint)
        XCTAssertNil(oidcClientConfig.state)
        XCTAssertNil(oidcClientConfig.nonce)
        XCTAssertNil(oidcClientConfig.display)
        XCTAssertNil(oidcClientConfig.prompt)
        XCTAssertNil(oidcClientConfig.uiLocales)
        XCTAssertNil(oidcClientConfig.acrValues)
        XCTAssertTrue(oidcClientConfig.additionalParameters.isEmpty)
        XCTAssertNil(oidcClientConfig.httpClient)
    }
    
    func testUpdateAgent() {
        let agent = MockAgent()
        oidcClientConfig.updateAgent(agent)
        XCTAssertNotNil(oidcClientConfig.agent)
    }
    
    func testScopeInsertion() {
        oidcClientConfig.scope("openid")
        XCTAssertTrue(oidcClientConfig.scopes.contains("openid"))
    }
    
    func testOidcInitializeInvalidDiscovery() async throws {
        
        MockURLProtocol.requestHandler =  { request in
            return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.error)
        }
        
        do {
            try await oidcClientConfig.oidcInitialize()
        } catch {
            XCTAssertNotNil(error)
        }
        XCTAssertNil(oidcClientConfig.openId)
    }
    
    func testOidcInitializeValidDiscovery() async throws {
        
        MockURLProtocol.requestHandler =  { request in
            return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
        }
        
        do {
            try await oidcClientConfig.oidcInitialize()
            XCTAssertNotNil(oidcClientConfig.openId)
            XCTAssertEqual(MockAPIEndpoint.authorization.url.absoluteString, oidcClientConfig.openId!.authorizationEndpoint)
            XCTAssertEqual(MockAPIEndpoint.token.url.absoluteString, oidcClientConfig.openId!.tokenEndpoint)
            XCTAssertEqual(MockAPIEndpoint.userinfo.url.absoluteString, oidcClientConfig.openId!.userinfoEndpoint)
            XCTAssertEqual(MockAPIEndpoint.endSession.url.absoluteString, oidcClientConfig.openId!.endSessionEndpoint)
            XCTAssertEqual(MockAPIEndpoint.revocation.url.absoluteString, oidcClientConfig.openId!.revocationEndpoint)
        } catch {
            XCTFail("Initialization failed with error: \(error)")
        }
    }
    
    func testClone() {
        oidcClientConfig.agent = AgentDelegate(agent: MockAgent(), agentConfig: (), oidcClientConfig: oidcClientConfig)
        oidcClientConfig.logger = LogManager.standard
        oidcClientConfig.storage = MockStorage<Token>()
        oidcClientConfig.discoveryEndpoint = "https://example.com"
        oidcClientConfig.clientId = "clientId"
        oidcClientConfig.scopes.insert("openid")
        oidcClientConfig.redirectUri = "http://localhost/callback"
        oidcClientConfig.loginHint = "loginHint"
        oidcClientConfig.nonce = "nonce"
        oidcClientConfig.display = "display"
        oidcClientConfig.prompt = "prompt"
        oidcClientConfig.uiLocales = "uiLocales"
        oidcClientConfig.acrValues = "acrValues"
        oidcClientConfig.additionalParameters = ["param": "value"]
        oidcClientConfig.httpClient = HttpClient()
        
        let clonedConfig = oidcClientConfig.clone()
        
        XCTAssertEqual(oidcClientConfig.openId.debugDescription, clonedConfig.openId.debugDescription)
        XCTAssertEqual(oidcClientConfig.agent.debugDescription, clonedConfig.agent.debugDescription)
        XCTAssertEqual(oidcClientConfig.discoveryEndpoint, clonedConfig.discoveryEndpoint)
        XCTAssertEqual(oidcClientConfig.clientId, clonedConfig.clientId)
        XCTAssertEqual(oidcClientConfig.scopes, clonedConfig.scopes)
        XCTAssertEqual(oidcClientConfig.redirectUri, clonedConfig.redirectUri)
        XCTAssertEqual(oidcClientConfig.loginHint, clonedConfig.loginHint)
        XCTAssertEqual(oidcClientConfig.nonce, clonedConfig.nonce)
        XCTAssertEqual(oidcClientConfig.display, clonedConfig.display)
        XCTAssertEqual(oidcClientConfig.prompt, clonedConfig.prompt)
        XCTAssertEqual(oidcClientConfig.uiLocales, clonedConfig.uiLocales)
        XCTAssertEqual(oidcClientConfig.acrValues, clonedConfig.acrValues)
        XCTAssertEqual(oidcClientConfig.additionalParameters, clonedConfig.additionalParameters)
        XCTAssertEqual(oidcClientConfig.httpClient.debugDescription, clonedConfig.httpClient.debugDescription)
    }
    
    func testUpdate() {
        let otherConfig = OidcClientConfig()
        otherConfig.agent = AgentDelegate(agent: MockAgent(), agentConfig: (), oidcClientConfig: oidcClientConfig)
        otherConfig.logger = LogManager.standard
        otherConfig.storage = MockStorage<Token>()
        otherConfig.discoveryEndpoint = "https://example.com"
        otherConfig.clientId = "clientId"
        otherConfig.scopes.insert("openid")
        otherConfig.redirectUri = "http://localhost/callback"
        otherConfig.loginHint = "loginHint"
        otherConfig.nonce = "nonce"
        otherConfig.display = "display"
        otherConfig.prompt = "prompt"
        otherConfig.uiLocales = "uiLocales"
        otherConfig.acrValues = "acrValues"
        otherConfig.additionalParameters = ["param": "value"]
        otherConfig.httpClient = HttpClient()
        
        oidcClientConfig.update(with: otherConfig)
        
        XCTAssertEqual(otherConfig.openId.debugDescription, oidcClientConfig.openId.debugDescription)
        XCTAssertEqual(otherConfig.agent.debugDescription, oidcClientConfig.agent.debugDescription)
        XCTAssertEqual(otherConfig.discoveryEndpoint, oidcClientConfig.discoveryEndpoint)
        XCTAssertEqual(otherConfig.clientId, oidcClientConfig.clientId)
        XCTAssertEqual(otherConfig.scopes, oidcClientConfig.scopes)
        XCTAssertEqual(otherConfig.redirectUri, oidcClientConfig.redirectUri)
        XCTAssertEqual(otherConfig.loginHint, oidcClientConfig.loginHint)
        XCTAssertEqual(otherConfig.nonce, oidcClientConfig.nonce)
        XCTAssertEqual(otherConfig.display, oidcClientConfig.display)
        XCTAssertEqual(otherConfig.prompt, oidcClientConfig.prompt)
        XCTAssertEqual(otherConfig.uiLocales, oidcClientConfig.uiLocales)
        XCTAssertEqual(otherConfig.acrValues, oidcClientConfig.acrValues)
        XCTAssertEqual(otherConfig.additionalParameters, oidcClientConfig.additionalParameters)
        XCTAssertEqual(otherConfig.httpClient.debugDescription, oidcClientConfig.httpClient.debugDescription)
    }
}

// Mock classes for AgentDelegateProtocol, Agent, HttpClient, etc.
class MockAgent: Agent {
    func config() -> () -> T {
        return {}
    }
    
    func endSession(oidcConfig: PingOidc.OidcConfig<T>, idToken: String) async throws -> Bool {
        let params = [
            "client_id": oidcConfig.oidcClientConfig.clientId,
            "id_token_hint": idToken
        ]
        let request = Request()
        request.url(MockAPIEndpoint.endSession.url.absoluteString)
        request.form(formData: params)
        do {
            let (_, _) = try await oidcConfig.oidcClientConfig.httpClient!.sendRequest(request: request)
        } catch {
        }
        return true
    }
    
    func authorize(oidcConfig: PingOidc.OidcConfig<T>) async throws -> PingOidc.AuthCode {
        return AuthCode(code: "TestAgent", codeVerifier: "codeVerifier")
    }
    
    typealias T = Void
}
