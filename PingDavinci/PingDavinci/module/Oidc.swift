//
//  OIDC.swift
//  PingDavinci
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingOidc
import PingOrchestrate

public actor OidcModule {
    
    public init() {}
    
    public static let config: Module<OidcClientConfig> = Module.of ({ OidcClientConfig() }) { setup in
        
        let config: OidcClientConfig = setup.config
        let daVinciFlow: DaVinci = setup.workflow
        
        // Initializes the module.
        setup.initialize {
            // propagate the configuration from workflow to the module
            config.httpClient = daVinciFlow.config.httpClient
            config.logger = daVinciFlow.config.logger
            // global context
            daVinciFlow.sharedContext.set(key: SharedContext.Keys.oidcClientConfigKey, value: config)
            //Override the agent setting
            config.updateAgent(DefaultAgent())
            try await config.oidcInitialize()
        }
        
        // Starts the module.
        setup.start { context, request in
            // When user starts the flow again, revoke previous token if exists
            await daVinciFlow.user()?.revoke()
            
            let pkce = Pkce.generate()
            context.flowContext.set(key: SharedContext.Keys.pkceKey, value: pkce)
            return config.populateRequest(request: request, pkce: pkce)
        }
        
        // Handles success of the module.
        setup.success { context, success in
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
        setup.signOff { request in
            request.url(config.openId?.endSessionEndpoint ?? "")
            
            _ = await OidcClient(config: config).endSession { idToken in
                request.parameter(name: OidcClient.Constants.id_token_hint, value: idToken)
                request.parameter(name: OidcClient.Constants.client_id, value: config.clientId)
                return true
            }
            
            return request
        }
    }
}

extension SharedContext.Keys {
    public static let pkceKey = "com.pingidentity.davinci.PKCE"
    public static let userKey = "com.pingidentity.davinci.User"
    public static let oidcClientConfigKey = "com.pingidentity.davinci.OidcClientConfig"
}
