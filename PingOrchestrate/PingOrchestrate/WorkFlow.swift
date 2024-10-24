//
//  Workflow.swift
//  PingOrchestrate
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingLogger

/// Class representing the context of a flow.
/// - property flowContext: The shared context of the flow.
public class FlowContext {
    public let flowContext: SharedContext
    
    public init(flowContext: SharedContext) {
        self.flowContext = flowContext
    }
}

extension Workflow {
    /// Creates a new Workflow instance with the provided configuration block.
    /// - Parameter block: The configuration block for the Workflow.
    /// - Returns: A new Workflow instance.
    public static func createWorkflow(_ block: (WorkflowConfig) -> Void = { _ in }) -> Workflow {
        let config = WorkflowConfig()
        block(config)
        return Workflow(config: config)
    }
}

public enum ModuleKeys: String {
    case customHeader = "customHeader"
    case nosession = "nosession"
    case forceAuth = "forceAuth"
}

/// Class representing a workflow.
public class Workflow: @unchecked Sendable {
    /// The configuration for the workflow.
    public let config: WorkflowConfig
    ///  Global SharedContext
    public let sharedContext = SharedContext()
    
    private var started = false
    
    internal var initHandlers =  [() async throws -> Void]()
    internal var startHandlers = [(FlowContext, Request) async throws -> Request]()
    internal var nextHandlers = [(FlowContext, ContinueNode, Request) async throws -> Request]()
    internal var responseHandlers = [(FlowContext, Response) async throws -> Void]()
    internal var nodeHandlers = [(FlowContext, Node) async throws -> Node]()
    internal var successHandlers = [(FlowContext, SuccessNode) async throws -> SuccessNode]()
    internal var signOffHandlers = [(Request) async throws -> Request]()
    // Transform response to Node, we can only have one transform
    internal var transformHandler: (FlowContext, Response) async throws -> Node = { _, _ in EmptyNode() }
    
    ///  Initializes the workflow.
    /// - Parameter config: The configuration for the workflow.
    public init(config: WorkflowConfig) {
        self.config = config
        self.config.register(workflow: self)
    }
    
  /// Initializes the workflow.
  public func initialize() async throws {
    if !started {
      for handler in initHandlers {
          try await handler()
        }
      started = true
    }
  }
  
    /// Starts the workflow with the provided request.
    /// - Parameter request: The request to start the workflow with.
    /// - Returns: The resulting Node after processing the workflow.
    private func start(request: Request) async throws -> Node {
        // Before we start, make sure all the module init has been completed
        try await initialize()
        config.logger.i("Starting...")
        let context = FlowContext(flowContext: SharedContext())
        var currentRequest = request
        for handler in startHandlers {
            currentRequest = try await handler(context, currentRequest)
        }
        let response = try await send(context, request: currentRequest)
        
        let transform = try await transformHandler(context, response)
        
        var initialNode = transform
        for handler in nodeHandlers {
            initialNode = try await handler(context, initialNode)
        }
        
        return try await next(context, initialNode)
    }
    
    /// Starts the workflow with a default request.
    /// - Returns: The resulting Node after processing the workflow.
    public func start() async -> Node {
        do {
            return try await start(request: Request())
        }
        catch {
          return FailureNode(cause: error)
        }
    }
    
    /// Sends a request and returns the response.
    /// - Parameters:
    ///   - context: The context of the flow.
    ///   - request: The request to be sent.
    /// - Returns: The response received.
    private func send(_ context: FlowContext, request: Request) async throws -> Response {
        let (data, urlResponse) = try await config.httpClient.sendRequest(request: request)
        let response = Response(data: data, response: urlResponse)
        for handler in responseHandlers {
            try await handler(context, response)
        }
        return response
    }
    
    /// Sends a request and returns the response.
    /// - Parameter request: The request to be sent.
    /// - Returns: The response received.
    private func send(_ request: Request) async throws -> Response {
        // semaphore
        let (data, urlResponse) = try await config.httpClient.sendRequest(request: request)
        return Response(data: data, response: urlResponse)
    }
    
    /// Processes the next node if it is a success node.
    /// - Parameters:
    ///   - context: The context of the flow.
    ///   - node: The current node.
    /// - Returns: The resulting Node after processing the next step.
    private func next(_ context: FlowContext, _ node: Node) async throws -> Node {
        if let success = node as? SuccessNode {
            var result = success
            for handler in successHandlers {
                result = try await handler(context, result)
            }
            return result
        } else {
            return node
        }
    }
    
    /// Processes the next node in the workflow.
    /// - Parameters:
    ///   - context: The context of the flow.
    ///   - current: The current ContinueNode.
    /// - Returns: The resulting Node after processing the next step.
    public func next(_ context: FlowContext, _ current: ContinueNode) async -> Node {
        do {
            config.logger.i("Next...")
            let initialRequest = current.asRequest()
            var request = initialRequest
            for handler in nextHandlers {
                request = try await handler(context, current, request)
            }
            current.close()
            let initialNode = try await transformHandler(context, try await send(context, request: request))
            var node = initialNode
            for handler in nodeHandlers {
                node = try await handler(context, node)
            }
            return try await next(context, node)
        }
        catch {
          return FailureNode(cause: error)
        }
    }
    
    /// Signs off the workflow.
    /// - Returns: A Result indicating the success or failure of the sign off.
    public func signOff() async -> Result<Void, Error> {
        self.config.logger.i("SignOff...")
        do {
            try await initialize()
            var request = Request()
            for handler in signOffHandlers {
                request = try await handler(request)
            }
            _ = try await send(request)
            return .success(())
        }
        catch {
            config.logger.e("Error during sign off", error: error)
            return .failure(error)
        }
    }
    
    /// Processes the response.
    /// - Parameters:
    ///   - context: The context of the flow.
    ///   - response: The response to be processed.
    private func response(context: FlowContext, response: Response) async throws {
        for handler in responseHandlers {
            try await handler(context, response)
        }
    }
}
