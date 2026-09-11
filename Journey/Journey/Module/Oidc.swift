//
//  Oidc.swift
//  Journey
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOidc
import PingOrchestrate
import PingJourneyPlugin
import PingNetwork
import PingLogger

/// A module that integrates OIDC capabilities into the Journey workflow.
public class OidcModule {
    
    /// Initializes a new instance of `OidcModule`.
    public init() {}
    
    /// The configuration for the OIDC module.
    public static let config: Module<OidcClientConfig> = Module.of ({ OidcClientConfig() }) { setup in
        
        let config: OidcClientConfig = setup.config
        let journeyFlow: Journey = setup.workflow
        
        // Initializes the module.
        setup.initialize {  @Sendable in
            // propagate the configuration from workflow to the module
            config.httpClient = journeyFlow.config.httpClient
            config.logger = journeyFlow.config.logger
            // global context
            journeyFlow.sharedContext.set(key: SharedContext.Keys.oidcClientConfigKey, value: config)
            //Override the agent setting
            config.updateAgent(DefaultAgent())
            // OidcModule is always attached (see Journey.swift), so most Journeys never configure
            // OIDC token exchange and leave both `discoveryEndpoint` and `openId` at their defaults.
            // Only attempt initialization when OIDC has actually been configured for this flow —
            // otherwise `oidcInitialize()` throws `OidcError.configurationError` for a Journey that
            // never intended to use OIDC at all.
            let hasDiscoveryEndpoint = !config.discoveryEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if config.openId != nil || hasDiscoveryEndpoint {
                try await config.oidcInitialize()
            }
        }
        
        // Handles success of the module.
        setup.success { @Sendable context, success in
            // RFC 8628 approving-device: when Journey.start was given a verificationUriComplete,
            // POST user_code + decision=allow back to that URL with the SSO token as cookie.
            // No-op when the key is absent.
            if let uriString = journeyFlow.sharedContext.get(key: SharedContext.Keys.journeyVerificationUriCompleteKey) as? String,
               !uriString.isEmpty {
                // The session value may be empty due to NoSession or re-run existing Journey
                let existingSession: Session = !success.session.value.isEmpty ? success.session : (await journeyFlow.session() ?? success.session)
                if let url = URL(string: uriString),
                   let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let userCode = components.queryItems?.first(where: { $0.name == JourneyConstants.userCode })?.value,
                   !userCode.isEmpty {
                    let approvalConfig: JourneyConfig? = journeyFlow.config as? JourneyConfig
                    let response = try await journeyFlow.config.httpClient.request { request in
                        request.url = uriString
                        request.setHeader(name: approvalConfig?.cookie ?? JourneyConstants.cookie, value: existingSession.value)
                        request.form(parameters: [
                            JourneyConstants.userCode: userCode,
                            JourneyConstants.decision: JourneyConstants.decisionAllow,
                            JourneyConstants.csrf: existingSession.value
                        ])
                    }
                    guard response.status.isSuccess() else {
                        journeyFlow.config.logger.w("Oidc: device approval POST returned non-2xx status: \(response.status)", error: nil)
                        throw OidcError.apiError(code: response.status, message: response.bodyAsString())
                    }
                    journeyFlow.config.logger.i("Oidc: device approval response status: \(response.status)")
                }
            }

            let cloneConfig: OidcClientConfig = config.clone()
            let journeyConfig: JourneyConfig? = journeyFlow.config as? JourneyConfig
            let flowPkce = context.flowContext.get(key: SharedContext.Keys.pkceKey) as? Pkce
            let agent = CreateAgent(session: success.session, pkce: flowPkce, cookieName: journeyConfig?.cookie ?? JourneyConstants.cookie)
            cloneConfig.updateAgent(agent)

            let oidcuser: User = OidcUser(config: cloneConfig)
            let prepareUser = UserDelegate(journey: journeyFlow, user: oidcuser, session: success.session)
            journeyFlow.sharedContext.set(key: SharedContext.Keys.userKey, value: prepareUser)

            return SuccessNode(input: success.input, session: success.session)
        }
        
        // Handles sign off of the module.
        setup.signOff { @Sendable request in
            _ = await OidcClient(config: config).endSession { idToken in
                return true
            }
            
            return request
        }
    }
}

extension SharedContext.Keys {
    /// The key used to store the PKCE value in the shared context.
    static let pkceKey = "com.pingidentity.journey.PKCE"
    
    /// The key used to store the user in the shared context.
    static let userKey = "com.pingidentity.journey.User"
    
    /// The key used to store the OIDC client configuration in the shared context.
    static let oidcClientConfigKey = "com.pingidentity.journey.OidcClientConfig"
    
    /// The shared context key under which `Journey.start` stores the `verificationUriComplete`
    /// URL string. When set, `OidcModule.setup.success` posts approval to that URL after the
    /// user authenticates, completing the RFC 8628 device authorization flow.
    public static let journeyVerificationUriCompleteKey = "com.pingidentity.journey.VerificationUriComplete"
}
