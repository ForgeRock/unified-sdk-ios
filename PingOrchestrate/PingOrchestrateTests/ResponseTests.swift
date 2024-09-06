//
//  ResponseTests.swift
//  PingOrchestrateTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingOrchestrate

final class ResponseTests: XCTestCase {
    
    func testInit() async throws {
        let response = Response(data: Data(), response: URLResponse())
        XCTAssertNotNil(response.data)
        XCTAssertNotNil(response.response)
    }
    
    func testDefaultValues() async throws {
        let data = Data("{}".utf8)
        let response = Response(data: data, response: URLResponse())
        XCTAssertNotNil(response.body())
        XCTAssertNotNil(try response.json(data: data))
    }
    
    func testHeader() async throws {
        let data = Data("{}".utf8)
        
        let setCookie: [String: String] = ["Set-Cookie":"Ping=token; Expires=Wed, 21 Oct 1999 01:00:00 GMT; Domain=openam.example.com"]
        
        let urlresponse = HTTPURLResponse(url: URL(string: "https://ping.com")! , statusCode: 200, httpVersion: "1.0", headerFields: setCookie)!
        
        let response = Response(data: data, response: urlresponse)
        
        XCTAssertEqual(response.header(name: "Set-Cookie"), "Ping=token; Expires=Wed, 21 Oct 1999 01:00:00 GMT; Domain=openam.example.com")
        
        XCTAssertEqual(response.status(), 200)
        XCTAssertNotNil(try response.json(data: data))
        
        XCTAssertEqual(response.getCookies().count, 1)
        
    }
    
    func testBodyShouldReturnResponseBodyAsString() {
        let responseBody = "response body".data(using: .utf8)!
        let urlResponse = HTTPURLResponse(url: URL(string: "https://ping.com")! , statusCode: 200, httpVersion: "1.0", headerFields: nil)!
        let response = Response(data: responseBody, response: urlResponse)
        
        XCTAssertEqual(response.body(), "response body")
    }
    
    func testStatusShouldReturnResponseStatusCode() {
        let responseBody = "response body".data(using: .utf8)!
        let urlResponse = HTTPURLResponse(url: URL(string: "https://ping.com")! , statusCode: 200, httpVersion: "1.0", headerFields: nil)!
        let response = Response(data: responseBody, response: urlResponse)
        
        XCTAssertEqual(response.status(), 200)
    }
    
    func testCookiesShouldReturnCookiesFromResponse() {
        let responseBody = "response body".data(using: .utf8)!
        let setCookie: [String: String] = ["Set-Cookie":"cookie1=value1, cookie2=value2"]
        let urlResponse = HTTPURLResponse(url: URL(string: "https://ping.com")! , statusCode: 200, httpVersion: "1.0", headerFields: setCookie)!
        let response = Response(data: responseBody, response: urlResponse)
        
        XCTAssertEqual(response.getCookies().count, 2)
        XCTAssertEqual(response.getCookies().first?.name, "cookie1")
        XCTAssertEqual(response.getCookies().first?.value, "value1")
        XCTAssertEqual(response.getCookies().last?.name, "cookie2")
        XCTAssertEqual(response.getCookies().last?.value, "value2")
        XCTAssertEqual(response.header(name: "Set-Cookie"), "cookie1=value1, cookie2=value2")
    }
    
    func testHeaderShouldReturnSpecificHeaderValue() {
        let responseBody = "response body".data(using: .utf8)!
        let urlResponse = HTTPURLResponse(url: URL(string: "https://ping.com")! , statusCode: 200, httpVersion: "1.0", headerFields: ["Content-Type": "application/json"])!
        let response = Response(data: responseBody, response: urlResponse)
        
        XCTAssertEqual(response.header(name: "Content-Type"), "application/json")
    }
    
    func testHeaderShouldReturnNullIfHeaderIsNotPresent() {
        let responseBody = "response body".data(using: .utf8)!
        let urlResponse = HTTPURLResponse(url: URL(string: "https://ping.com")! , statusCode: 200, httpVersion: "1.0", headerFields: nil)!
        let response = Response(data: responseBody, response: urlResponse)
        
        XCTAssertNil(response.header(name: "Non-Existent-Header"))
    }
}
