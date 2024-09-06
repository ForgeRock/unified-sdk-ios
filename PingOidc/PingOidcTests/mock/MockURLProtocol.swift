//
//  MockURLProtocol.swift
//  PingOidcTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import XCTest
import PingLogger

class MockURLProtocol: URLProtocol {
    public static var requestHistory: [URLRequest] = [URLRequest]()
    
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    
    static func startInterceptingRequests() {
        URLProtocol.registerClass(MockURLProtocol.self)
    }
    
    static func stopInterceptingRequests() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        requestHistory.removeAll()
    }
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        MockURLProtocol.requestHistory.append(request)
        
        guard let handler = MockURLProtocol.requestHandler else {
            XCTFail("Received unexpected request with no handler set")
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {
        
    }
}
