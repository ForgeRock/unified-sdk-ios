//
//  WorkflowTests.swift
//  PingOrchestrateTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingOrchestrate

class CustomHeaderConfig {
    var enable = true
    var headerValue = "iOS-SDK"
    var headerName = "header-name"
}

class WorkflowTest: XCTestCase {
    
    var customHeader = Module.of({ CustomHeaderConfig() }, setup: { setup in
        let config = setup.config
        setup.next { ( context, _, request) in
            if config.enable {
                request.header(name: config.headerName, value: config.headerValue)
            }
            return request
        }
        
        setup.start { ( context, request) in
            if config.enable {
                request.header(name: config.headerName, value: config.headerValue)
            }
            return request
        }
    })
    
    let nosession = Module.of { setup in
        setup.next { ( context,_, request) in
            request.header(name: "nosession", value: "true")
            return request
        }
    }
    
    
    let forceAuth = Module.of { setup in
        setup.start { ( context, request) in
            request.header(name: "forceAuth", value: "true")
            return request
        }
    }
    
    override func setUp() {
        super.setUp()
        MockURLProtocol.startInterceptingRequests()
    }
    
    override func tearDown() {
        super.tearDown()
        MockURLProtocol.stopInterceptingRequests()
    }
    
    func testSameModuleInstanceShouldOverrideExistingModule() {
        
        let workflow = Workflow.createWorkflow { config in
            config.timeout = 10
            
            config.module(forceAuth)
            
            config.module(customHeader) { header in
                header.headerName = "header-name1"
                header.headerValue = "Android-SDK"
            }
            
            config.module(nosession)
            
            config.module(customHeader) { header in
                header.headerName = "header-name2"
                header.headerValue = "iOS-SDK"
            }
        }
        
        XCTAssertEqual(workflow.config.modules.count, 3)
        let moduleRegistry = workflow.config.modules.first(where: { $0.id  == customHeader.id })
        XCTAssertEqual((moduleRegistry?.config as? CustomHeaderConfig)?.headerValue, "iOS-SDK")
        XCTAssertEqual(forceAuth.id, workflow.config.modules[0].id)
        XCTAssertEqual(customHeader.id, workflow.config.modules[1].id)
        XCTAssertEqual(nosession.id, workflow.config.modules[2].id)
        
    }
    
    func testSameModuleInstanceShouldOverrideExistingModuleWithPriority (){
        let workflow = Workflow.createWorkflow { config in
            config.timeout = 10
            
            config.module(forceAuth, 1)
            
            config.module(customHeader, 2) { header in
                header.headerName = "header-name1"
                header.headerValue = "Android-SDK"
            }
            
            config.module(nosession, 3)
            
            config.module(customHeader, 10) { header in
                header.headerName = "header-name2"
                header.headerValue = "iOS-SDK"
            }
        }
        
        XCTAssertEqual(workflow.config.modules.count, 3)
        let moduleRegistry = workflow.config.modules.first(where: { $0.id  == customHeader.id })
        XCTAssertEqual((moduleRegistry?.config as? CustomHeaderConfig)?.headerValue, "iOS-SDK")
        let index = workflow.config.modules.firstIndex(where: { $0.id  == customHeader.id })
        //The original position is retained even with the new priority
        XCTAssertEqual(index, 1)
        
    }
    
    func testNotOverrideExistingModule() {
        let workflow = Workflow.createWorkflow { config in
            config.timeout = 10
            
            config.module(forceAuth)
            config.module(nosession)
            
            config.module(customHeader) { header in
                header.headerName = "header-name1"
                header.headerValue = "Android-SDK"
            }
            // You cannot register 2 modules with the same instance,
            // the later one will replace the previous one
            // To register the same module twice, you need to add overridable = false
            // APPEND means the module cannot be replaced and does not replace previous module
            config.module(customHeader, mode: .append) { header in
                header.headerName = "header-name2"
                header.headerValue = "iOS-SDK"
            }
        }
        
        XCTAssertEqual(workflow.config.modules.count, 4)
    }
    
    func testNotOverrideExistingModuleWithIgnore() {
        let workflow = Workflow.createWorkflow { config in
            config.timeout = 10
            
            config.module(forceAuth)
            config.module(nosession)
            
            config.module(customHeader) { header in
                header.headerName = "header-name1"
                header.headerValue = "Android-SDK"
            }
            config.module(customHeader, mode: .ignore) { header in
                header.headerName = "header-name2"
                header.headerValue = "iOS-SDK"
            }
        }
        
        XCTAssertEqual(workflow.config.modules.count, 3)
        let moduleRegistry = workflow.config.modules.first(where: { $0.id  == customHeader.id })
        XCTAssertEqual((moduleRegistry?.config as? CustomHeaderConfig)?.headerValue, "Android-SDK")
    }
    
    func testAddModuleWithIgnore() {
        let workflow = Workflow.createWorkflow { config in
            config.timeout = 10
            
            config.module(forceAuth)
            config.module(nosession)
            
            config.module(customHeader, mode: .ignore) { header in
                header.headerName = "header-name2"
                header.headerValue = "iOS-SDK"
            }
        }
        
        XCTAssertEqual(workflow.config.modules.count, 3)
        let moduleRegistry = workflow.config.modules.first(where: { $0.id  == customHeader.id })
        XCTAssertEqual((moduleRegistry?.config as? CustomHeaderConfig)?.headerValue, "iOS-SDK")
    }
    
    func testModuleDefaultPriority() {
        let workflow = Workflow.createWorkflow { config in
            config.timeout = 10
            
            config.module(forceAuth)
            config.module(nosession)
            
            config.module(customHeader) { header in
                header.headerName = "header-name2"
                header.headerValue = "iOS-SDK"
            }
            
            config.module(nosession)
        }
        
        XCTAssertEqual(workflow.config.modules.count, 3)
        XCTAssertEqual(forceAuth.id, workflow.config.modules[0].id)
        XCTAssertEqual(nosession.id, workflow.config.modules[1].id)
        XCTAssertEqual(customHeader.id, workflow.config.modules[2].id)
    }
    
    func testModuleCustomPriority() {
        let workflow = Workflow.createWorkflow { config in
            config.timeout = 10
            
            config.module(forceAuth, 2)
            config.module(nosession, 3)
            
            config.module(customHeader, 1) { header in
                header.headerName = "header-name2"
                header.headerValue = "iOS-SDK"
            }
        }
        
        XCTAssertEqual(workflow.config.modules.count, 3)
        XCTAssertEqual(customHeader.id, workflow.config.modules[0].id)
        XCTAssertEqual(forceAuth.id, workflow.config.modules[1].id)
        XCTAssertEqual(nosession.id, workflow.config.modules[2].id)
    }
    
    func testModuleWithSamePriority() {
        let workflow = Workflow.createWorkflow { config in
            config.timeout = 10
            
            config.module(forceAuth, 2)
            config.module(nosession, 2)
            
            config.module(customHeader, 1) { header in
                header.headerName = "header-name2"
                header.headerValue = "iOS-SDK"
            }
            
        }
        
        XCTAssertEqual(workflow.config.modules.count, 3)
        XCTAssertEqual(customHeader.id, workflow.config.modules[0].id)
        XCTAssertEqual(forceAuth.id, workflow.config.modules[1].id)
        XCTAssertEqual(nosession.id, workflow.config.modules[2].id)
    }
    
    func testModuleRegistrationInEachStage() {
        let workflow = Workflow(config: WorkflowConfig())
        XCTAssertTrue(workflow.config.modules.isEmpty)
        XCTAssertTrue(workflow.initHandlers.isEmpty)
        XCTAssertTrue(workflow.startHandlers.isEmpty)
        XCTAssertTrue(workflow.nextHandlers.isEmpty)
        XCTAssertTrue(workflow.responseHandlers.isEmpty)
        XCTAssertTrue(workflow.nodeHandlers.isEmpty)
        XCTAssertTrue(workflow.successHandlers.isEmpty)
        XCTAssertTrue(workflow.signOffHandlers.isEmpty)
        
        let dummy = Module.of({CustomHeaderConfig()}) { module in
            module.initialize  {
                // Intercept all send request and inject custom header
            }
            module.start { _, request  in
                return request
            }
            module.next { _,_, request in
                return request
            }
            module.response {_,_ in
                // Handle response
            }
            module.node { _, node in
                return node
            }
            module.success { _, success  in
                return success
            }
            module.transform {_,_ in
                return SuccessNode(session: EmptySession())
            }
            module.signOff { signOff in
                return signOff
            }
        }
        
        let workflow2 = Workflow.createWorkflow { config in
            config.module(dummy)
        }
        
        XCTAssertEqual(workflow2.config.modules.count, 1)
        XCTAssertEqual(workflow2.initHandlers.count, 1)
        XCTAssertEqual(workflow2.startHandlers.count, 1)
        XCTAssertEqual(workflow2.nextHandlers.count, 1)
        XCTAssertEqual(workflow2.responseHandlers.count, 1)
        XCTAssertEqual(workflow2.nodeHandlers.count, 1)
        XCTAssertEqual(workflow2.successHandlers.count, 1)
        XCTAssertEqual(workflow2.signOffHandlers.count, 1)
    }
    
    func testModuleExecution() async {
        var initializeCnt = 0
        var startCnt = 0
        var nextCnt = 0
        var responseCnt = 0
        var transformCnt = 0
        var nodeReceivedCnt = 0
        var successCnt = 0
        var success = false
        
        let json: [String: Bool] = ["booleanKey": true]
        
        MockURLProtocol.requestHandler = { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }
        
        var workflow = Workflow.createWorkflow { config in
            config.httpClient = HttpClient(session: .shared)
        }
        
        let dummy = Module.of({CustomHeaderConfig()}) { module in
            module.initialize  {
                initializeCnt += 1
            }
            module.start { _, request  in
                startCnt += 1
                return request
            }
            module.next { _,_, request in
                nextCnt += 1
                return request
            }
            module.response {_,_ in
                responseCnt += 1
                // Handle response
            }
            module.node { _, node in
                nodeReceivedCnt += 1
                return node
            }
            module.success { _, success1  in
                successCnt += 1
                return success1
            }
            module.transform { flowContext,_ in
                transformCnt += 1
                if success {
                    return SuccessNode(session: EmptySession())
                } else {
                    success = true
                    return TestContinueNode(context: flowContext, workflow: workflow, input: json, actions: [])
                }
            }
        }
        
        workflow = Workflow.createWorkflow { config in
            config.httpClient = HttpClient(session: .shared)
            config.module(dummy)
        }
        
        let node = await workflow.start()
        let connector = node as! ContinueNode
        XCTAssertTrue(workflow === connector.workflow)
        XCTAssertEqual(json, connector.input as? [String: Bool])
        XCTAssertTrue(connector.actions.isEmpty)
        let isEmpty = connector.context.flowContext.isEmpty
        XCTAssertTrue(isEmpty)
        _ = await connector.next()
        XCTAssertEqual(1, initializeCnt)
        XCTAssertEqual(1, startCnt)
        XCTAssertEqual(1, nextCnt)
        XCTAssertEqual(2, responseCnt)
        XCTAssertEqual(2, transformCnt)
        XCTAssertEqual(2, nodeReceivedCnt)
        XCTAssertEqual(1, successCnt)
    }
    
    func testAccessToWorkflowContext() async {
        let json: [String: Any] = ["booleanKey": true]
        var success = false
        
        MockURLProtocol.requestHandler = { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }
        
        var workflow = Workflow.createWorkflow { config in
            config.httpClient = HttpClient(session: .shared)
        }
        
        let dummy = Module.of({CustomHeaderConfig()}) { module in
            module.initialize  {
                let count = (workflow.sharedContext.get(key: "count") as! Int) + 1
                workflow.sharedContext.set(key: "count", value: count)
            }
            module.start { _, request  in
                let count = (workflow.sharedContext.get(key: "count")as! Int) + 1
                workflow.sharedContext.set(key: "count", value: count)
                return request
            }
            module.next { _,_, request in
                let count = (workflow.sharedContext.get(key: "count")as! Int) + 1
                workflow.sharedContext.set(key: "count", value: count)
                return request
            }
            module.response {_,_ in
                let count = (workflow.sharedContext.get(key: "count")as! Int) + 1
                workflow.sharedContext.set(key: "count", value: count)
                // Handle response
            }
            module.node { _, node in
                let count = (workflow.sharedContext.get(key: "count")as! Int) + 1
                workflow.sharedContext.set(key: "count", value: count)
                return node
            }
            module.success { _, success1  in
                let count = (workflow.sharedContext.get(key: "count")as! Int) + 1
                workflow.sharedContext.set(key: "count", value: count)
                return success1
            }
            module.transform { flowContext,_ in
                let count = (workflow.sharedContext.get(key: "count")as! Int) + 1
                workflow.sharedContext.set(key: "count", value: count)
                if success {
                    return SuccessNode(session: EmptySession())
                } else {
                    success = true
                    return TestContinueNode(context: flowContext, workflow: workflow, input: json, actions: [])
                }
            }
        }
        
        workflow = Workflow.createWorkflow { config in
            config.httpClient = HttpClient(session: .shared)
            config.module(dummy)
        }
        
        workflow.sharedContext.set(key: "count", value: 0)
        
        let node = await workflow.start()
        _ = await (node as! ContinueNode).next()
        
        let count = (workflow.sharedContext.get(key: "count")as! Int)
        XCTAssertEqual(10, count)
    }
    
    func testInitStateFunctionThrowException() async {
        let initFailed = Module.of({CustomHeaderConfig()}) { module in
            module.initialize  {
                throw NSError(domain: "InitializationError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize"])
            }
        }
        
        let workflow = Workflow.createWorkflow { config in
            config.module(initFailed)
        }
        
        let node = await workflow.start()
        XCTAssertTrue(node is FailureNode)
        XCTAssertEqual((node as! FailureNode).cause.localizedDescription, "Failed to initialize")
    }
    
    func testStartStateFunctionThrowsException() async throws {
        let startFailed = Module.of({CustomHeaderConfig()}) { module in
            module.start { _,_ in
                throw NSError(domain: "InitializationError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize"])
            }
        }
        let workflow = Workflow.createWorkflow { config in
            config.module(startFailed)
        }
        
        let node = await workflow.start()
        XCTAssertTrue(node is FailureNode)
        XCTAssertEqual((node as! FailureNode).cause.localizedDescription, "Failed to initialize")
    }
    
    func testResponseStateFunctionThrowsException() async throws {
        MockURLProtocol.requestHandler = { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }
        
        let responseFailed = Module.of({CustomHeaderConfig()}) { module in
            module.response { _,_ in
                throw NSError(domain: "InitializationError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize"])
            }
        }
        let workflow = Workflow.createWorkflow { config in
            config.httpClient = HttpClient(session: .shared)
            config.module(responseFailed)
        }
        
        let node = await workflow.start()
        XCTAssertTrue(node is FailureNode)
        XCTAssertEqual((node as! FailureNode).cause.localizedDescription, "Failed to initialize")
    }
    
    func testTransformStateFunctionThrowsException() async throws {
        
        MockURLProtocol.requestHandler = { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }
        
        let transformFailed = Module.of({CustomHeaderConfig()}) { module in
            module.transform { _,_ in
                throw NSError(domain: "InitializationError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize"])
            }
        }
        let workflow = Workflow.createWorkflow { config in
            config.httpClient = HttpClient(session: .shared)
            config.module(transformFailed)
        }
        
        let node = await workflow.start()
        XCTAssertTrue(node is FailureNode)
        XCTAssertEqual((node as! FailureNode).cause.localizedDescription, "Failed to initialize")
    }
    
    func testNextStateFunctionThrowsException() async throws {
        let json = ["booleanKey": true]
        MockURLProtocol.requestHandler = { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }
        var workflow = Workflow.createWorkflow { config in
            config.httpClient = HttpClient(session: .shared)
        }
        
        let nextFailed = Module.of({CustomHeaderConfig()}) { module in
            module.next { _,_, _ in
                throw NSError(domain: "InitializationError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize"])
            }
            
            module.transform { flowContext,_ in
              TestContinueNode(context: flowContext, workflow: workflow, input: json, actions: [])
            }
        }
        
        workflow = Workflow.createWorkflow { config in
            config.httpClient = HttpClient(session: .shared)
            config.module(nextFailed)
        }
        
        let node = await workflow.start()
        let next = await (node as? ContinueNode)?.next()
        XCTAssertTrue(next is FailureNode)
        XCTAssertEqual((next as! FailureNode).cause.localizedDescription, "Failed to initialize")
    }
    
    func testNodeStateFunctionThrowsException() async throws {
        let json = ["booleanKey": true]
        MockURLProtocol.requestHandler = { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }
        var workflow = Workflow.createWorkflow { config in
            config.httpClient = HttpClient(session: .shared)
        }
        
        let nodeFailed = Module.of({CustomHeaderConfig()}) { module in
            module.node { _, _ in
                throw NSError(domain: "InitializationError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize"])
            }
            
            module.transform { flowContext,_ in
              TestContinueNode(context: flowContext, workflow: workflow, input: json, actions: [])
            }
        }
        
        workflow = Workflow.createWorkflow { config in
            config.httpClient = HttpClient(session: .shared)
            config.module(nodeFailed)
        }
        
        let node = await workflow.start()
        XCTAssertTrue(node is FailureNode)
        XCTAssertEqual((node as! FailureNode).cause.localizedDescription, "Failed to initialize")
    }
    
    func testSuccessStateFunctionThrowsException() async throws {
        MockURLProtocol.requestHandler = { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }
        var workflow = Workflow.createWorkflow { config in
            config.httpClient = HttpClient(session: .shared)
        }
        
        let successFailed = Module.of({CustomHeaderConfig()}) { module in
            module.success { _, _ in
                throw NSError(domain: "InitializationError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize"])
            }
            
            module.transform { flowContext,_ in
                SuccessNode(session: EmptySession())
            }
        }
        
        workflow = Workflow.createWorkflow { config in
            config.httpClient = HttpClient(session: .shared)
            config.module(successFailed)
        }
        
        let node = await workflow.start()
      XCTAssertTrue(node is FailureNode)
        XCTAssertEqual((node as! FailureNode).cause.localizedDescription, "Failed to initialize")
    }
    
    func testExecutionFailure() async {
        MockURLProtocol.requestHandler = { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!, "Invalid request".data(using: .utf8)!)
        }
        
        let dummy = Module.of({CustomHeaderConfig()}) { module in
            module.transform {_,_ in
              return ErrorNode(input: [:], message: "Invalid request")
            }
        }
        
        let workflow = Workflow.createWorkflow { config in
            config.httpClient = HttpClient(session: .shared)
            config.module(dummy)
        }
        
        let node = await workflow.start()
        let failure = node as! ErrorNode
        XCTAssertEqual("Invalid request", failure.message)
        XCTAssertTrue(failure.input.isEmpty)
    }
    
    func testSignOffShouldReturnSuccessResultWhenNoExceptionsOccur() async {
        
        MockURLProtocol.requestHandler = { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, "".data(using: .utf8)!)
        }
        
        let workflow = Workflow.createWorkflow { config in
            config.httpClient = HttpClient(session: .shared)
        }
        
        let result = await workflow.signOff()
        
        switch result {
        case .success(let result):
            XCTAssertNotNil(result)
            break
            
        default:
            XCTFail("Expected success result")
        }
        
    }
    
    func testSignOffShouldReturnFailureResultWhenExceptionOccurs() async {
        MockURLProtocol.requestHandler = { request in
            throw NSError(domain: "SignOffError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Sign off failed"])
        }
        
        let workflow = Workflow.createWorkflow { config in
            config.httpClient = HttpClient(session: .shared)
        }
        
        let result = await workflow.signOff()
        switch result {
        case .failure(let error):
            XCTAssertEqual(error.localizedDescription, "Sign off failed")
            break
            
        default:
            XCTFail("Expected failure result")
        }
    }
}
