//
//  Logger.swift
//  PingLogger
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// Logger protocol that provides methods for logging different levels of information.
public protocol Logger {
  /// Logs a debug message.
  /// - Parameter message: The debug message to be logged.
  func d(_ message: String)

  /// Logs an informational message.
  /// - Parameter message: The message to be logged.
  func i(_ message: String)

  /// Logs a warning message.
  /// - Parameters:
  ///   - message: The warning message to be logged.
  ///   - error: Optional Error associated with the warning.
  func w(_ message: String, error: Error?)
  
  /// Logs an error message.
  /// - Parameters:
  ///   - message: The error message to be logged.
  ///   - error: Optional Error associated with the warning.
  func e(_ message: String, error: Error?)
}

///LogManager to access the global logger instances
public struct LogManager {
  private static var shared: Logger = NoneLogger()

  ///Global logger instance. If no logger is set, it defaults to Logger.None.
  public static var logger: Logger {
    get { shared }
    set { shared = newValue }
  }
}
