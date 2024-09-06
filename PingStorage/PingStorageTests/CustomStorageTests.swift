//
//  CustomStorageTests.swift
//  PingStorageTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingStorage

final class CustomStorageTests: XCTestCase {

  private var customStorage: CustomStorageDelegate<TestItem>!

  override func setUp() {
      super.setUp()
      customStorage = CustomStorageDelegate()
  }

  override func tearDown() {
      customStorage = nil
      super.tearDown()
  }

  func testSaveItem() async throws {
      let item = TestItem(id: 1, name: "Test")
      try await customStorage.save(item: item)
      let retrievedItem = try await customStorage.get()
      XCTAssertEqual(retrievedItem, item)
  }

  func testGetItem() async throws {
      let item = TestItem(id: 1, name: "Test")
      try await customStorage.save(item: item)
      let retrievedItem = try await customStorage.get()
      XCTAssertEqual(retrievedItem, item)
  }

  func testDeleteItem() async throws {
      let item = TestItem(id: 1, name: "Test")
      try await customStorage.save(item: item)
      try await customStorage.delete()
      let retrievedItem = try await customStorage.get()
      XCTAssertNil(retrievedItem)
  }

}

public class CustomStorage<T: Codable>: Storage {
  private var data: T?

  public func save(item: T) async throws {
    data = item
  }

  public func get() async throws -> T?  {
    return data
  }

  public func delete() async throws {
    data = nil
  }

}

public class CustomStorageDelegate<T: Codable>: StorageDelegate<T> {
  public init(cacheable: Bool = false) {
    super.init(delegate: CustomStorage<T>(), cacheable: cacheable)
  }
}
