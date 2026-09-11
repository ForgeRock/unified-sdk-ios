//
//  Oidc.swift
//  PingDavinci
//
//  Copyright (c) 2024 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingOidc
import PingOrchestrate
import PingNetwork
import PingLogger

/// A module that integrates OIDC capabilities into the DaVinci workflow.
public class OidcModule {
    
    /// Initializes a new instance of `OidcModule`.
    public init() {}
    
    /// The configuration for the OIDC module.
    public static let config: Module<OidcClientConfig> = Module.of ({ OidcClientConfig() }) { setup in
        
        let config: OidcClientConfig = setup.config
        let daVinciFlow: DaVinci = setup.workflow
        
        // Initializes the module.
        setup.initialize {  @Sendable in
            // propagate the configuration from workflow to the module
            config.httpClient = daVinciFlow.config.httpClient
            config.logger = daVinciFlow.config.logger
            // global context
            daVinciFlow.sharedContext.set(key: SharedContext.Keys.oidcClientConfigKey, value: config)
            //Override the agent setting
            config.updateAgent(DefaultAgent())
            // OidcModule is always attached (see DaVinci.swift), so most DaVinci flows never
            // configure OIDC token exchange and leave both `discoveryEndpoint` and `openId` at
            // their defaults. Only attempt initialization when OIDC has actually been configured
            // for this flow — otherwise `oidcInitialize()` throws `OidcError.configurationError`
            // for a flow that never intended to use OIDC at all.
            let hasDiscoveryEndpoint = !config.discoveryEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if config.openId != nil || hasDiscoveryEndpoint {
                try await config.oidcInitialize()
            }
        }
        
        // Starts the module.
        setup.start { @Sendable context, request in
            
            // Check for Device Flow
            if let uriString = daVinciFlow.sharedContext.get(key: SharedContext.Keys.daVinciVerificationUriCompleteKey) as? String,
               let url = URL(string: uriString),
               let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let userCode = components.queryItems?.first(where: { $0.name == OidcClient.Constants.userCodeSnake })?.value,
               !userCode.isEmpty {
                // Move key from sharedContext (workflow-scoped) into flowContext (this invocation only)
                // so success can detect the device-flow path, and a subsequent start() is unaffected.
                _ = daVinciFlow.sharedContext.removeValue(forKey: SharedContext.Keys.daVinciVerificationUriCompleteKey)
                context.flowContext.set(key: SharedContext.Keys.daVinciVerificationUriCompleteKey, value: uriString)
                config.logger.d( "Oidc: device code completion flow detected, skipping authorization request")
                return try config.populateDeviceFlowVerificationRequest(request: request, userCode: userCode)
            }
            
            
            // When user starts the flow again, revoke previous token if exists
            await daVinciFlow.daVinciUser()?.revoke()
            
            let pkce = Pkce.generate()
            context.flowContext.set(key: SharedContext.Keys.pkceKey, value: pkce)
            return try await config.populateRequest(request: request, pkce: pkce)
        }
        
        // Handles success of the module.
        setup.success { @Sendable context, success in
            
            // Device-code completion flow: token exchange already handled externally, skip.
            // The key was moved into flowContext by start; sharedContext key was already consumed there.
            if context.flowContext.get(key: SharedContext.Keys.daVinciVerificationUriCompleteKey) != nil {
                return SuccessNode(input: success.input, session: success.session)
            }
            
            let cloneConfig: OidcClientConfig = config.clone()
            
            let flowPkce = context.flowContext.get(key: SharedContext.Keys.pkceKey) as? Pkce
            let agent = CreateAgent(session: success.session, pkce: flowPkce)
            cloneConfig.updateAgent(agent)
            
            let oidcuser: User = OidcUser(config: cloneConfig)
            let prepareUser = UserDelegate(daVinci: daVinciFlow, user: oidcuser, session: success.session)
            daVinciFlow.sharedContext.set(key: SharedContext.Keys.userKey, value: prepareUser)
            
            return SuccessNode(input: success.input, session: prepareUser)
        }
        
        // Handles sign off of the module.
        setup.signOff { @Sendable request in
            request.url = config.openId?.endSessionEndpoint ?? ""
            
            _ = await OidcClient(config: config).endSession { idToken in
                request.setParameter(name: OidcClient.Constants.id_token_hint, value: idToken)
                request.setParameter(name: OidcClient.Constants.client_id, value: config.clientId)
                return true
            }
            
            return request
        }
    }
}

extension SharedContext.Keys {
    /// The key used to store the PKCE value in the shared context.
    public static let pkceKey = "com.pingidentity.davinci.PKCE"
    
    /// The key used to store the user in the shared context.
    public static let userKey = "com.pingidentity.davinci.User"
    
    /// The key used to store the OIDC client configuration in the shared context.
    public static let oidcClientConfigKey = "com.pingidentity.davinci.OidcClientConfig"
    
    /// The shared context key under which the `verificationUriComplete` URL string is stored
    /// for the DaVinci device authorization flow.
    public static let daVinciVerificationUriCompleteKey = "com.pingidentity.davinci.VerificationUriComplete"
}
