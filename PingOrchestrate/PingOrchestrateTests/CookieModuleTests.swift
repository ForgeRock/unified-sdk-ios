//
//  CookieModuleTests.swift
//  PingOrchestrateTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import XCTest
@testable import PingStorage
@testable import PingOrchestrate

final class CookieModuleTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        MockURLProtocol.startInterceptingRequests()
    }
    
    override func tearDown() {
        super.tearDown()
        MockURLProtocol.stopInterceptingRequests()
    }
    
    func testCookieFromResponse() async {
        MockURLProtocol.requestHandler = { request in
            return (HTTPURLResponse(url: URL(string: "http://openam.example.com")!, statusCode: 200, httpVersion: nil, headerFields: [
                "Set-Cookie":
                    "interactionId=178ce234-afd2-4207-984e-bda28bd7042c; Max-Age=3600; Path=/; Expires=Thu, 09 May 9999 21:38:44 GMT; HttpOnly; Domain=openam.example.com, interactionToken=abc; Max-Age=3600; Path=/; Expires=Thu, 09 May 9999 21:38:44 GMT; HttpOnly; Domain=openam.example.com"
            ])!, Data())
        }
        
        let dummy = Module.of({CustomHeaderConfig()}) { module in
            module.transform {_,_ in
                return SuccessNode(session: EmptySession())
            }
        }
        let memory = MemoryStorage<[PingHTTPCookie]>()
        let workflow = Workflow.createWorkflow { config in
            config.httpClient = HttpClient(session: .shared)
            config.module(dummy)
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = memory
                cookieValue.persist = ["interactionId", "interactionToken"]
            }
        }
        
        _ = await workflow.start()
        let cookies = try? await memory.get()
        XCTAssertNotNil(cookies)
        XCTAssertEqual(cookies?.count, 2)
    }
    
    func testCookieStorageFromResponse() async {
        MockURLProtocol.requestHandler = { request in
            return (HTTPURLResponse(url: URL(string: "http://openam.example.com")!, statusCode: 200, httpVersion: nil, headerFields: [
                "Set-Cookie":
                    "interactionId=178ce234-afd2-4207-984e-bda28bd7042c; Max-Age=3600; Path=/; Expires=Thu, 09 May 9999 21:38:44 GMT; HttpOnly; Domain=.openam.example.com, interactionToken=abc; Max-Age=3600; Path=/; Expires=Thu, 09 May 9999 21:38:44 GMT; HttpOnly; Domain=.openam.example.com"
            ])!, Data())
        }
        
        let dummy = Module.of({CustomHeaderConfig()}) { module in
            module.transform {_,_ in
                return SuccessNode(session: EmptySession())
            }
        }
        let memory = MemoryStorage<[PingHTTPCookie]>()
        let workflow = Workflow.createWorkflow { config in
            config.httpClient = HttpClient(session: .shared)
            config.module(dummy)
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = memory
                cookieValue.persist = ["interactionId"]
            }
        }
        
        _ = await workflow.start()
        let cookies = try? await memory.get()
        XCTAssertNotNil(cookies)
        XCTAssertEqual(cookies?.count, 1)
    }
    
    func testCookieInjectToRequestAndSignoff() async {
        var success = false
        let json: [String: Any] = ["booleanKey": true]
        
        MockURLProtocol.requestHandler = { request in
            return (HTTPURLResponse(url: URL(string: "http://openam.example.com")!, statusCode: 200, httpVersion: nil, headerFields: [
                "Set-Cookie":
                    "interactionId=178ce234-afd2-4207-984e-bda28bd7042c; Max-Age=3600; Path=/; Expires=Thu, 09 May 9999 21:38:44 GMT; HttpOnly; Domain=openam.example.com, interactionToken=abc; Max-Age=3600; Path=/; Expires=Thu, 09 May 9999 21:38:44 GMT; HttpOnly; Domain=openam.example.com"
            ])!, Data())
        }
        
        var workflow = Workflow.createWorkflow { config in
            config.httpClient = HttpClient(session: .shared)
        }
        
        let dummy = Module.of({CustomHeaderConfig()}) { module in
            module.transform { flowContext, _ in
                if success {
                    return SuccessNode(session: EmptySession())
                } else {
                    success = true
                    return TestConnector(context: flowContext, workflow: workflow, input: json, actions: [])
                }
            }
        }
        let memory = MemoryStorage<[PingHTTPCookie]>()
        workflow = Workflow.createWorkflow { config in
            config.httpClient = HttpClient(session: .shared)
            config.module(dummy)
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = memory
                cookieValue.persist = ["interactionId"]
            }
        }
        
        let node = await workflow.start()
        _ = await (node as? Connector)?.next()
        
        XCTAssertTrue(MockURLProtocol.requestHistory[1].allHTTPHeaderFields!["Cookie"]!.contains("interactionId=178ce234-afd2-4207-984e-bda28bd7042c"))
        XCTAssertTrue(MockURLProtocol.requestHistory[1].allHTTPHeaderFields!["Cookie"]!.contains("interactionToken=abc"))
        
        let cookies = try? await memory.get()
        XCTAssertNotNil(cookies)
        XCTAssertEqual(cookies?.count, 1)
        
        let result = await workflow.signOff()
        switch result {
        case .success:
            break
        default:
            XCTFail("Should have succeeded")
        }
        
//        XCTAssertTrue(MockURLProtocol.requestHistory[2].allHTTPHeaderFields!["Cookie"]!.contains("interactionId=178ce234-afd2-4207-984e-bda28bd7042c"))
//        XCTAssertFalse(MockURLProtocol.requestHistory[2].allHTTPHeaderFields!["Cookie"]!.contains("interactionToken=abc"))
        let cookies2 = try? await memory.get()
        XCTAssertNil(cookies2)
        
    }
    
    func testExpiredCookieFromResponse() async {
        MockURLProtocol.requestHandler = { request in
            return (HTTPURLResponse(url: URL(string: "http://openam.example.com")!, statusCode: 200, httpVersion: nil, headerFields: [
                "Set-Cookie":
                    "interactionId=178ce234-afd2-4207-984e-bda28bd7042c; Path=/; Expires=Wed, 21 Oct 1999 01:00:00 GMT; HttpOnly; Domain=openam.example.com, interactionToken=abc; Path=/; Expires=Thu, 09 May 9999 21:38:44 GMT; HttpOnly; Domain=openam.example.com"
            ])!, Data())
        }
        
        let dummy = Module.of({CustomHeaderConfig()}) { module in
            module.transform {_,_ in
                return SuccessNode(session: EmptySession())
            }
        }
        let memory = MemoryStorage<[PingHTTPCookie]>()
        let workflow = Workflow.createWorkflow { config in
            config.httpClient = HttpClient(session: .shared)
            config.module(dummy)
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = memory
                cookieValue.persist = ["interactionId", "interactionToken"]
            }
            
        }
        
        _ = await workflow.start()
        let cookies = try? await memory.get()
        XCTAssertNotNil(cookies)
        XCTAssertEqual(cookies?.count, 1)
    }
    
    
    func testCookieIsExpiredValidationExpired() {
        let setCookie: [String: String] = ["Set-Cookie":"iPlanetDirectoryPro=token; Expires=Wed, 21 Oct 1999 01:00:00 GMT; Domain=openam.example.com"]
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: setCookie, for: URL(string: "https://openam.example.com")!)
        guard let cookie = cookies.first else {
            XCTFail("Failed to parse Cookies from response header")
            return
        }
        XCTAssertTrue(cookie.isExpired)
    }


    func testCookieIsExpiredValidationNotExpired() {
        let setCookie: [String: String] = ["Set-Cookie":"iPlanetDirectoryPro=token; Expires=Wed, 21 Oct 2032 01:00:00 GMT; Domain=openam.example.com"]
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: setCookie, for: URL(string: "https://openam.example.com")!)
        guard let cookie = cookies.first else {
            XCTFail("Failed to parse Cookies from response header")
            return
        }
        XCTAssertFalse(cookie.isExpired)
    }
}
