//
//  StandardLogger.swift
//  PingLogger
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import os.log

/// Stadard Logger to go to the iOS Console
public class StandardLogger: Logger {
  /// SDK Version to be updated with each release
  private let sdkVersion = "Ping SDK 0.9.0"
  var log: OSLog
  
  /// Initializer for StandardLogger
  /// - Parameter log: Optional OSLog. Default: subsystem: "com.pingidentity.ios", category: "Standard"
  public init (log: OSLog? = nil) {
    self.log = log ?? OSLog(subsystem: "com.pingidentity.ios", category: "Standard")
  }
  
  /// Logs a debug message.
  /// - Parameter message: The debug message to be logged.
  public func d(_ message: String) {
    logMessage(message, log: log, type: .debug, error: nil)
  }

  /// Logs an informational message.
  /// - Parameter message: The message to be logged.
  public func i(_ message: String) {
    logMessage(message, log: log, type: .info, error: nil)
  }

  /// Logs a warning message.
  /// - Parameters:
  ///   - message: The warning message to be logged.
  ///   - error: Optional Error associated with the warning.
  public func w(_ message: String, error: Error?) {
    logMessage(message, log: log, type: .error, error: error)
  }
  
  /// Logs an error message.
  /// - Parameters:
  ///   - message: The error message to be logged.
  ///   - error: Optional Error associated with the warning.
  public func e(_ message: String, error: Error?) {
    logMessage(message, log: log, type: .fault, error: error)
  }
  
  private func logMessage(_ message: String, log: OSLog = .default, type: OSLogType = .default, error: Error? = nil) {
    let errorMessage = (error == nil ? "" : ", Error: \(error!.localizedDescription)")
    os_log("%{public}@", log: log, type: type, "[\(sdkVersion)] \(message)\(errorMessage)")
  }
}

public class WarningLogger: StandardLogger {
  public override func d(_ message: String) { }

  public override func i(_ message: String) { }
}

extension LogManager {
  /// Static logger of `StandardLogger` type
  public static var standard: Logger { return StandardLogger() }
  /// Static logger of `StandardWarningLogger` type
  public static var warning: Logger { return WarningLogger()
  }
}
