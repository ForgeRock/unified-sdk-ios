//
//  MockStorage.swift
//  PingOidcTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingStorage

public class Mock<T: Codable>: Storage {
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

public class MockStorage<T: Codable>: StorageDelegate<T> {
    public init(cacheable: Bool = false) {
        super.init(delegate: Mock<T>(), cacheable: cacheable)
    }
}

