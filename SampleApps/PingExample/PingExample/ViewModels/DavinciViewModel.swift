//
//  DavinciViewModel.swift
//  PingExample
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingDavinci
import PingOidc
import PingOrchestrate

class DavinciViewModel: ObservableObject {
    
    @Published public var data: StateNode = StateNode()
    
    @Published public var isLoading: Bool = false
    
    init() {
        Task {
            await startDavinci()
        }
    }
    
    private func startDavinci() async {
        
        await MainActor.run {
            isLoading = true
        }
        let node = await ConfigurationManager.shared.davinci?.start()
        
        if let connector = node as? Connector {
            let node = await connector.next()
            await MainActor.run {
                self.data = StateNode(currentNode: node, previousNode: node)
            }
        } else {
            await MainActor.run {
                self.data = StateNode(currentNode: node, previousNode: node)
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
        
    }
    
    public func next(node: Node) async {
        await MainActor.run {
            isLoading = true
        }
        if let connector = node as? Connector {
            let next = await connector.next()
            await MainActor.run {
                self.data = StateNode(currentNode: next, previousNode: node)
                isLoading = false
            }
        }
    }
}

class StateNode {
    var currentNode: Node? = nil
    var previousNode: Node? = nil
    
    init(currentNode: Node?  = nil, previousNode: Node? = nil) {
        self.currentNode = currentNode
        self.previousNode = previousNode
    }
}
