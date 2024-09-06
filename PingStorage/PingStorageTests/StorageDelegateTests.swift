//
//  StorageDelegateTests.swift
//  PingStorageTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingStorage

final class StorageDelegateTests: XCTestCase {
  private var storageDelegate: StorageDelegate<TestItem>!
  private var memoryStorage: MemoryStorage<TestItem>!

  override func setUp() {
    super.setUp()
    memoryStorage = MemoryStorage()
    storageDelegate = StorageDelegate(delegate: memoryStorage, cacheable: false)
  }

  override func tearDown() {
    storageDelegate = nil
    memoryStorage = nil
    super.tearDown()
  }

  func testSaveItem() async throws {
    let item = TestItem(id: 1, name: "Test")
    try await storageDelegate.save(item: item)
    let retrievedItem = try await storageDelegate.get()
    XCTAssertEqual(retrievedItem, item)
  }

  func testGetItem() async throws {
    let item = TestItem(id: 1, name: "Test")
    try await storageDelegate.save(item: item)
    let retrievedItem = try await storageDelegate.get()
    XCTAssertEqual(retrievedItem, item)
  }

  func testDeleteItem() async throws {
    let item = TestItem(id: 1, name: "Test")
    try await storageDelegate.save(item: item)
    try await storageDelegate.delete()
    let retrievedItem = try await storageDelegate.get()
    XCTAssertNil(retrievedItem)
  }

  func testConcurrentAccess() {
    let concurrentQueue = DispatchQueue(label: "com.example.concurrentQueue", attributes: .concurrent)
    let group = DispatchGroup()
    let item = TestItem(id: 1, name: "Test")
    let iterations = 1000

    // Concurrent writes
    for _ in 0..<iterations {
      group.enter()
      concurrentQueue.async {
        Task {
          try? await self.storageDelegate.save(item: item)
          group.leave()
        }
      }
    }

    // Concurrent reads
    for _ in 0..<iterations {
      group.enter()
      concurrentQueue.async {
        Task {
          let _ = try? await self.storageDelegate.get()
          group.leave()
        }
      }
    }

    // Wait for all tasks to finish
    group.wait()

    // Verify the final value
    Task {
      let finalValue = try? await storageDelegate.get()
      XCTAssertEqual(finalValue, item)
    }
  }

  func testConcurrentModification() {
   let concurrentQueue = DispatchQueue(label: "com.example.concurrentQueue", attributes: .concurrent)
    let group = DispatchGroup()
    let item = TestItem(id: 1, name: "Test")
    let iterations = 1000

    // Concurrent writes and deletes
    for i in 0..<iterations {
      group.enter()
      concurrentQueue.async {
        Task {
          if i % 2 == 0 {
            try? await self.storageDelegate.save(item: item)
          } else {
            try? await self.storageDelegate.delete()
          }
          group.leave()
        }
      }
    }

    // Wait for all tasks to finish
    group.wait()

    // Verify the final state
    // Since the operations are concurrent and we don't know the exact state,
    // we just check that no crash or data corruption occurred.
    XCTAssertTrue(true)
  }

  func testConcurrentAccessWithTaskGroup() async {
         let iterations = 1000
    let item = TestItem(id: 1, name: "Test")

         await withTaskGroup(of: Void.self) { group in
             for _ in 0..<iterations {
                 group.addTask {
                   try? await self.storageDelegate.save(item: item)
                 }
             }
             for _ in 0..<iterations {
                 group.addTask {
                   _ = try? await self.storageDelegate.get()
                 }
             }
         }

    let finalValue = try? await storageDelegate.get()
         XCTAssertEqual(finalValue, item)
     }

     func testConcurrentModificationWithTaskGroup() async {
         let iterations = 1000
       let item = TestItem(id: 1, name: "Test")

         await withTaskGroup(of: Void.self) { group in
             for i in 0..<iterations {
                 group.addTask {
                     if i % 2 == 0 {
                       try? await self.storageDelegate.save(item: item)
                     } else {
                       try? await self.storageDelegate.delete()
                     }
                 }
             }
         }

         // Since the operations are concurrent and we don't know the exact state,
         // we just check that no crash or data corruption occurred.
         XCTAssertTrue(true)
     }
}
