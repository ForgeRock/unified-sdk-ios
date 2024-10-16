//
//  DaVinciErrorTests.swift
//  PingDavinciTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import XCTest
@testable import PingOrchestrate
@testable import PingStorage
@testable import PingLogger
@testable import PingOidc
@testable import PingDavinci

class DaVinciErrorTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    MockURLProtocol.startInterceptingRequests()
    _ = CollectorFactory()
  }
  
  override func tearDown() {
    super.tearDown()
    MockURLProtocol.stopInterceptingRequests()
  }
  
  func testDaVinciWellKnownEndpointFailedwith404() async throws {
    
    MockURLProtocol.requestHandler = { request in
      switch request.url!.path {
      case MockAPIEndpoint.discovery.url.path:
        return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 404, httpVersion: nil, headerFields: MockResponse.headers)!, "Not Found".data(using: .utf8)!)
      default:
        return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
      }
    }
    
    let daVinci = DaVinci.createDaVinci { config in
      config.httpClient = HttpClient(session: .shared)
      
      config.module(OidcModule.config) { oidcValue in
        oidcValue.clientId = "test"
        oidcValue.scopes = ["openid", "email", "address"]
        oidcValue.redirectUri = "http://localhost:8080"
        oidcValue.discoveryEndpoint = "http://localhost/.well-known/openid-configuration"
        oidcValue.storage = MemoryStorage()
        oidcValue.logger = LogManager.standard
      }
      
      config.module(CookieModule.config) { cookieValue in
        cookieValue.cookieStorage = MemoryStorage()
        cookieValue.persist = ["ST"]
      }
    }
    
    let node = await daVinci.start()
    XCTAssertTrue(node is FailureNode)
    let error = (node as! FailureNode).cause as! OidcError
    
    switch error {
    case .apiError(let code, _):
      XCTAssertEqual(code, 404)
    default:
      XCTFail()
    }
    
  }
  
  func testDaVinciAuthorizeEndpointFailedWith401() async throws {
    let number = Int.random(in: 400 ..< 500)
    MockURLProtocol.requestHandler = { request in
      switch request.url!.path {
      case MockAPIEndpoint.discovery.url.path:
        return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
      case MockAPIEndpoint.authorization.url.path:
        return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: number, httpVersion: nil, headerFields: MockResponse.headers)!, """
                {
                    "id": "7bbe285f-c0e0-41ef-8925-c5c5bb370acc",
                    "code": 1999,
                    "message": "Unauthorized!",
                    "errorMessage": "Unauthorized!",
                }
                """.data(using: .utf8)!)
      default:
        return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
      }
    }
    
    let daVinci = DaVinci.createDaVinci { config in
      config.httpClient = HttpClient(session: .shared)
      
      config.module(OidcModule.config) { oidcValue in
        oidcValue.clientId = "test"
        oidcValue.scopes = ["openid", "email", "address"]
        oidcValue.redirectUri = "http://localhost:8080"
        oidcValue.discoveryEndpoint = "http://localhost/.well-known/openid-configuration"
        oidcValue.storage = MemoryStorage()
        oidcValue.logger = LogManager.standard
      }
      
      config.module(CookieModule.config) { cookieValue in
        cookieValue.cookieStorage = MemoryStorage()
        cookieValue.persist = ["ST"]
      }
    }
    
    let node = await daVinci.start()
    XCTAssertTrue(node is FailureNode)
    let failureNode = node as! FailureNode
    let apiError = failureNode.cause as! ApiError
    switch apiError {
    case .error(let code, _, _):
      XCTAssertTrue(code == number)
    }
  }
  
  func testDaVinciInvalidSessionBetween400To499() async throws {
    let number = Int.random(in: 400 ..< 500)
    MockURLProtocol.requestHandler = { request in
      switch request.url!.path {
      case MockAPIEndpoint.discovery.url.path:
        return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
      case MockAPIEndpoint.authorization.url.path:
        return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: number, httpVersion: nil, headerFields: MockResponse.headers)!, """
                {
                    "id": "7bbe285f-c0e0-41ef-8925-c5c5bb370acc",
                    "connectorId": "pingOneAuthenticationConnector",
                    "capabilityName": "setSession",
                    "message": "Invalid Connector.",
                }
                """.data(using: .utf8)!)
      default:
        return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
      }
    }
    
    let daVinci = DaVinci.createDaVinci { config in
      config.httpClient = HttpClient(session: .shared)
      
      config.module(OidcModule.config) { oidcValue in
        oidcValue.clientId = "test"
        oidcValue.scopes = ["openid", "email", "address"]
        oidcValue.redirectUri = "http://localhost:8080"
        oidcValue.discoveryEndpoint = "http://localhost/.well-known/openid-configuration"
        oidcValue.storage = MemoryStorage()
        oidcValue.logger = LogManager.standard
      }
      
      config.module(CookieModule.config) { cookieValue in
        cookieValue.cookieStorage = MemoryStorage()
        cookieValue.persist = ["ST"]
      }
    }
    
    let node = await daVinci.start()
    XCTAssertTrue(node is FailureNode)
    let failureNode = node as! FailureNode
    let apiError = failureNode.cause as! ApiError
    switch apiError {
    case .error(let code, _, _):
      XCTAssertTrue(code == number)
    }
  }
  
  func testDaVinciInvalidConnectorBetween400To499() async throws {
    let number = Int.random(in: 400 ..< 500)
    MockURLProtocol.requestHandler = { request in
      switch request.url!.path {
      case MockAPIEndpoint.discovery.url.path:
        return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
      case MockAPIEndpoint.authorization.url.path:
        return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: number, httpVersion: nil, headerFields: MockResponse.headers)!, """
                {
                    "id": "7bbe285f-c0e0-41ef-8925-c5c5bb370acc",
                    "connectorId": "pingOneAuthenticationConnector",
                    "capabilityName": "returnSuccessResponseRedirect",
                    "message": "Invalid Connector.",
                }
                """.data(using: .utf8)!)
      default:
        return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
      }
    }
    
    let daVinci = DaVinci.createDaVinci { config in
      config.httpClient = HttpClient(session: .shared)
      
      config.module(OidcModule.config) { oidcValue in
        oidcValue.clientId = "test"
        oidcValue.scopes = ["openid", "email", "address"]
        oidcValue.redirectUri = "http://localhost:8080"
        oidcValue.discoveryEndpoint = "http://localhost/.well-known/openid-configuration"
        oidcValue.storage = MemoryStorage()
        oidcValue.logger = LogManager.standard
      }
      
      config.module(CookieModule.config) { cookieValue in
        cookieValue.cookieStorage = MemoryStorage()
        cookieValue.persist = ["ST"]
      }
    }
    
    let node = await daVinci.start()
    XCTAssertTrue(node is FailureNode)
    let failureNode = node as! FailureNode
    let apiError = failureNode.cause as! ApiError
    switch apiError {
    case .error(let code, _, _):
      XCTAssertTrue(code == number)
    }
  }
  
  func testDaVinciTimeOutBetween400To499() async throws {
    let number = Int.random(in: 400 ..< 500)
    MockURLProtocol.requestHandler = { request in
      switch request.url!.path {
      case MockAPIEndpoint.discovery.url.path:
        return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
      case MockAPIEndpoint.authorization.url.path:
        return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: number, httpVersion: nil, headerFields: MockResponse.headers)!, """
                {
                    "id": "7bbe285f-c0e0-41ef-8925-c5c5bb370acc",
                    "code": "requestTimedOut",
                    "message": "Request timed out. Please try again.",
                }
                """.data(using: .utf8)!)
      default:
        return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
      }
    }
    
    let daVinci = DaVinci.createDaVinci { config in
      config.httpClient = HttpClient(session: .shared)
      
      config.module(OidcModule.config) { oidcValue in
        oidcValue.clientId = "test"
        oidcValue.scopes = ["openid", "email", "address"]
        oidcValue.redirectUri = "http://localhost:8080"
        oidcValue.discoveryEndpoint = "http://localhost/.well-known/openid-configuration"
        oidcValue.storage = MemoryStorage()
        oidcValue.logger = LogManager.standard
      }
      
      config.module(CookieModule.config) { cookieValue in
        cookieValue.cookieStorage = MemoryStorage()
        cookieValue.persist = ["ST"]
      }
    }
    
    let node = await daVinci.start()
    XCTAssertTrue(node is FailureNode)
    let failureNode = node as! FailureNode
    let apiError = failureNode.cause as! ApiError
    switch apiError {
    case .error(let code, _, _):
      XCTAssertTrue(code == number)
    }
  }
  
  
  func testDaVinciAuthorizeEndpointFailedBetween400To499() async throws {
    MockURLProtocol.requestHandler = { request in
      switch request.url!.path {
      case MockAPIEndpoint.discovery.url.path:
        return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
      case MockAPIEndpoint.authorization.url.path:
        return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: 400, httpVersion: nil, headerFields: MockResponse.headers)!, """
                {
                    "id": "7bbe285f-c0e0-41ef-8925-c5c5bb370acc",
                    "code": "INVALID_REQUEST",
                    "message": "Invalid DV Flow Policy ID: Single_Factor"
                }
                """.data(using: .utf8)!)
      default:
        return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
      }
    }
    
    let daVinci = DaVinci.createDaVinci { config in
      config.httpClient = HttpClient(session: .shared)
      
      config.module(OidcModule.config) { oidcValue in
        oidcValue.clientId = "test"
        oidcValue.scopes = ["openid", "email", "address"]
        oidcValue.redirectUri = "http://localhost:8080"
        oidcValue.discoveryEndpoint = "http://localhost/.well-known/openid-configuration"
        oidcValue.storage = MemoryStorage()
        oidcValue.logger = LogManager.standard
      }
      
      config.module(CookieModule.config) { cookieValue in
        cookieValue.cookieStorage = MemoryStorage()
        cookieValue.persist = ["ST"]
      }
    }
    
    let node = await daVinci.start()
    XCTAssertTrue(node is ErrorNode)
    let errorNode = node as! ErrorNode
    XCTAssertTrue(errorNode.input.description.contains("INVALID_REQUEST"))
  }
  
  func testDaVinciAuthorizeEndpointFailedWith500() async throws {
    MockURLProtocol.requestHandler = { request in
      switch request.url!.path {
      case MockAPIEndpoint.discovery.url.path:
        return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
      case MockAPIEndpoint.authorization.url.path:
        return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: 500, httpVersion: nil, headerFields: MockResponse.headers)!, """
              {
                  "id": "7bbe285f-c0e0-41ef-8925-c5c5bb370acc",
                  "code": "INVALID_REQUEST",
                  "message": "Invalid DV Flow Policy ID: Single_Factor"
              }
              """.data(using: .utf8)!)
      default:
        return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
      }
    }
    
    let daVinci = DaVinci.createDaVinci { config in
      config.httpClient = HttpClient(session: .shared)
      
      config.module(OidcModule.config) { oidcValue in
        oidcValue.clientId = "test"
        oidcValue.scopes = ["openid", "email", "address"]
        oidcValue.redirectUri = "http://localhost:8080"
        oidcValue.discoveryEndpoint = "http://localhost/.well-known/openid-configuration"
        oidcValue.storage = MemoryStorage()
        oidcValue.logger = LogManager.standard
      }
      
      config.module(CookieModule.config) { cookieValue in
        cookieValue.cookieStorage = MemoryStorage()
        cookieValue.persist = ["ST"]
      }
    }
    
    let node = await daVinci.start()
    XCTAssertTrue(node is FailureNode)
    let failureNode = node as! FailureNode
    let apiError = failureNode.cause as! ApiError
    switch apiError {
    case .error(let code, _, _):
      XCTAssertTrue(code == 500)
    }
    
  }
  
  func testDaVinciAuthorizeEndpointFailedWithOKResponseButFailedStatusDuringTransform() async throws {
    MockURLProtocol.requestHandler = { request in
      switch request.url!.path {
      case MockAPIEndpoint.discovery.url.path:
        return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
      case MockAPIEndpoint.authorization.url.path:
        return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, """
                {
                    "environment": {
                        "id": "0c6851ed-0f12-4c9a-a174-9b1bf8b438ae"
                    },
                    "status": "FAILED",
                    "error": {
                        "code": "login_required",
                        "message": "The request could not be completed. There was an issue processing the request"
                    }
                }
                """.data(using: .utf8)!)
      default:
        return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
      }
    }
    
    let daVinci = DaVinci.createDaVinci { config in
      config.httpClient = HttpClient(session: .shared)
      
      config.module(OidcModule.config) { oidcValue in
        oidcValue.clientId = "test"
        oidcValue.scopes = ["openid", "email", "address"]
        oidcValue.redirectUri = "http://localhost:8080"
        oidcValue.discoveryEndpoint = "http://localhost/.well-known/openid-configuration"
        oidcValue.storage = MemoryStorage()
        oidcValue.logger = LogManager.standard
      }
      
      config.module(CookieModule.config) { cookieValue in
        cookieValue.cookieStorage = MemoryStorage()
        cookieValue.persist = ["ST"]
      }
    }
    
    let node = await daVinci.start()
    XCTAssertTrue(node is FailureNode)
    let error = (node as! FailureNode).cause as! ApiError
    
    switch error {
    case .error( _, _, let message):
      XCTAssertTrue(message.contains("login_required"))
    }
    
  }
  
  func testDaVinciAuthorizeEndpointFailedWithOKResponseButErrorDuringTransform() async throws {
    MockURLProtocol.requestHandler = { request in
      switch request.url!.path {
      case MockAPIEndpoint.discovery.url.path:
        return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
      case MockAPIEndpoint.authorization.url.path:
        return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, """
              {
                  "environment": {
                      "id": "0c6851ed-0f12-4c9a-a174-9b1bf8b438ae"
                  },
                  "error": {
                      "code": "login_required",
                      "message": "The request could not be completed. There was an issue processing the request"
                  }
              }
              """.data(using: .utf8)!)
      default:
        return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
      }
    }
    
    let daVinci = DaVinci.createDaVinci { config in
      config.httpClient = HttpClient(session: .shared)
      
      config.module(OidcModule.config) { oidcValue in
        oidcValue.clientId = "test"
        oidcValue.scopes = ["openid", "email", "address"]
        oidcValue.redirectUri = "http://localhost:8080"
        oidcValue.discoveryEndpoint = "http://localhost/.well-known/openid-configuration"
        oidcValue.storage = MemoryStorage()
        oidcValue.logger = LogManager.standard
      }
      
      config.module(CookieModule.config) { cookieValue in
        cookieValue.cookieStorage = MemoryStorage()
        cookieValue.persist = ["ST"]
      }
    }
    
    let node = await daVinci.start()
    XCTAssertTrue(node is FailureNode)
    let error = (node as! FailureNode).cause as! ApiError
    
    switch error {
    case .error( _, _, let message):
      XCTAssertTrue(message.contains("login_required"))
    }
    
  }
  
  func testDaVinciTransformFailed() async throws {
    MockURLProtocol.requestHandler = { request in
      switch request.url!.path {
      case MockAPIEndpoint.discovery.url.path:
        return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
      case MockAPIEndpoint.authorization.url.path:
        return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.authorizeResponseHeaders)!, " Not a Json ".data(using: .utf8)!)
      default:
        return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
      }
    }
    
    let daVinci = DaVinci.createDaVinci { config in
      config.httpClient = HttpClient(session: .shared)
      
      config.module(OidcModule.config) { oidcValue in
        oidcValue.clientId = "test"
        oidcValue.scopes = ["openid", "email", "address"]
        oidcValue.redirectUri = "http://localhost:8080"
        oidcValue.discoveryEndpoint = "http://localhost/.well-known/openid-configuration"
        oidcValue.storage = MemoryStorage()
        oidcValue.logger = LogManager.standard
      }
      
      config.module(CookieModule.config) { cookieValue in
        cookieValue.cookieStorage = MemoryStorage()
        cookieValue.persist = ["ST"]
      }
    }
    
    let node = await daVinci.start()
    XCTAssertTrue(node is FailureNode)
  }
  
  func testDaVinciInvalidPassword() async throws {
    MockURLProtocol.requestHandler = { request in
      switch request.url!.path {
      case MockAPIEndpoint.discovery.url.path:
        return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
      case MockAPIEndpoint.customHTMLTemplate.url.path:
        return (HTTPURLResponse(url: MockAPIEndpoint.customHTMLTemplate.url, statusCode: 400, httpVersion: nil, headerFields: MockResponse.customHTMLTemplateHeaders)!, MockResponse.customHTMLTemplateWithInvalidPassword)
      case MockAPIEndpoint.authorization.url.path:
        return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.authorizeResponseHeaders)!, MockResponse.authorizeResponse)
      default:
        return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
      }
    }
    
    
    let daVinci = DaVinci.createDaVinci { config in
      config.httpClient = HttpClient(session: .shared)
      
      config.module(OidcModule.config) { oidcValue in
        oidcValue.clientId = "test"
        oidcValue.scopes = ["openid", "email", "address"]
        oidcValue.redirectUri = "http://localhost:8080"
        oidcValue.discoveryEndpoint = "http://localhost/.well-known/openid-configuration"
        oidcValue.storage = MemoryStorage()
        oidcValue.logger = LogManager.standard
      }
      
      config.module(CookieModule.config) { cookieValue in
        cookieValue.cookieStorage = MemoryStorage()
        cookieValue.persist = ["ST"]
      }
    }
    
    let node =  await daVinci.start()
    XCTAssertTrue(node is ContinueNode)
    let connector = node as! ContinueNode
    if let textCollector = connector.collectors[0] as? TextCollector {
      textCollector.value = "My First Name"
    }
    if let passwordCollector = connector.collectors[1] as? PasswordCollector {
      passwordCollector.value = "My Password"
    }
    if let submitCollector = connector.collectors[2] as? SubmitCollector {
      submitCollector.value = "click me"
    }
    
    let next = await connector.next()
    
    XCTAssertEqual((connector.collectors[1] as? PasswordCollector)?.value, "")
    
    XCTAssertTrue(next is ErrorNode)
    let errorNode = next as! ErrorNode
    XCTAssertEqual(errorNode.message, "Invalid username and/or password")
    XCTAssertTrue(errorNode.input.description.contains("The provided password did not match provisioned password"))
  }
}
