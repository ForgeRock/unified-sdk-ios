//
//  PingOrchestrateTests.swift
//  PingOrchestrateTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.

//
//import Testing
//
//@testable import PingOrchestrate
//
//struct PingOrchestrateTests {
//  
//  @Test func testWorkFlowOverridable() async throws {
//    
//    class CustomHeaderConfig {
//      var enable = true
//      var headerValue = "iOS-SDK"
//      var headerName = "header-name"
//    }
//    
//    let customHeader = Module.of({ CustomHeaderConfig() }, block: { setup in
//      let config = setup.config
//      setup.next { ( context, _, request) in
//        if config.enable {
//          request.header(name: config.headerName, value: config.headerValue)
//        }
//        return request
//      }
//      
//      setup.start { ( context, request) in
//        if config.enable {
//          request.header(name: config.headerName, value: config.headerValue)
//        }
//        return request
//      }
//      
//    })
//    
//    
//    let nosession = Module.of { setup in
//      setup.next { ( context,_, request) in
//        request.header(name: "nosession", value: "true")
//        return request
//      }
//    }
//    
//    
//    let forceAuth = Module.of { setup in
//      setup.start { ( context, request) in
//        request.header(name: "forceAuth", value: "true")
//        return request
//      }
//    }
//    
//    let workFlow = Workflow.config { config in
//      config.debug = true
//      config.timeout = 10
//      
//      config.module(customHeader) { header in
//        header.headerName = "header-name2"
//        header.headerValue = "iOS-SDK"
//      }
//      
//      config.module(customHeader) { header in
//        header.headerName = "header-name1"
//        header.headerValue = "Android-SDK"
//      }
//      
//      config.module(forceAuth)
//      config.module(nosession)
//      
//    }
//    
//    #expect(workFlow.workFlowConfig.modules.count == 3)
//  
//    
//  }
//  
//  @Test("This validates customer can be overridate later") func testWorkFlowOverridable1() async throws {
//    
//    class CustomHeaderConfig {
//      var enable = true
//      var headerValue = "iOS-SDK"
//      var headerName = "header-name"
//    }
//    
//    let customHeader = Module.of({ CustomHeaderConfig() }, block: { setup in
//      let config = setup.config
//      setup.next { ( context,_, request) in
//        if config.enable {
//          request.header(name: config.headerName, value: config.headerValue)
//        }
//        return request
//      }
//      
//      setup.start { ( context, request) in
//        if config.enable {
//          request.header(name: config.headerName, value: config.headerValue)
//        }
//        return request
//      }
//      
//    })
//    
//    
//    let nosession = Module.of { setup in
//      setup.next { ( context, _, request) in
//        request.header(name: "nosession", value: "true")
//        return request
//      }
//    }
//    
//    
//    let forceAuth = Module.of{ setup in
//      setup.start { ( context, request) in
//        request.header(name: "forceAuth", value: "true")
//        return request
//      }
//    }
//    
//    let workFlow = Workflow.config { config in
//      config.debug = true
//      config.timeout = 10
//      
//      config.module(customHeader, mode: OverrideMode.append) { header in
//        header.enable = true
//        header.headerName = "header-name1"
//        header.headerValue = "Android-SDK1"
//      }
//      
//      config.module(customHeader) { header in
//        header.enable = true
//        header.headerName = "header-name2"
//        header.headerValue = "Android-SDK2"
//      }
//      
//      config.module(customHeader, mode: OverrideMode.append) { header in
//        header.enable = true
//        header.headerName = "header-name3"
//        header.headerValue = "iOS-SDK3"
//      }
//      
//      
//      config.module(customHeader) { header in
//        header.enable = true
//        header.headerName = "header-name4"
//        header.headerValue = "Android-SDK4"
//      }
//      
//
//      config.module(forceAuth)
//      config.module(nosession)
//      
//    }
//    
//    try #require(workFlow.workFlowConfig.modules.count > 0)
//    
//    #expect(workFlow.workFlowConfig.modules.count == 5)
//    
//  }
//
////  @Test("This validates customer can be overridate later") func testWorkFlowOverridable2() async throws {
////    
////    class CustomHeaderConfig {
////      var enable = true
////      var headerValue = "iOS-SDK"
////      var headerName = "header-name"
////    }
////    
////    let customHeader = Module.of({ CustomHeaderConfig()}, priority: .low, block: { setup in
////      let config = setup.config
////      setup.next { ( context,_, request) in
////        if config.enable {
////          request.header(name: config.headerName, value: config.headerValue)
////        }
////        return request
////      }
////      
////      setup.start { ( context, request) in
////        if config.enable {
////          request.header(name: config.headerName, value: config.headerValue)
////        }
////        return request
////      }
////      
////    })
////    
////    
////    let nosession = Module.of(priority: .high) { setup in
////      setup.next { ( context, _, request) in
////        request.header(name: "nosession", value: "true")
////        return request
////      }
////    }
////    
////    
////    let forceAuth = Module.of{ setup in
////      setup.start { ( context, request) in
////        request.header(name: "forceAuth", value: "true")
////        return request
////      }
////    }
////    
////    let workFlow = Workflow.config { config in
////      config.debug = true
////      config.timeout = 10
////      
////      config.module(customHeader, false) { header in
////        header.enable = true
////        header.headerName = "header-name1"
////        header.headerValue = "Android-SDK1"
////      }
////      
////      config.module(customHeader) { header in
////        header.enable = true
////        header.headerName = "header-name2"
////        header.headerValue = "Android-SDK2"
////      }
////      
////      config.module(customHeader, false) { header in
////        header.enable = true
////        header.headerName = "header-name3"
////        header.headerValue = "iOS-SDK3"
////      }
////      
////      
////      config.module(customHeader) { header in
////        header.enable = true
////        header.headerName = "header-name4"
////        header.headerValue = "Android-SDK4"
////      }
////      
////
////      config.module(forceAuth)
////      config.module(nosession)
////      
////    }
////    
////    try #require(workFlow.workFlowConfig.modules.count > 0)
////    
////    #expect(workFlow.workFlowConfig.modules.count == 5)
////    #expect(workFlow.workFlowConfig.highPriorityModule.count == 1)
////    #expect(workFlow.workFlowConfig.lowPriorityModule.count == 4)
////    
////  }
////  
//  
//}
