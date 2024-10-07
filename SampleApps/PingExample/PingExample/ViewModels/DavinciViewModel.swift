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
        //TODO: Integration Point. STEP 3
        /*
         When the application is ready to start the Davinci flow, the SDK `start()` method needs to be called.
         In this Sample app we have created a reference to the DaVinci Object inside the `ConfigurationManager` singleton class.
         From any place in the app you can access this, by calling `ConfigurationManager.shared.davinci`.
         Use the this reference and an `async/await` pattern to start the flow and receive the first node/connector.
         
         Starting a DaVinci flow, will return a Connector object. This will be assigned to a Published property of type: `StateNode`.
         This will be consumed automatically, as this class is an `ObservableObject` from the DavinciView struct, that acts as the Flow view.
         
         Each connector can be either a `SuccessNode` or a `FailureNode` or an `ErrorNode` or finally a `Connector`.
         A `Connector` contains the `collectors` array that is the `Inputs` and `Outputs` that developers need to present to collect the user inputs for the flow.
         Notice that in order to move to the next connect in the flow we need to call `connector.next()`.
         
         Example: let node = await ConfigurationManager.shared.davinci?.start()
         */
        
        
        if let connector = node as? Connector {
            let node = await connector.next() // <-- In the first step, calls DaVinci and starts the flow. On next steps, submits and returns the next `Connector`.
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
            //TODO: Integration Point. STEP 4
            /*
             At this point the application is ready to submit the Node/Connector and receive the "next step".
             To submit the data call `connector.next()`
             
             Example:
             let next = await connector.next()
             */
           
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
