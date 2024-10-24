// 
//  FieldCollectorTests.swift
//  PingDavinciTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import XCTest
@testable import PingDavinci

class FieldCollectorTests: XCTestCase {
    
    class MockFieldCollector: FieldCollector, @unchecked Sendable  {}
    
    func testShouldInitializeKeyAndLabelFromJsonObject() {
        let jsonObject: Field = Field(type: "", value: "", key: "testKey", label: "testLabel")
        let fieldCollector = MockFieldCollector(with: jsonObject)
        
        XCTAssertEqual("testKey", fieldCollector.key)
        XCTAssertEqual("testLabel", fieldCollector.label)
    }
    
    func testShouldReturnValueWhenValueIsSet() {
        let fieldCollector = MockFieldCollector()
        fieldCollector.value = "test"
        XCTAssertEqual("test", fieldCollector.value)
    }
}
