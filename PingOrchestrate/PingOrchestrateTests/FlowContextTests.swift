//
//  FlowContextTests.swift
//  PingOrchestrateTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingOrchestrate

final class FlowContextTests: XCTestCase {
    
    func testInit() async throws {
        let context = FlowContext(flowContext: SharedContext(["cookie": "pingCookie"]))
        XCTAssertNotNil(context)
    }
    
    func testDefaultValues() async throws {
        let context = FlowContext(flowContext: SharedContext(["cookie": "pingCookie"]))
        let request = Request()
        let body = ["bodykey": "bodyvalue"]
        request.url("https://pingone.com")
        request.header(name: "testHeader", value: "testValue")
        request.header(name: "testHeader1", value: "testValue2")
        request.header(name: "testHeader1", value: "testValue2")
        request.parameter(name: "key1", value: "key1Value")
        request.parameter(name: "key2", value: "key2Value")
        request.body(body: body)
        
        context.flowContext.set(key: "request", value: request)
        let cookie = context.flowContext.get(key: "cookie")
        XCTAssertNotNil(cookie)
        let requestValue = context.flowContext.get(key: "request")
        XCTAssertTrue(requestValue != nil)
        XCTAssertTrue(requestValue is Request)
    }
}
