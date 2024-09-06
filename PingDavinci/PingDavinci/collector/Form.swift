//
//  Form.swift
//  PingDavinci
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// Class that handles the parsing and JSON representation of collectors.
/// This class provides functions to parse a JSON object into a list of collectors and to represent a list of collectors as a JSON object.
class Form {
    
    /// Parses a JSON object into a list of collectors.
    ///  This function takes a JSON object and extracts the "form" field. It then iterates over the "fields" array in the "components" object,
    ///  parsing each field into a collector and adding it to a list.
    ///  - Parameter json :The JSON object to parse.
    ///  - Returns:  A list of collectors parsed from the JSON object.
    static func parse(json: [String: Any]) -> Collectors {
        var collectors = Collectors()
        if let form = json[Constants.form] as? [String: Any],
           let components = form[Constants.components] as? [String: Any],
           let fields = components[Constants.fields] as? [[String: Any]] {
            collectors = CollectorFactory().collector(from: fields)
        }
        return collectors
    }
}
