//
//  DaVinci.swift
//  PingDavinci
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingOrchestrate
import PingOidc

public typealias DaVinci = Workflow
public typealias DaVinciConfig = WorkflowConfig

extension DaVinci {
    public static func createDaVinci(block: (DaVinciConfig) -> Void = {_ in }) -> DaVinci {
        let config = DaVinciConfig()
        config.module(CustomHeader.config) { customHeaderConfig in
            customHeaderConfig.header(name: Request.Constants.xRequestedWith, value: Request.Constants.forgerockSdk)
            customHeaderConfig.header(name: Request.Constants.xRequestedPlatform, value: Request.Constants.ios)
        }
        config.module(NodeTransformModule.config)
        config.module(OidcModule.config)
        config.module(CookieModule.config) { cookieConfig in
            cookieConfig.persist = [Request.Constants.stCookie, Request.Constants.stNoSsCookie]
        }
        
        // Apply custom configuration
        block(config)
        
        return DaVinci(config: config)
    }
}
