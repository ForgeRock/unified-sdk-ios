//
//  ModuleRegistry.swift
//  PingOrchestrate
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

public protocol ModuleRegistryProtocol<Config> {
    associatedtype Config: Any
    var id: UUID { get set }
    var priority: Int { get }
    var config: Config { get }
    var setup: (Setup<Config>) -> (Void) { get }
    
    func register(workflow: Workflow)
}

/// Class for a ModuleRegistry. A ModuleRegistry represents a registry of modules in the application.
///  - property id: The UUID of the module
///  - property priority: The priority of the module in the registry.
///  - property config: The configuration for the module.
///  - property setup: The function that sets up the module.
public final class ModuleRegistry<Config>: ModuleRegistryProtocol {
    public var id: UUID = UUID()
    public let priority: Int
    public let config: Config
    public let setup: (Setup<Config>) -> Void
    
    public init(setup: @escaping (Setup<Config>) -> (Void),
                priority: Int,
                id: UUID,
                config: Config) {
        self.id = id
        self.priority = priority
        self.config = config
        self.setup = setup
    }
    
    /// Registers the module to the workflow.
    /// - parameter workflow: The workflow to which the module is registered.
    public func register(workflow: Workflow) {
        let setupInstance = Setup<Config>(workflow: workflow, config: config)
        setup(setupInstance)
    }
}

extension ModuleRegistry: Comparable {
    public static func < (lhs: ModuleRegistry, rhs: ModuleRegistry) -> Bool {
        return lhs.priority < rhs.priority
    }
    
    public static func == (lhs: ModuleRegistry, rhs: ModuleRegistry) -> Bool {
        return lhs.priority == rhs.priority
    }
}

