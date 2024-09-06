//
//  CustomHeaderModuleTests.swift
//  PingOrchestrateTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import XCTest
@testable import PingOrchestrate

final class CustomHeaderModuleTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        MockURLProtocol.startInterceptingRequests()
    }
    
    override func tearDown() {
        super.tearDown()
        MockURLProtocol.stopInterceptingRequests()
    }
    
    func testCustomHeaderAddedToRequest() async {
        MockURLProtocol.requestHandler = { request in
            
            XCTAssertNotNil(request.allHTTPHeaderFields?["X-Custom-Header"])
            XCTAssertEqual("CustomValue", request.allHTTPHeaderFields?["X-Custom-Header"])
            
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
            
        }
        
        let workflow = Workflow.createWorkflow { config in
            config.httpClient = HttpClient(session: .shared)
            config.module(CustomHeader.config) { customHeaderConfig in
                customHeaderConfig.header(name: "X-Custom-Header", value: "CustomValue")
                
            }
        }
        
        _ = await workflow.start()
    }
}
