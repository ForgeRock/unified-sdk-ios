// 
//  CallbackFactoryTests.swift
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

class CallbackFactoryTests: XCTestCase {
    override func setUp() {
        CollectorFactory.shared.register(type: "type1", collector: DummyCallback.self)
        CollectorFactory.shared.register(type: "type2", collector: Dummy2Callback.self)
    }
    
    func testShouldReturnListOfCollectorsWhenValidTypesAreProvided() {
        let jsonArray: [[String: Any]] = [
            ["type": "type1"],
            ["type": "type2"]
        ]
        
        let callbacks = CollectorFactory.shared.collector(from: jsonArray)
        XCTAssertEqual((callbacks[0] as? DummyCallback)?.value, "dummy")
        XCTAssertEqual((callbacks[1] as? Dummy2Callback)?.value, "dummy2")
        
        XCTAssertEqual(callbacks.count, 2)
    }
    
    func testShouldReturnEmptyListWhenNoValidTypesAreProvided() {
        let jsonArray: [[String: Any]] = [
            ["type": "invalidType"]
        ]
        
        let callbacks = CollectorFactory.shared.collector(from: jsonArray)
        
        XCTAssertTrue(callbacks.isEmpty)
    }
    
    func testShouldReturnEmptyListWhenJsonArrayIsEmpty() {
        let jsonArray: [[String: Any]] = []
        
        let callbacks = CollectorFactory.shared.collector(from: jsonArray)
        
        XCTAssertTrue(callbacks.isEmpty)
    }
}

class DummyCallback: Collector {
    var id: UUID = UUID()
    var value: String?
    
    required public init(with json: [String: Any]) {
        value = "dummy"
    }
}

class Dummy2Callback: Collector {
    var id: UUID = UUID()
    var value: String?
    
    required public init(with json: [String: Any]) {
        value = "dummy2"
    }
}
