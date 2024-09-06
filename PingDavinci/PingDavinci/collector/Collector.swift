//
//  FlowCollector.swift
//  PingDavinci
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.


import PingOrchestrate

/// Protocol representing a Collector.
public protocol Collector: Action, Identifiable {
    var id: UUID { get }
    init(with json: [String: Any])
}

extension Connector {
    public var collectors: [any Collector] {
        return actions.compactMap { $0 as? (any Collector) }
    }
}

///  Type alias for a list of collectors.
public typealias Collectors = [any Collector]

extension Collectors {
    /// Finds the event type from a list of collectors.
    ///This function iterates over the list of collectors and returns the value if the collector's value is not empty.
    /// - Returns:  The event type as a String if found, otherwise nil.
    func eventType() -> String? {
        for collector in self {
            if let submitCollector = collector as? SubmitCollector, !submitCollector.value.isEmpty {
                return submitCollector.value
            }
            if let flowCollector = collector as? FlowCollector, !flowCollector.value.isEmpty {
                return flowCollector.value
            }
        }
        return nil
    }
    
    /// Represents a list of collectors as a JSON object for posting to the server.
    /// This function takes a list of collectors and represents it as a JSON object. It iterates over the list of collectors,
    /// adding each collector's key and value to the JSON object if the collector's value is not empty.
    /// - Returns: JSON object representing the list of collectors.
    func asJson() -> [String: Any] {
        var jsonObject: [String: Any] = [:]
        
        for collector in self {
            if let submitCollector = collector as? SubmitCollector, !submitCollector.value.isEmpty {
                jsonObject[Constants.actionKey] = submitCollector.key
            }
            if let flowCollector = collector as? FlowCollector, !flowCollector.value.isEmpty {
                jsonObject[Constants.actionKey] = flowCollector.key
            }
        }
        
        var formData: [String: Any] = [:]
        for collector in self {
            if let textCollector = collector as? TextCollector, !textCollector.value.isEmpty {
                formData[textCollector.key] = textCollector.value
            }
            if let passwordCollector = collector as? PasswordCollector, !passwordCollector.value.isEmpty {
                formData[passwordCollector.key] = passwordCollector.value
            }
        }
        
        jsonObject[Constants.formData] = formData
        return jsonObject
    }
}
