//
//  StorageDelegate.swift
//  PingStorage
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// A storage dlegate class that delegates its operations to a storage.
/// It can optionally cache the stored item in memory.
/// This class is designed to be subclassed by specific storage strategies (e.g., keychain, in-memory) that conform to the `Storage` protocol.
///
/// - Parameter T: The type of the objects being stored. Must conform to `Codable` to ensure that
///                objects can be easily encoded and decoded.
open class StorageDelegate<T: Codable>: Storage {
  private let delegate: any Storage<T>
  private let cacheable: Bool
  private var cached: T?
  private let queue = DispatchQueue(label: "com.ping.storage.queue")
  
  /// Initializer for StorageDelegate
  /// - Parameters:
  ///   - delegate: The storage to delegate the operations to.
  ///   - cacheable: Whether the storage dleegate should cache the object in memory.
  public init(delegate: any Storage<T>, cacheable: Bool = false) {
    self.delegate = delegate
    self.cacheable = cacheable
  }
  
  /// Saves the given item in the storage and optionally in memory.
  /// - Parameter item: The item to save.
  public func save(item: T) async throws {
    try await withCheckedThrowingContinuation { continuation in
      queue.async {
        Task {
          do {
            try await self.delegate.save(item: item)
            if self.cacheable {
              self.cached = item
            }
            continuation.resume()
          } catch {
            continuation.resume(throwing: error)
          }
        }
      }
    }
  }
  
  /// Retrieves the item from memory if it's cached, otherwise from the storage.
  /// - Returns: The item if it exists, null otherwise.
  public func get() async throws -> T? {
    try await withCheckedThrowingContinuation { continuation in
      queue.async {
        Task {
          do {
            if let cached = self.cached {
              continuation.resume(returning: cached)
            } else {
              let item = try await self.delegate.get()
              continuation.resume(returning: item)
            }
          } catch {
            continuation.resume(throwing: error)
          }
        }
      }
    }
  }
  
  /// Deletes the item from the storage and removes it from memory if it's cached.
  public func delete() async throws {
    try await withCheckedThrowingContinuation { continuation in
      queue.async {
        Task {
          do {
            try await self.delegate.delete()
            if self.cacheable {
              self.cached = nil
            }
            continuation.resume()
          } catch {
            continuation.resume(throwing: error)
          }
        }
      }
    }
  }
}
