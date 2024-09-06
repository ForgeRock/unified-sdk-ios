//
//  Storage.swift
//  PingStorage
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// Protocol to persist and retrieve `Codable` instanse.
public protocol Storage<T> {
    associatedtype T: Codable

    func save(item: T) async throws
    func get() async throws -> T?
    func delete() async throws
}
