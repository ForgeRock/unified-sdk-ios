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
open class FieldCollector: Collector {
    public var key: String = ""
    public var label: String = ""
    public var value: String = ""
    public let id = UUID()
    
    public init() {}
    
    required public init(with json: [String: Any]) {
        key = json[Constants.key] as? String ?? ""
        label = json[Constants.label] as? String ?? ""
    }
}
