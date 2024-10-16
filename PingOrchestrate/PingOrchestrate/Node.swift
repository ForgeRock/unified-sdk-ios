//
//  Node.swift
//  PingOrchestrate
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


/// Protocol for actions
public protocol Action {}

/// Protocol for closeable resources
public protocol Closeable {
  func close()
}

/// Protocol for Node. Represents a node in the workflow.
public protocol Node {}

/// Represents an EmptyNode node in the workflow.
public struct EmptyNode: Node {
  public init() {}
}

/// Represents an Failure node in the workflow.
/// - property cause: The cause of the error.
public struct FailureNode: Node {
  public init(cause: any Error) {
    self.cause = cause
  }
  
  public let cause: Error
}

/// Represents a ErrorNode node in the workflow.
/// - property status: The status of the error.
/// - property input: The input for the error.
/// - property message: The message for the error.
public struct ErrorNode: Node {
  public init(status: Int? = nil,
              input: [String : Any] = [:],
              message: String = "") {
    self.input = input
    self.message = message
    self.status = status
  }
  
  public let input: [String: Any]
  public let message: String
  public let status: Int?
}

/// Represents a success node in the workflow.
/// - property input: The input for the success.
/// - property session: The session for the success.
public struct SuccessNode: Node {
  public let input: [String: Any]
  public let session: Session
  
  public init(input: [String : Any] = [:], session: Session) {
    self.session = session
    self.input = input
  }
}

/// Abstract class for a ContinueNode node in the workflow.
/// - property context: The context for the node.
/// - property workflow: The workflow for the node.
/// - property input: The input for the node.
/// - property actions: The actions for the node.
open class ContinueNode: Node, Closeable {
  public let context: FlowContext
  public let workflow: Workflow
  public let input: [String: Any]
  public let actions: [any Action]
  
  public init(context: FlowContext, workflow: Workflow, input: [String: Any], actions: [any Action]) {
    self.context = context
    self.workflow = workflow
    self.input = input
    self.actions = actions
  }
  
  open func asRequest() -> Request {
    fatalError("Must be overridden in subclass")
  }
  
  public func next() async -> Node {
    return await workflow.next(context, self)
  }
  
  public func close() {
    actions.compactMap { $0 as? Closeable }.forEach { $0.close() }
  }
}

/// Protocol for a Session. A Session represents a user's session in the application.
public protocol Session {
  /// Returns the value of the session as a String.
  func value() -> String
}


/// Singleton for an EmptySession. An EmptySession represents a session with no value.
public struct EmptySession: Session {
  public init() {}
  
  /// The value of the empty session as a String.
  public func value() -> String {
    return ""
  }
}
