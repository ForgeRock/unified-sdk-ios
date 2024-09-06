//
//  RequestTests.swift
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

final class RequestTests: XCTestCase {
    
    func testInit() async throws {
        let request = Request()
        XCTAssertNotNil(request)
    }
    
    func testDefaultValues() async throws {
        let request = Request()
        let body = ["bodykey": "bodyvalue"]
        let json = try? JSONSerialization.data(withJSONObject: body, options: [])
        request.url("https://pingone.com")
        request.header(name: "testHeader", value: "testValue")
        request.header(name: "testHeader1", value: "testValue2")
        request.header(name: "testHeader1", value: "testValue2")
        request.parameter(name: "key1", value: "key1Value")
        request.parameter(name: "key2", value: "key2Value")
        request.body(body: body)
        XCTAssertTrue(request.urlRequest.httpBody == json)
        XCTAssertTrue(request.urlRequest.allHTTPHeaderFields?.count == 3)
        XCTAssertTrue(request.urlRequest.url?.absoluteString == "https://pingone.com?key1=key1Value&key2=key2Value")
    }
    
    func testDefaultValuesFormUrlEncoded() async throws {
        let request = Request()
        let body = ["bodykey": "bodyvalue"]
        let jsonData = "bodykey=bodyvalue".data(using: .utf8)
        request.url("https://pingone.com")
        request.header(name: "testHeader", value: "testValue")
        request.header(name: "testHeader1", value: "testValue2")
        request.header(name: "testHeader1", value: "testValue2")
        request.parameter(name: "key1", value: "key1Value")
        request.parameter(name: "key2", value: "key2Value")
        request.form(formData: body)
        XCTAssertTrue(request.urlRequest.httpBody == jsonData)
        XCTAssertTrue(request.urlRequest.allHTTPHeaderFields?.count == 3)
        XCTAssertTrue(request.urlRequest.url?.absoluteString == "https://pingone.com?key1=key1Value&key2=key2Value")
    }
    
    func testUrlSetsTheCorrectUrl() {
        let request = Request()
        request.url("http://example.com")
        XCTAssertEqual("http://example.com", request.urlRequest.url?.absoluteString)
    }
    
    func testParameterAppendsTheCorrectParameter() {
        let request = Request()
        request.parameter(name: "key", value: "value")
        XCTAssertEqual("value", request.urlRequest.url?.query?.components(separatedBy: "&").first(where: { $0.contains("key=") })?.split(separator: "=")[1])
    }
    
    func testHeaderAppendsTheCorrectHeader() {
        let request = Request()
        request.header(name: "Content-Type", value: "application/json")
        XCTAssertEqual("application/json", request.urlRequest.allHTTPHeaderFields?["Content-Type"])
    }
    
    func testCookiesSetsTheCorrectCookies() {
        let request = Request()
        let setCookie: [String: String] = ["Set-Cookie":"interactionId=178ce234-afd2-4207-984e-bda28bd7042c; Max-Age=3600; Path=/; Expires=Thu, 09 May 2024 21:38:44 GMT; HttpOnly; Secure, interactionToken=abc; Max-Age=3600; Path=/; Expires=Thu, 09 May 2024 21:38:44 GMT; HttpOnly; Secure"]
        let httpCookies = HTTPCookie.cookies(withResponseHeaderFields: setCookie, for: URL(string: "https://openam.example.com")!)
        request.cookies(cookies: httpCookies)
        
        let cookieHeader = request.urlRequest.allHTTPHeaderFields?["Cookie"] ?? ""
        XCTAssertTrue(cookieHeader.contains("interactionId"))
        XCTAssertTrue(cookieHeader.contains("interactionToken"))
    }
    
    func testBodySetsTheCorrectBody() {
        let request = Request()
        let jsonData = try! JSONSerialization.data(withJSONObject: ["key": "value"], options: [])
        let body = try! JSONSerialization.jsonObject(with: jsonData, options: []) as! [String: Any]
        request.body(body: body)
        XCTAssertEqual(String(data: request.urlRequest.httpBody!, encoding: .utf8), """
                           {"key":"value"}
                           """)
    }
    
    func testFormSetsTheCorrectFormData() {
        let request = Request()
        let body = ["key": "value"]
        request.form(formData: body)
        XCTAssertEqual(String(data: request.urlRequest.httpBody!, encoding: .utf8), "key=value")
    }
}
