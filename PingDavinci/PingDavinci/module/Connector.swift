//
//  DavinciConnector.swift
//  PingDavinci
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.


import PingOrchestrate

/// Extension to get the id of a Connector.
extension Connector {
    public var id: String {
        return (self as? DaVinciConnector)?.idValue ?? ""
    }
    
    public var name: String {
        return (self as? DaVinciConnector)?.nameValue ?? ""
    }
    
    public var description: String {
        return (self as? DaVinciConnector)?.descriptionValue ?? ""
    }
    
    public var category: String {
        return (self as? DaVinciConnector)?.categoryValue ?? ""
    }
    
}


/// Class representing a DaVinciConnector.
///- property context: The FlowContext of the connector.
///- property workflow: The Workflow of the connector.
///- property input: The input JsonObject of the connector.
///- property collectors: The collectors of the connector.
class DaVinciConnector: Connector {
    
    init(context: FlowContext, workflow: Workflow, input: [String: Any], collectors: Collectors) {
        super.init(context: context, workflow: workflow, input: input, actions: collectors)
    }
    
    /// Function to convert the connector to a dictionary.
    /// - returns: The connector as a JsonObject.
    private func asJson() -> [String: Any] {
        var parameters: [String: Any] = [:]
        if let eventType = collectors.eventType() {
            parameters[Constants.eventType] = eventType
        }
        parameters[Constants.data] = collectors.asJson()
        
        return [
            Constants.id: (input[Constants.id] as? String) ?? "",
            Constants.eventName: (input[Constants.eventName] as? String) ?? "",
            Constants.parameters: parameters
        ]
    }
    
    /// Lazy property to get the id of the connector.
    lazy var idValue: String = {
        return input[Constants.id] as? String ?? ""
    }()
    
    /// Lazy property to get the name of the connector.
    lazy var nameValue: String = {
        guard let form = input[Constants.form] as? [String: Any] else { return "" }
        return form[Constants.name] as? String ?? ""
    }()
    
    /// Lazy property to get the description of the connector.
    lazy var descriptionValue: String = {
        guard let form = input[Constants.form] as? [String: Any] else { return "" }
        return form[Constants.description] as? String ?? ""
    }()
    
    /// Lazy property to get the category of the connector.
    lazy var categoryValue: String = {
        guard let form = input[Constants.form] as? [String: Any] else { return "" }
        return form[Constants.category] as? String ?? ""
    }()
    
    /// Function to convert the connector to a Request.
    /// - Returns: The connector as a Request.
    override func asRequest() -> Request {
        let request = Request()
        
        let links: [String: Any]? = input[Constants._links] as? [String: Any]
        let next = links?[Constants.next] as? [String: Any]
        let href = next?[Constants.href] as? String ?? ""
        
        request.url(href)
        request.header(name: Request.Constants.contentType, value: Request.ContentType.json.rawValue)
        request.body(body: asJson())
        return request
    }
}
