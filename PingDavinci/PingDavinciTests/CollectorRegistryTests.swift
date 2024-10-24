//
//  CollectorRegistryTests.swift
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

class CollectorRegistryTests: XCTestCase {
    
    private var collectorFactory: CollectorFactory!
    
    override func setUp() {
        super.setUp()
        collectorFactory = CollectorFactory()
    }
    
    override func tearDown() async throws {
       try await super.tearDown()
       await collectorFactory.reset()
    }
    
  func testShouldRegisterCollector() async {
    
    let jsonArray: [Field] = [Field(type: "TEXT", value: "", key: "", label: ""),
                              Field(type: "PASSWORD", value: "", key: "", label: ""),
                              Field(type: "SUBMIT_BUTTON", value: "", key: "", label: ""),
                              Field(type: "FLOW_BUTTON", value: "", key: "", label: "")]
    
        let collectors = await collectorFactory.collector(from: jsonArray)
        XCTAssertTrue(collectors[0] is TextCollector)
        XCTAssertTrue(collectors[1] is PasswordCollector)
        XCTAssertTrue(collectors[2] is SubmitCollector)
        XCTAssertTrue(collectors[3] is FlowCollector)
    }
    
    func testShouldIgnoreUnknownCollector() async {
      let jsonArray: [Field] = [Field(type: "TEXT", value: "", key: "", label: ""),
                                Field(type: "PASSWORD", value: "", key: "", label: ""),
                                Field(type: "SUBMIT_BUTTON", value: "", key: "", label: ""),
                                Field(type: "FLOW_BUTTON", value: "", key: "", label: ""),
                                Field(type: "UNKNOWN", value: "", key: "", label: "")]
        
        let collectors = await collectorFactory.collector(from: jsonArray)
        XCTAssertEqual(collectors.count, 4)
    }
}
