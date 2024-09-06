//
//  KeychainStorageTests.swift
//  PingStorageTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingStorage

final class KeychainStorageTests: XCTestCase {
    private var keychainStorage: KeychainStorage<TestItem>!

    override func setUp() {
        super.setUp()
        keychainStorage = KeychainStorage(account: "testAccount", encryptor: SecuredKeyEncryptor() ?? NoEncryptor())
    }

    override func tearDown() {
      Task {
        try? await keychainStorage.delete()
        keychainStorage = nil
      }
      super.tearDown()
    }

    func testSaveItem() async throws {
        let item = TestItem(id: 1, name: "Test")
        try await keychainStorage.save(item: item)
        let retrievedItem = try await keychainStorage.get()
        XCTAssertEqual(retrievedItem, item)
    }

    func testGetItem() async throws {
        let item = TestItem(id: 1, name: "Test")
        try await keychainStorage.save(item: item)
        let retrievedItem = try await keychainStorage.get()
        XCTAssertEqual(retrievedItem, item)
    }

    func testDeleteItem() async throws {
        let item = TestItem(id: 1, name: "Test")
        try await keychainStorage.save(item: item)
        try await keychainStorage.delete()
        let retrievedItem = try await keychainStorage.get()
        XCTAssertNil(retrievedItem)
    }
}
