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
    
    override func tearDown() {
        super.tearDown()
        collectorFactory.reset()
    }
    
    func testShouldRegisterCollector() {
        let jsonArray: [[String: Any]] = [
            ["type": "TEXT"],
            ["type": "PASSWORD"],
            ["type": "SUBMIT_BUTTON"],
            ["type": "FLOW_BUTTON"]
        ]
        
        let collectors = collectorFactory.collector(from: jsonArray)
        XCTAssertTrue(collectors[0] is TextCollector)
        XCTAssertTrue(collectors[1] is PasswordCollector)
        XCTAssertTrue(collectors[2] is SubmitCollector)
        XCTAssertTrue(collectors[3] is FlowCollector)
    }
    
    func testShouldIgnoreUnknownCollector() {
        let jsonArray: [[String: Any]] = [
            ["type": "TEXT"],
            ["type": "PASSWORD"],
            ["type": "SUBMIT_BUTTON"],
            ["type": "FLOW_BUTTON"],
            ["type": "UNKNOWN"]
        ]
        
        let collectors = collectorFactory.collector(from: jsonArray)
        XCTAssertEqual(collectors.count, 4)
    }
}
