//
//  ModuleTests.swift
//  PingOrchestrateTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingOrchestrate

final class ModuleTests: XCTestCase {
    
    func testModule() async throws {
        
        class CustomHeaderConfig: Equatable {
            var enable = true
            var headerValue = "iOS-SDK"
            var headerName = "header-name"
            
            static func == (lhs: CustomHeaderConfig, rhs: CustomHeaderConfig) -> Bool {
                return lhs.enable == rhs.enable && lhs.headerValue == rhs.headerValue && lhs.headerName == rhs.headerName
            }
        }
        
        func headerconfig<T: CustomHeaderConfig>(setup: Setup<T>) {
            let config = setup.config
            setup.next { (context, _, request) in
                if config.enable {
                    request.header(name: config.headerName, value: config.headerValue)
                }
                return request
            }
        }
        
        let block = { CustomHeaderConfig() }
        let module = Module.of(block, setup: headerconfig)
        
        XCTAssertNotNil(module.config)
        XCTAssertNotNil(module.setup)
        
    }
}
