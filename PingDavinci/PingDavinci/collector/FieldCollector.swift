//
//  FieldCollector.swift
//  PingDavinci
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation


/// Abstract class representing a field collector.
/// - property key: The key of the field collector.
/// - property label The label of the field collector.
/// - property value The value of the field collector. It's open for modification.
open class FieldCollector: Collector, @unchecked Sendable {
    
    // Private queue for thread-safe access
    private let syncQueue = DispatchQueue(label: "com.fieldCollector.syncQueue", attributes: .concurrent)
    
    // Private backing properties to store data
    private var _key: String = ""
    private var _label: String = ""
    private var _value: String = ""
    
    // Public computed properties for thread-safe access
    public var key: String {
        get {
            return syncQueue.sync { _key }
        }
        set {
            syncQueue.async(flags: .barrier) { self._key = newValue }
        }
    }
    
    public var label: String {
        get {
            return syncQueue.sync { _label }
        }
        set {
            syncQueue.async(flags: .barrier) { self._label = newValue }
        }
    }
    
    public var value: String {
        get {
            return syncQueue.sync { _value }
        }
        set {
            syncQueue.async(flags: .barrier) { self._value = newValue }
        }
    }
    
    public let id = UUID()
    
    // Default initializer
    public init() {}
    
    // Initializer with a JSON field
    required public init(with json: Field) {
        syncQueue.async(flags: .barrier) {
            self._key = json.key
            self._label = json.label
        }
    }
}
