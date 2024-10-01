// 
//  ConfigurationManager.swift
//  PingExample
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingDavinci

class ConfigurationManager: ObservableObject {
    static let shared = ConfigurationManager()
    public var davinci: DaVinci?
    private var currentConfigurationViewModel: ConfigurationViewModel?
    
    public func loadConfigurationViewModel() -> ConfigurationViewModel {
        if self.currentConfigurationViewModel == nil {
            self.currentConfigurationViewModel = defaultConfigurationViewModel()
        }
        return self.currentConfigurationViewModel!
    }
    
    public func createDavinciWorkflow() {
        if let currentConfiguration = self.currentConfigurationViewModel {
            self.davinci = DaVinci.createDaVinci { config in
                //config.debug = true
                config.module(OidcModule.config) { oidcValue in
                    oidcValue.clientId = currentConfiguration.clientId
                    oidcValue.scopes = Set(currentConfiguration.scopes)
                    oidcValue.redirectUri = currentConfiguration.redirectUri
                    oidcValue.discoveryEndpoint = currentConfiguration.discoveryEndpoint
                }
            }
        }
    }
    
    public func saveConfiguration() {
        if let currentConfiguration = self.currentConfigurationViewModel {
            let encoder = JSONEncoder()
            let configuration = Configuration(clientId: currentConfiguration.clientId, scopes: currentConfiguration.scopes, redirectUri: currentConfiguration.redirectUri, discoveryEndpoint: currentConfiguration.discoveryEndpoint)
            if let encoded = try? encoder.encode(configuration) {
                let defaults = UserDefaults.standard
                defaults.set(encoded, forKey: "CurrentConfiguration")
            }
        }
    }
    
    public func deleteSavedConfiguration() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "CurrentConfiguration")
    }
    
    private func defaultConfigurationViewModel() -> ConfigurationViewModel {
        let defaults = UserDefaults.standard
        if let savedConfiguration = defaults.object(forKey: "CurrentConfiguration") as? Data {
            let decoder = JSONDecoder()
            if let loadedConfiguration = try? decoder.decode(Configuration.self, from: savedConfiguration) {
                return ConfigurationViewModel(clientId: loadedConfiguration.clientId, scopes: loadedConfiguration.scopes, redirectUri: loadedConfiguration.redirectUri, discoveryEndpoint: loadedConfiguration.discoveryEndpoint)
            }
        }
        return ConfigurationViewModel(
            clientId: "[Client ID]",
            scopes: ["openid", "email", "address", "phone", "profile"],
            redirectUri: "[Redirect URI]",
            discoveryEndpoint: "[Discovery Endpoint]"
        )
    }
}

/*
 Example Values (Please create your own application as described in the documentation):
 return ConfigurationViewModel(
     clientId: "10a80cd7-a844-4cdf-b1c6-7dc2ccdb9769",
     scopes: ["openid", "email", "address", "phone", "profile"],
     redirectUri: "org.forgerock.demo://oauth2redirect",
     discoveryEndpoint: "https://auth.pingone.com/5e508bc0-91e7-409b-8514-783bad6d1811/as/.well-known/openid-configuration"
 )
 */
