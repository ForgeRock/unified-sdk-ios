//
//  CollectorFactory.swift
//  PingDavinci
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import PingOrchestrate

/// The CollectorFactory singleton is responsible for creating and managing Collector instances.
/// It maintains a dictionary of collector creation functions, keyed by type.
/// It also provides functions to register new types of collectors and to create collectors from a JSON array.
final class CollectorFactory {
    // A dictionary to hold the collector creation functions.
    public var collectors: [String: any Collector.Type] = [:]
    
    public static let shared = CollectorFactory()
    
    init() {
        register(type: Constants.TEXT, collector: TextCollector.self)
        register(type: Constants.PASSWORD, collector: PasswordCollector.self)
        register(type: Constants.SUBMIT_BUTTON, collector: SubmitCollector.self)
        register(type: Constants.FLOW_BUTTON, collector:  FlowCollector.self)
    }
    
    /// Registers a new type of Collector.
    /// - Parameters:
    ///   - type:  The type of the Collector.
    ///   - block: A function    that creates a new instance of the Collector.
    public func register(type: String, collector: any Collector.Type) {
        collectors[type] = collector
    }
    
    /// Creates a list of Collector instances from an array of dictionaries.
    /// Each dictionary should have a "type" field that matches a registered Collector type.
    /// - Parameter array: The array of dictionaries to create the Collectors from.
    /// - Returns: A list of Collector instances.
    func collector(from array: [[String: Any]]) -> Collectors {
        var list: [any Collector] = []
        for item in array {
            if let type = item[Constants.type] as? String, let collectorType = collectors[type] {
                list.append(collectorType.init(with: item))
            }
        }
        return list
    }
    
    func reset() {
        collectors.removeAll()
    }
}
