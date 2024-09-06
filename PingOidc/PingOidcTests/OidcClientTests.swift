//
//  OidcClientTests.swift
//  PingOidcTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingOidc
@testable import PingOrchestrate
@testable import PingStorage

final class OidcClientTests: XCTestCase {
    var oidcClientConfig: OidcClientConfig!
    var oidcClient: OidcClient!
    
    override func setUp() {
        super.setUp()
        oidcClientConfig = OidcClientConfig()
        let agent = MockAgent()
        oidcClientConfig.updateAgent(agent)
        oidcClientConfig.discoveryEndpoint = MockAPIEndpoint.discovery.url.absoluteString
        oidcClientConfig.storage = MockStorage<Token>()
        oidcClientConfig.clientId = "test-client-id"
        oidcClientConfig.httpClient = HttpClient(session: .shared)
        oidcClient = OidcClient(config: oidcClientConfig)
        
        MockURLProtocol.startInterceptingRequests()
        
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
            case MockAPIEndpoint.token.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.token.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.token)
            case MockAPIEndpoint.userinfo.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.userinfo.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.userinfo)
            case MockAPIEndpoint.revocation.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.revocation.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, Data())
            case MockAPIEndpoint.endSession.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.endSession.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, Data())
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
    }
    
    override func tearDown() {
        MockURLProtocol.stopInterceptingRequests()
        
        oidcClient = nil
        oidcClientConfig = nil
        super.tearDown()
    }
    
    func testFailedToLookupDiscoveryEndpoint() async throws {
        
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: MockResponse.headers)!, Data())
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        let result = await oidcClient.token()
        
        switch result {
        case .success(_):
            XCTFail("Should have failed with error")
        case .failure(let failure):
            switch failure {
            case .apiError(let code, _):
                XCTAssertEqual(code, 500)
            case .authorizeError, .networkError, .unknown:
                XCTFail("Should have failed with .apiError")
            }
        }
    }
    
    func testAccessTokenShouldReturnCachedTokenIfNotExpired() async throws {
        let result = await oidcClient.token()
        switch result {
        case .success( _):
            break
        case .failure(_):
            XCTFail("Should have succeeded")
        }
        let cached = await oidcClient.token()
        switch cached {
        case .success( let token):
            XCTAssertEqual(token.accessToken, "Dummy AccessToken")
            XCTAssertEqual(token.tokenType, "Dummy Token Type")
            XCTAssertEqual(token.refreshToken, "Dummy RefreshToken")
            XCTAssertEqual(token.idToken, "Dummy IdToken")
            XCTAssertEqual(token.scope, "openid email address")
            break
        case .failure(let error):
            XCTFail("Should have succeeded, but failed with error \(error.errorMessage)")
        }
        
        XCTAssertEqual(MockURLProtocol.requestHistory.count, 2)
    }
    
    func testAccessTokenShouldRefreshTokenIfExpired() async throws {
        let result = await oidcClient.token()
        switch result {
        case .success( _):
            break
        case .failure(_):
            XCTFail("Should have succeeded")
        }
        
        // Advance time by 1 second
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        _ = await oidcClient.token()
        
        // auto refresh has been triggered
        XCTAssertEqual(MockURLProtocol.requestHistory.count, 3)
        XCTAssertEqual(Int(MockURLProtocol.requestHistory.last!.value(forHTTPHeaderField: "Content-Length")!), "grant_type=refresh_token&refresh_token=Dummy RefreshToken&client_id=test-client-id".count)
    }
    
    func testRevokeShouldDeleteTokenFromStorage() async throws {
        // First, get an access token
        let result = await oidcClient.token()
        switch result {
        case .success( _):
            break
        case .failure(_):
            XCTFail("Should have succeeded")
        }
        
        // Then, revoke the access token
        await oidcClient.revoke()
        
        // Check that the token is no longer in storage
        let tokenInStorage = try await oidcClientConfig.storage.get()
        XCTAssertNil(tokenInStorage)
    }
    
    func testUserinfoShouldReturnUserInfo() async throws {
        let result = await oidcClient.userinfo()
        switch result {
        case .success(let userinfo):
            XCTAssertEqual(userinfo["sub"] as? String, "test-sub")
            XCTAssertEqual(userinfo["name"] as? String, "test-name")
        case .failure(_):
            XCTFail("Should have succeeded")
        }
    }
    
    func testEndSessionShouldEndSessionAndRevokeToken() async throws {
        // First, get an access token
        let result = await oidcClient.token()
        switch result {
        case .success( _):
            break
        case .failure(_):
            XCTFail("Should have succeeded")
        }
        
        // Then, end the session
        let endSessionResult = await oidcClient.endSession()
        XCTAssertTrue(endSessionResult)
        
        // Check that the token is no longer in storage
        let tokenInStorage = try await oidcClientConfig.storage.get()
        XCTAssertNil(tokenInStorage)
        
        let revokeCalled = MockURLProtocol.requestHistory.contains(where: { request in
            request.url?.path == MockAPIEndpoint.revocation.url.path
        })
        
        XCTAssertTrue(revokeCalled, "The /revoke endpoint was not called.")
        
        let signOffCalled = MockURLProtocol.requestHistory.contains(where:  { request in
            request.url?.path == MockAPIEndpoint.endSession.url.path
        })
        XCTAssertTrue(signOffCalled, "The /signoff endpoint was not called.")
    }
    
    func testFailedToRetrieveAccessToken() async throws {
        
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
            case MockAPIEndpoint.token.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.token.url, statusCode: 400, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.tokenErrorResponse)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        let result = await oidcClient.token()
        switch result {
        case .success(_):
            XCTFail("Should have failed with error")
        case .failure(let failure):
            switch failure {
            case .apiError(let code, _):
                XCTAssertEqual(code, 400)
            case .authorizeError, .networkError, .unknown:
                XCTFail("Should have failed with .apiError(400)")
            }
        }
    }
    
    func testFailedToInjectAccessTokenToUserinfo() async throws {
        
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
            case MockAPIEndpoint.token.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.token.url, statusCode: 400, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.tokenErrorResponse)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        let result = await oidcClient.userinfo()
        switch result {
        case .success(_):
            XCTFail("Should have failed with error")
        case .failure(let failure):
            switch failure {
            case .apiError(let code, _):
                XCTAssertEqual(code, 400)
            case .authorizeError, .networkError, .unknown:
                XCTFail("Should have failed with .apiError(400)")
            }
        }
    }
    
    func testFailedToRetrieveUserinfo() async throws {
        
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
            case MockAPIEndpoint.token.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.token.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.token)
            case MockAPIEndpoint.userinfo.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.userinfo.url, statusCode: 401, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.tokenErrorResponse)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        let result = await oidcClient.userinfo()
        switch result {
        case .success(_):
            XCTFail("Should have failed with error")
        case .failure(let failure):
            switch failure {
            case .apiError(let code, _):
                XCTAssertEqual(code, 401)
            case .authorizeError, .networkError, .unknown:
                XCTFail("Should have failed with .apiError(401)")
            }
        }
    }
    
    func testFailedToRefreshTokenAfterTokenExpired() async throws {
        
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
            case MockAPIEndpoint.token.url.path:
               // as httpBody is not available her (it is nil), we will check the `Content-Length` header value to see if the `grant_type` is `refresh_token'
                if Int(request.value(forHTTPHeaderField: "Content-Length")!) == "grant_type=refresh_token&refresh_token=Dummy RefreshToken&client_id=test-client-id".count {
                    return (HTTPURLResponse(url: MockAPIEndpoint.token.url, statusCode: 400, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.tokenErrorResponse)
                } else {
                    return (HTTPURLResponse(url: MockAPIEndpoint.token.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.token)
                }
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        let result = await oidcClient.token()
        switch result {
        case .success( _):  break
        case .failure( _): XCTFail("Should have succeeded")
        }
        
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        let refreshResult = await oidcClient.token()
        switch refreshResult {
        case .success( _):  break
        case .failure( _): XCTFail("Should have succeeded")
        }
        
        let revokeCalled = MockURLProtocol.requestHistory.contains(where: { request in
            request.url?.path == "/revoke"
        })
        
        XCTAssertTrue(revokeCalled, "The /revoke endpoint was not called.")
    }
}
