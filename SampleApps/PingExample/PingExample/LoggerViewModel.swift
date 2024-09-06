//
//  LoggerViewModel.swift
//  PingExample
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingLogger

class LoggerViewModel {

    func setupLogger() {


      var logger = LogManager.logger
      logger.d("Debug")
      logger.i("Info")
      logger.w("Warning", error: TestError.success)
      logger.e("Error", error: TestError.failure)

      logger = LogManager.standard
      logger.d("Debug")
      logger.i("Test log")
      logger.w("Warning", error: TestError.success)
      logger.e("Error", error: TestError.failure)

      logger = LogManager.warning
      logger.d("Debug")
      logger.i("Test log")
      logger.w("Warning", error: TestError.success)
      logger.e("Error", error: TestError.failure)

    }

  enum TestError: Error {
    case success
    case failure
  }

}
