//
//  NoneLogger.swift
//  PingLogger
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// The None class is an implementation of the Logger interface that performs no operations.
/// This can be used as a default or placeholder logger.
public class NoneLogger: Logger {
  /// Logs a debug message.
  /// - Parameter message: The debug message to be logged.
  public func d(_ message: String) {}

  /// Logs an informational message.
  /// - Parameter message: The message to be logged.
  public func i(_ message: String) {}

  /// Logs a warning message.
  /// - Parameters:
  ///   - message: The warning message to be logged.
  ///   - error: Optional Error associated with the warning.
  public func w(_ message: String, error: Error?) {}

  /// Logs an error message.
  /// - Parameters:
  ///   - message: The error message to be logged.
  ///   - error: Optional Error associated with the warning.
  public func e(_ message: String, error: Error?) {}
}

extension LogManager {
  /// Staic logger of `NoneLogger` type
  public static var none: Logger { return NoneLogger() }
}
