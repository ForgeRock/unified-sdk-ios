//
//  DaVinciTests.swift
//  PingDavinciTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingOrchestrate
@testable import PingLogger
@testable import PingOidc
@testable import PingStorage
@testable import PingDavinci

final class DaVinciTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        MockURLProtocol.startInterceptingRequests()
        _ = CollectorFactory()
        
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
            case MockAPIEndpoint.token.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.token.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.tokenResponse)
            case MockAPIEndpoint.userinfo.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.userinfo.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.userinfoResponse)
            case MockAPIEndpoint.revocation.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.revocation.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, Data())
            case MockAPIEndpoint.endSession.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.endSession.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, Data())
            case MockAPIEndpoint.customHTMLTemplate.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.customHTMLTemplate.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.customHTMLTemplateHeaders)!, MockResponse.customHTMLTemplate)
            case MockAPIEndpoint.authorization.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.authorizeResponseHeaders)!, MockResponse.authorizeResponse)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
    }
    
    override func tearDown() {
        super.tearDown()
        MockURLProtocol.stopInterceptingRequests()
    }
    
    func testDaVinci() throws {
        
        let davinci = DaVinci.createDaVinci { config in
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = "c12743f9-08e8-4420-a624-71bbb08e9fe1"
                oidcValue.scopes = ["openid", "email", "address", "phone", "profile"]
                oidcValue.redirectUri = "org.forgerock.demo://oauth2redirect"
                oidcValue.discoveryEndpoint = "https://auth.pingone.ca/02fb4743-189a-4bc7-9d6c-a919edfe6447/as/.well-known/openid-configuration"
            }
        }
        
        XCTAssertEqual(davinci.config.modules.count, 4)
        XCTAssertEqual(davinci.initHandlers.count, 2)
        XCTAssertEqual(davinci.nextHandlers.count, 2)
        XCTAssertEqual(davinci.nodeHandlers.count, 0)
        XCTAssertEqual(davinci.responseHandlers.count, 1)
        XCTAssertEqual(davinci.signOffHandlers.count, 2)
        XCTAssertEqual(davinci.successHandlers.count, 1)
        
        let nosession = Module.of { setup in
            setup.next { ( context,connector, request) in
                request.header(name: "nosession", value: "true")
                return request
            }
        }
        
        let davinci1 = DaVinci.createDaVinci { config in
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = "c12743f9-08e8-4420-a624-71bbb08e9fe1"
                oidcValue.scopes = ["openid", "email", "address", "phone", "profile"]
                oidcValue.redirectUri = "org.forgerock.demo://oauth2redirect"
                oidcValue.discoveryEndpoint = "https://auth.pingone.ca/02fb4743-189a-4bc7-9d6c-a919edfe6447/as/.well-known/openid-configuration"
            }
            
            config.module(nosession)
        }
        
        XCTAssertEqual(davinci1.config.modules.count, 5)
        XCTAssertEqual(davinci1.initHandlers.count, 2)
        XCTAssertEqual(davinci1.nextHandlers.count, 3)
        XCTAssertEqual(davinci1.nodeHandlers.count, 0)
        XCTAssertEqual(davinci1.responseHandlers.count, 1)
        XCTAssertEqual(davinci1.signOffHandlers.count, 2)
        XCTAssertEqual(davinci1.successHandlers.count, 1)
    }
    
    
    func testDaVinciDefaultModuleSequence() async throws {
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
        
        XCTAssertEqual(4, daVinci.config.modules.count)
        let list = daVinci.config.modules
        XCTAssertTrue(list[0].config is CustomHeaderConfig)
        XCTAssertTrue(list[1].config is Void)
        XCTAssertTrue(list[2].config is OidcClientConfig)
        XCTAssertTrue(list[3].config is CookieConfig)
        
    }
    
    func testDaVinciSimpleHappyPath() async throws {
        let tokenStorage = MemoryStorage<Token>()
        let cookieStorage = MemoryStorage<[PingHTTPCookie]>()
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = HttpClient(session: .shared)
            
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = "test"
                oidcValue.scopes = ["openid", "email", "address"]
                oidcValue.redirectUri = "http://localhost:8080"
                oidcValue.discoveryEndpoint = "http://localhost/.well-known/openid-configuration"
                oidcValue.storage = tokenStorage
                oidcValue.logger = LogManager.standard
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = cookieStorage
                cookieValue.persist = ["ST"]
            }
        }
        
        var node = await daVinci.start()
        XCTAssertTrue(node is Connector)
        let connector = node as! Connector
        XCTAssertEqual(connector.collectors.count, 5)
        
        XCTAssertEqual(connector.id, "cq77vwelou")
        XCTAssertEqual(connector.name, "Username/Password Form")
        XCTAssertEqual(connector.description, "Test Description")
        XCTAssertEqual(connector.category, "CUSTOM_HTML")
        
        (connector.collectors[0] as? TextCollector)?.value = "My First Name"
        (connector.collectors[1] as? PasswordCollector)?.value = "My Password"
        (connector.collectors[2] as? SubmitCollector)?.value = "click me"
        
        node = await connector.next()
        XCTAssertTrue(node is SuccessNode)
        
        let authorizeReq = MockURLProtocol.requestHistory[1]
        XCTAssertTrue(authorizeReq.url!.query?.contains("client_id=test") ?? false)
        XCTAssertTrue(authorizeReq.url!.query?.contains("response_mode=pi.flow") ?? false)
        XCTAssertTrue(authorizeReq.url!.query?.contains("code_challenge_method=S256") ?? false)
        XCTAssertTrue(authorizeReq.url!.query?.contains("code_challenge=") ?? false)
        XCTAssertTrue(authorizeReq.url!.query?.contains("redirect_uri=") ?? false)
        
        let request = MockURLProtocol.requestHistory[2]
        //let result = request.httpBody as! TextContent
        //            let json = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        //            XCTAssertEqual(json["eventName"] as? String, "continue")
        //            let parameters = json["parameters"] as! [String: Any]
        //            let data = parameters["data"] as! [String: Any]
        //            XCTAssertEqual(data["actionKey"] as? String, "SIGNON")
        //            let formData = data["formData"] as! [String: Any]
        //            XCTAssertEqual(formData["username"] as? String, "My First Name")
        //            XCTAssertEqual(formData["password"] as? String, "My Password")
        
        XCTAssertEqual(request.allHTTPHeaderFields!["x-requested-with"], "forgerock-sdk")
        XCTAssertEqual(request.allHTTPHeaderFields!["x-requested-platform"], "ios")
        XCTAssertTrue(request.allHTTPHeaderFields!["Cookie"]?.contains("interactionId") ?? false)
        //XCTAssertTrue(request.allHTTPHeaderFields!["Cookie"]?.contains("interactionToken") ?? false)
        //XCTAssertTrue(request.allHTTPHeaderFields!["Cookie"]?.contains("skProxyApiEnvironmentId") ?? false)
        
        let successNode = node as! SuccessNode
        let user = successNode.user
        let userToken = await user?.token()
        switch userToken! {
        case .success(let token):
            XCTAssertEqual(token.accessToken, "Dummy AccessToken")
            break
        case .failure(_):
            XCTFail("Should have succeeded")
        }
        //            XCTAssertEqual((user?.token() as? Result.Success)?.value.accessToken, "Dummy AccessToken")
        
        let u = await daVinci.user()
        await u?.logout()
        let revoke = MockURLProtocol.requestHistory[4]
        XCTAssertEqual(revoke.url!.absoluteString, "https://auth.test-one-pingone.com/revoke")
        //            let revokeBody =  try JSONSerialization.jsonObject(with: revoke.httpBody!) as! [String: Any]
        //            XCTAssertEqual(revokeBody["client_id"] as? String, "test")
        //            XCTAssertEqual(revokeBody["token"] as? String, "Dummy RefreshToken")
        
        let signOff = MockURLProtocol.requestHistory[5]
        XCTAssertEqual(signOff.url!.absoluteString, "https://auth.test-one-pingone.com/signoff?id_token_hint=Dummy%20IdToken&client_id=test")
        XCTAssertTrue(signOff.allHTTPHeaderFields!["Cookie"]?.contains("ST=session_token") ?? false)
        
        let storedToken = try await tokenStorage.get()
        XCTAssertNil(storedToken)
        let storedCokie = try await cookieStorage.get()
        XCTAssertNil(storedCokie)
        let storedUser = await daVinci.user()
        XCTAssertNil(storedUser)
    }
    
    func testDaVinciAdditionOidcParameter() async throws {
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = HttpClient(session: .shared)
            
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = "test"
                oidcValue.scopes = ["openid", "email", "address"]
                oidcValue.redirectUri = "http://localhost:8080"
                oidcValue.discoveryEndpoint = "http://localhost/.well-known/openid-configuration"
                oidcValue.storage =  MemoryStorage()
                oidcValue.logger = LogManager.standard
                oidcValue.acrValues = "acrValues"
                oidcValue.display = "display"
                oidcValue.loginHint = "login_hint"
                oidcValue.nonce = "nonce"
                oidcValue.prompt = "prompt"
                oidcValue.uiLocales = "ui_locales"
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = MemoryStorage()
                cookieValue.persist = ["ST"]
            }
        }
        
        var node = await daVinci.start()
        XCTAssertTrue(node is Connector)
        let connector = node as! Connector
        (connector.collectors[0] as? TextCollector)?.value = "My First Name"
        (connector.collectors[1] as? PasswordCollector)?.value = "My Password"
        (connector.collectors[2] as? SubmitCollector)?.value = "click me"
        
        node = await connector.next()
        XCTAssertTrue(node is SuccessNode)
        
        let authorizeReq = MockURLProtocol.requestHistory[1]
        XCTAssertTrue(authorizeReq.url?.query?.contains("client_id=test") ?? false)
        XCTAssertTrue(authorizeReq.url?.query?.contains("response_mode=pi.flow") ?? false)
        XCTAssertTrue(authorizeReq.url?.query?.contains("code_challenge_method=S256") ?? false)
        XCTAssertTrue(authorizeReq.url?.query?.contains("code_challenge=") ?? false)
        XCTAssertTrue(authorizeReq.url?.query?.contains("redirect_uri=http://localhost:8080") ?? false)
        XCTAssertTrue(authorizeReq.url?.query?.contains("acr_values=acrValues") ?? false)
        XCTAssertTrue(authorizeReq.url?.query?.contains("display=display") ?? false)
        XCTAssertTrue(authorizeReq.url?.query?.contains("login_hint=login_hint") ?? false)
        XCTAssertTrue(authorizeReq.url?.query?.contains("nonce=nonce") ?? false)
        XCTAssertTrue(authorizeReq.url?.query?.contains("prompt=prompt") ?? false)
        XCTAssertTrue(authorizeReq.url?.query?.contains("ui_locales=ui_locales") ?? false)
    }
    
    func testDaVinciRevokeAccessToken() async throws {
        let tokenStorage = MemoryStorage<Token>()
        let cookieStorage = MemoryStorage<[PingHTTPCookie]>()
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = HttpClient(session: .shared)
            
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = "test"
                oidcValue.scopes = ["openid", "email", "address"]
                oidcValue.redirectUri = "http://localhost:8080"
                oidcValue.discoveryEndpoint = "http://localhost/.well-known/openid-configuration"
                oidcValue.storage = tokenStorage
                oidcValue.logger = LogManager.standard
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = cookieStorage
                cookieValue.persist = ["ST"]
            }
        }
        
        var node = await daVinci.start()
        XCTAssertTrue(node is Connector)
        let connector = node as! Connector
        (connector.collectors[0] as? TextCollector)?.value = "My First Name"
        (connector.collectors[1] as? PasswordCollector)?.value = "My Password"
        (connector.collectors[2] as? SubmitCollector)?.value = "click me"
        
        node = await connector.next()
        XCTAssertTrue(node is SuccessNode)
        
        let u = await daVinci.user()
        await u?.revoke()
        let storedToken = try await tokenStorage.get()
        XCTAssertNil(storedToken)
        let storedCokie = try await cookieStorage.get()
        XCTAssertNotNil(storedCokie)
    }
}
