//
//  PingLoggerTests.swift
//  PingLoggerTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingLogger

final class PingLoggerTests: XCTestCase {

  func testLoggerSetAndGet() {
    let noneLogger = NoneLogger()
    LogManager.logger = noneLogger
    XCTAssert(LogManager.logger is NoneLogger)

    let standardLogger = StandardLogger()
    LogManager.logger = standardLogger
    XCTAssert(LogManager.logger is StandardLogger)

    let warningLogger = WarningLogger()
    LogManager.logger = warningLogger
    XCTAssert(LogManager.logger is WarningLogger)
  }


  func testDefaultLoggers() {
    let noneLogger = LogManager.none
    XCTAssert(noneLogger is NoneLogger)

    let standardLogger = LogManager.standard
    XCTAssert(standardLogger is StandardLogger)

    let warningLogger = LogManager.warning
    XCTAssert(warningLogger is WarningLogger)
  }


  func testCustomLogger() {
    var customLogger = LogManager.customLogger
    XCTAssert(customLogger is CustomLogger)

    customLogger = CustomLogger()
    LogManager.logger = customLogger
    XCTAssert(LogManager.logger is CustomLogger)
  }

}

struct CustomLogger: Logger {

  func i(_ message: String) {
  }

  func d(_ message: String) {
  }

  func w(_ message: String, error: Error?) {
    if let error = error {
      print("\(message): \(error)")
    } else {
      print(message)
    }
  }

  func e(_ message: String, error: Error?) {
    if let error = error {
      print("\(message): \(error)")
    } else {
      print(message)
    }
  }
}

extension LogManager {
  static var customLogger: Logger {
    return CustomLogger()
  }
}
