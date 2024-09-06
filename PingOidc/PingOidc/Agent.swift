//
//  Agent.swift
//  PingOidc
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// The `Agent` is a protocol that is used to authenticate and end a session with an OpenID Connect provider.
/// `T` is the configuration object that is used to configure the `Agent`.
public protocol Agent<T> {
     associatedtype T
     
     func config() -> () -> T
     
     /// End the session with the OpenID Connect provider.
     /// Best effort is made to end the session.
     func endSession(oidcConfig: OidcConfig<T>, idToken: String) async throws -> Bool
     
     /// Authorize the `Agent` with the OpenID Connect provider.
     /// Before returning the `AuthCode`, the agent should verify the response from the OpenID Connect provider.
     /// For example, the agent should verify the state parameter in the response.
     /// - Parameter oidcConfig: The configuration for the OpenID Connect client.
     /// - Returns: `AuthCode` instance
     func authorize(oidcConfig: OidcConfig<T>) async throws -> AuthCode
}


/// Allow the `Agent` to run on `OidcConfig` so that it can access the configuration object.
public class OidcConfig<T> {
     let oidcClientConfig: OidcClientConfig
     let config: T
     
     public init(oidcClientConfig: OidcClientConfig, config: T) {
          self.oidcClientConfig = oidcClientConfig
          self.config = config
     }
}

public class DefaultAgent: Agent {
     
     public typealias T = Void
     
     public init() {}
     
     public func config() -> () -> Void {
          return {}
     }
     
     public func endSession(oidcConfig: OidcConfig<Void>, idToken: String) async -> Bool {
          return false
     }
     
     public func authorize(oidcConfig: OidcConfig<Void>) async throws -> AuthCode {
          throw OidcError.authorizeError(message: "No AuthCode is available.")
     }
}

public protocol AgentDelegateProtocol {
     associatedtype T
     func authenticate() async throws -> AuthCode
     func endSession(idToken: String) async throws -> Bool
}

/// Delegate class to dispatch `Agent` functions
public class AgentDelegate<T: Any>: AgentDelegateProtocol  {
     let agent: any Agent<T>
     let oidcConfig: OidcConfig<T>
     
     init(agent: any Agent<T>, agentConfig: T, oidcClientConfig: OidcClientConfig) {
          self.agent = agent
          self.oidcConfig = OidcConfig(oidcClientConfig: oidcClientConfig, config: agentConfig)
     }
     
     public func authenticate() async throws -> AuthCode {
          return try await self.agent.authorize(oidcConfig: oidcConfig)
     }
     
     public func endSession(idToken: String) async throws -> Bool {
          return try await agent.endSession(oidcConfig: oidcConfig, idToken: idToken)
     }
     
}
