//
//  OidcClientConfig.swift
//  PingOidc
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingOrchestrate
import PingLogger
import PingStorage

public class OidcClientConfig {
    public var openId: OpenIdConfiguration?
    public var refreshThreshold: Int64 = 0
    
    internal var agent: (any AgentDelegateProtocol)?
    
    public var logger: Logger
    public var storage: StorageDelegate<Token>
    public var discoveryEndpoint = ""
    public var clientId = ""
    public var scopes = Set<String>()
    public var redirectUri = ""
    public var loginHint: String?
    public var state: String?
    public var nonce: String?
    public var display: String?
    public var prompt: String?
    public var uiLocales: String?
    public var acrValues: String?
    public var additionalParameters = [String: String]()
    public var httpClient: HttpClient?
    
    public init() {
        logger = LogManager.none
        storage = KeychainStorage<Token>(account: "ACCESS_TOKEN_STORAGE", encryptor: SecuredKeyEncryptor() ?? NoEncryptor(), cacheable: true)
    }
    
    public func scope(_ scope: String) {
        scopes.insert(scope)
    }
    
    public func updateAgent<T: Any>(_ agent: any Agent<T>, config: (T) -> Void = {_ in }) {
        self.agent = AgentDelegate<T>(agent: agent, agentConfig: agent.config()(), oidcClientConfig: self)
        
    }
    
    /// Initialize the lazy init properties to default
    public func oidcInitialize() async throws   {
        if httpClient == nil {
            httpClient = HttpClient()
        }
    
        if openId != nil {
            return
        }
        
        openId = try await discover()
    }
    
    private func discover() async throws -> OpenIdConfiguration?  {
        guard URL(string: discoveryEndpoint) != nil else {
            logger.e("Invalid Discovery URL", error: nil)
            return nil
        }
        
        guard let httpClient else {
            logger.e("Invalid Http Clinet URL", error: nil)
            return nil
        }
        let request = Request()
        request.url(discoveryEndpoint)
        let (data, response) = try await httpClient.sendRequest(request: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OidcError.apiError(code: (response as? HTTPURLResponse)?.statusCode ?? 500, message: String(decoding: data, as: UTF8.self))
        }
        let configuration = try JSONDecoder().decode(OpenIdConfiguration.self, from: data)
        return configuration
    }
    
    public func clone() -> OidcClientConfig {
        let cloned = OidcClientConfig()
        cloned.update(with: self)
        return cloned
    }
    
    func update(with other: OidcClientConfig) {
        self.openId = other.openId
        self.agent = other.agent
        self.logger = other.logger
        self.storage = other.storage
        self.discoveryEndpoint = other.discoveryEndpoint
        self.clientId = other.clientId
        self.scopes = other.scopes
        self.redirectUri = other.redirectUri
        self.loginHint = other.loginHint
        self.state = other.state
        self.nonce = other.nonce
        self.display = other.display
        self.prompt = other.prompt
        self.uiLocales = other.uiLocales
        self.acrValues = other.acrValues
        self.additionalParameters = other.additionalParameters
        self.httpClient = other.httpClient
    }
}
