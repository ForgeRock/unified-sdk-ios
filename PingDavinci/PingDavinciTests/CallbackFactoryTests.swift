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
  
    override func setUp() async throws {
      await CollectorFactory.shared.register(type: "type1", collector: DummyCallback.self)
      await CollectorFactory.shared.register(type: "type2", collector: Dummy2Callback.self)
    }
    
  func testShouldReturnListOfCollectorsWhenValidTypesAreProvided() async {
        let jsonArray: [Field] = [Field(type: "type1", value: "", key: "", label: ""),Field(type: "type2", value: "", key: "", label: "")]
    
        let callbacks = await CollectorFactory.shared.collector(from: jsonArray)
        XCTAssertEqual((callbacks[0] as? DummyCallback)?.value, "dummy")
        XCTAssertEqual((callbacks[1] as? Dummy2Callback)?.value, "dummy2")
        
        XCTAssertEqual(callbacks.count, 2)
    }
    
    func testShouldReturnEmptyListWhenNoValidTypesAreProvided() async {
      let jsonArray: [Field] = [Field(type: "invalidType", value: "", key: "", label: "")]
           
        let callbacks = await CollectorFactory.shared.collector(from: jsonArray)
        
        XCTAssertTrue(callbacks.isEmpty)
    }
    
    func testShouldReturnEmptyListWhenJsonArrayIsEmpty() async {
        let jsonArray: [Field] = []
        
        let callbacks = await CollectorFactory.shared.collector(from: jsonArray)
        
        XCTAssertTrue(callbacks.isEmpty)
    }
}

class DummyCallback: Collector, @unchecked Sendable {
    var id: UUID = UUID()
    var value: String?
    
    required public init(with json: Field) {
        value = "dummy"
    }
}

class Dummy2Callback: Collector, @unchecked Sendable {
    var id: UUID = UUID()
    var value: String?
    
    required public init(with json: Field) {
        value = "dummy2"
    }
}
