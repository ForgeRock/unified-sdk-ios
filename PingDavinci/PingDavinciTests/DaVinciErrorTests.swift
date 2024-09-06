//
//  DaVinciErrorTests.swift
//  PingDavinciTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import XCTest
@testable import PingOrchestrate
@testable import PingStorage
@testable import PingLogger
@testable import PingOidc
@testable import PingDavinci

class DaVinciErrorTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        MockURLProtocol.startInterceptingRequests()
        _ = CollectorFactory()
    }
    
    override func tearDown() {
        super.tearDown()
        MockURLProtocol.stopInterceptingRequests()
    }
    
    func testDaVinciWellKnownEndpointFailed() async throws {
        
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 404, httpVersion: nil, headerFields: MockResponse.headers)!, "Not Found".data(using: .utf8)!)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = HttpClient(session: .shared)
            
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = "test"
                oidcValue.scopes = ["openid", "email", "address"]
                oidcValue.redirectUri = "http://localhost:8080"
                oidcValue.discoveryEndpoint = "http://localhost/.well-known/openid-configuration"
                oidcValue.storage = MemoryStorage()
                oidcValue.logger = LogManager.standard
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = MemoryStorage()
                cookieValue.persist = ["ST"]
            }
        }
        
        let node = await daVinci.start()
        XCTAssertTrue(node is ErrorNode)
        XCTAssertTrue((node as! ErrorNode).cause is ApiError)
        let error = (node as! ErrorNode).cause as! ApiError
        
        switch error {
        case .error(let code, _):
            XCTAssertEqual(code, 500)
        }
        
    }
    
    func testDaVinciAuthorizeEndpointFailed() async throws {
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
            case MockAPIEndpoint.authorization.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: 400, httpVersion: nil, headerFields: MockResponse.headers)!, """
                {
                    "id": "7bbe285f-c0e0-41ef-8925-c5c5bb370acc",
                    "code": "INVALID_REQUEST",
                    "message": "Invalid DV Flow Policy ID: Single_Factor"
                }
                """.data(using: .utf8)!)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = HttpClient(session: .shared)
            
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = "test"
                oidcValue.scopes = ["openid", "email", "address"]
                oidcValue.redirectUri = "http://localhost:8080"
                oidcValue.discoveryEndpoint = "http://localhost/.well-known/openid-configuration"
                oidcValue.storage = MemoryStorage()
                oidcValue.logger = LogManager.standard
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = MemoryStorage()
                cookieValue.persist = ["ST"]
            }
        }
        
        let node = await daVinci.start()
        XCTAssertTrue(node is FailureNode)
        let failureNode = node as! FailureNode
        XCTAssertTrue(failureNode.input.description.contains("INVALID_REQUEST"))
    }
    
    func testDaVinciAuthorizeEndpointFailedWithOKResponseButErrorDuringTransform() async throws {
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
            case MockAPIEndpoint.authorization.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, """
                {
                    "environment": {
                        "id": "0c6851ed-0f12-4c9a-a174-9b1bf8b438ae"
                    },
                    "status": "FAILED",
                    "error": {
                        "code": "login_required",
                        "message": "The request could not be completed. There was an issue processing the request"
                    }
                }
                """.data(using: .utf8)!)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = HttpClient(session: .shared)
            
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = "test"
                oidcValue.scopes = ["openid", "email", "address"]
                oidcValue.redirectUri = "http://localhost:8080"
                oidcValue.discoveryEndpoint = "http://localhost/.well-known/openid-configuration"
                oidcValue.storage = MemoryStorage()
                oidcValue.logger = LogManager.standard
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = MemoryStorage()
                cookieValue.persist = ["ST"]
            }
        }
        
        let node = await daVinci.start()
        XCTAssertTrue(node is ErrorNode)
        let error = (node as! ErrorNode).cause as! ApiError
        
        switch error {
        case .error(_, let message):
            XCTAssertTrue(message.contains("login_required"))
        }
        
    }
    
    func testDaVinciTransformFailed() async throws {
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
            case MockAPIEndpoint.authorization.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.authorizeResponseHeaders)!, " Not a Json ".data(using: .utf8)!)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = HttpClient(session: .shared)
            
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = "test"
                oidcValue.scopes = ["openid", "email", "address"]
                oidcValue.redirectUri = "http://localhost:8080"
                oidcValue.discoveryEndpoint = "http://localhost/.well-known/openid-configuration"
                oidcValue.storage = MemoryStorage()
                oidcValue.logger = LogManager.standard
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = MemoryStorage()
                cookieValue.persist = ["ST"]
            }
        }
        
        let node = await daVinci.start()
        XCTAssertTrue(node is ErrorNode)
    }
    
    func testDaVinciInvalidPassword() async throws {
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
            case MockAPIEndpoint.customHTMLTemplate.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.customHTMLTemplate.url, statusCode: 400, httpVersion: nil, headerFields: MockResponse.customHTMLTemplateHeaders)!, MockResponse.customHTMLTemplateWithInvalidPassword)
            case MockAPIEndpoint.authorization.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.authorizeResponseHeaders)!, MockResponse.authorizeResponse)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = HttpClient(session: .shared)
            
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = "test"
                oidcValue.scopes = ["openid", "email", "address"]
                oidcValue.redirectUri = "http://localhost:8080"
                oidcValue.discoveryEndpoint = "http://localhost/.well-known/openid-configuration"
                oidcValue.storage = MemoryStorage()
                oidcValue.logger = LogManager.standard
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = MemoryStorage()
                cookieValue.persist = ["ST"]
            }
        }
        
        let node =  await daVinci.start()
        XCTAssertTrue(node is Connector)
        let connector = node as! Connector
        if let textCollector = connector.collectors[0] as? TextCollector {
            textCollector.value = "My First Name"
        }
        if let passwordCollector = connector.collectors[1] as? PasswordCollector {
            passwordCollector.value = "My Password"
        }
        if let submitCollector = connector.collectors[2] as? SubmitCollector {
            submitCollector.value = "click me"
        }
        
        let next = await connector.next()
        
        XCTAssertEqual((connector.collectors[1] as? PasswordCollector)?.value, "")
        
        XCTAssertTrue(next is FailureNode)
        let failureNode = next as! FailureNode
        XCTAssertEqual(failureNode.message, "Invalid username and/or password")
        XCTAssertTrue(failureNode.input.description.contains("The provided password did not match provisioned password"))
    }
}
