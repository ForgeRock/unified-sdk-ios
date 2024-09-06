//
//  Transform.swift
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

/// Module for transforming the response from DaVinci to `Node`.
public class NodeTransformModule {
    
    public static let config: Module<Void> = Module.of(setup: { setup in
        setup.transform { flowContext, response in
            switch response.status() {
            case 400:
                return failure(json: try response.json(data: response.data))
            case 200:
                return transform(context: flowContext, workflow: setup.workflow, json: try response.json(data: response.data))
            default:
                return ErrorNode(cause: ApiError.error(response.status(), response.body()))
            }
        }
    })
    
    private static func failure(json: [String: Any]) -> FailureNode {
        let message = json[Constants.message] as? String ?? ""
        return FailureNode(input: json, message: message)
    }
    
    private static func transform(context: FlowContext, workflow: Workflow, json: [String: Any]) -> Node {
        // If status is FAILED, return error
        if let status = json[Constants.status] as? String, status == Constants.FAILED {
            return ErrorNode(cause: ApiError.error(200, json.description))
        }
        
        // If authorizeResponse is present, return success
        if let _ = json[Constants.authorizeResponse] as? [String: Any] {
            return SuccessNode(input: json, session: SessionResponse(json: json))
        }
        
        var collectors: Collectors = []
        if let _ = json[Constants.form] {
            collectors.append(contentsOf: Form.parse(json: json))
        }
        
        return DaVinciConnector(context: context, workflow: workflow, input: json, collectors: collectors)
    }
}

struct SessionResponse: Session {
    public let json: [String: Any]
    
    public init(json: [String: Any] = [:]) {
        self.json = json
    }
    
    func value() -> String {
        let authResponse = json[Constants.authorizeResponse] as? [String: Any]
        return authResponse?[Constants.code] as? String ?? ""
    }
}

public enum ApiError: Error {
    case error(Int, String)
}
