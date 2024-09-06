//
//  MemoryStorageTests.swift
//  PingStorageTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingStorage

final class MemoryStorageTests: XCTestCase {
    private var memoryStorage: MemoryStorage<TestItem>!

    override func setUp() {
        super.setUp()
        memoryStorage = MemoryStorage()
    }

    override func tearDown() {
        memoryStorage = nil
        super.tearDown()
    }

    func testSaveItem() async throws {
        let item = TestItem(id: 1, name: "Test")
        try await memoryStorage.save(item: item)
        let retrievedItem = try await memoryStorage.get()
        XCTAssertEqual(retrievedItem, item)
    }

    func testGetItem() async throws {
        let item = TestItem(id: 1, name: "Test")
        try await memoryStorage.save(item: item)
        let retrievedItem = try await memoryStorage.get()
        XCTAssertEqual(retrievedItem, item)
    }

    func testDeleteItem() async throws {
        let item = TestItem(id: 1, name: "Test")
        try await memoryStorage.save(item: item)
        try await memoryStorage.delete()
        let retrievedItem = try await memoryStorage.get()
        XCTAssertNil(retrievedItem)
    }
}

struct TestItem: Codable, Equatable {
    let id: Int
    let name: String
}
