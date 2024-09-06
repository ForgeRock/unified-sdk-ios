//
//  MemoryStorage.swift
//  PingStorage
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// A storage for storing objects in memory, where `T` is he type of the object to be stored.
public class Memory<T: Codable>: Storage {
  private var data: T?
  
  /// Saves the given item in memory.
  /// - Parameter item: The item to save.
  public func save(item: T) async throws {
    data = item
  }
  
  /// Retrieves the item from memory.
  /// - Returns: The item if it exists, null otherwise.
  public func get() async throws -> T?  {
    return data
  }
  
  /// Deletes the item from memory.
  public func delete() async throws {
    data = nil
  }

}

/// `MemoryStorage` provides an in-memory storage solution for objects of type `T`.
/// It conforms to the `StorageDelegate` protocol, enabling it to interact seamlessly with other components expecting a storage delegate.
/// This class is ideal for temporary storage where persistence across app launches is not required.
///
/// The generic type `T` must conform to `Codable` to ensure that objects can be encoded and decoded when written to and read from memory, respectively.
///
/// - Parameter T: The type of the objects to be stored. Must conform to `Codable`.
public class MemoryStorage<T: Codable>: StorageDelegate<T> {
  /// Initializes a new instance of `MemoryStorage`.
  ///
  /// This initializer creates a `MemoryStorage` instance that acts as a delegate for an in-memory storage
  /// mechanism. It allows for the optional caching of data based on the `cacheable` parameter.
  ///
  /// - Parameter cacheable: A Boolean value indicating whether the stored data should be cached. Defaults to `false`,
  ///                        which means that caching is not enabled by default. When set to `true`, it enables caching
  ///                        based on the implementation details of the `Memory<T>` storage strategy.
  public init(cacheable: Bool = false) {
    super.init(delegate: Memory<T>(), cacheable: cacheable)
  }
}
