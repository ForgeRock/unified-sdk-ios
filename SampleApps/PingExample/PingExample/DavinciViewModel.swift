//
//  DavinciViewModel.swift
//  PingExample
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingDavinci
import PingOidc
import PingOrchestrate


public let davinciStage = DaVinci.createDaVinci { config in
  //config.debug = true
  
  config.module(OidcModule.config) { oidcValue in
    oidcValue.clientId = "3172d977-8fdc-4e8b-b3c5-4f3a34cb7262"
    oidcValue.scopes = ["openid", "email", "address", "phone", "profile"]
    oidcValue.redirectUri = "org.forgerock.demo://oauth2redirect"
    oidcValue.discoveryEndpoint = "https://auth.test-one-pingone.com/0c6851ed-0f12-4c9a-a174-9b1bf8b438ae/as/.well-known/openid-configuration"
  }
}

public let davinciTest = DaVinci.createDaVinci { config in
  //config.debug = true
  
  config.module(OidcModule.config) { oidcValue in
    oidcValue.clientId = "c12743f9-08e8-4420-a624-71bbb08e9fe1"
    oidcValue.scopes = ["openid", "email", "address", "phone", "profile"]
    oidcValue.redirectUri = "org.forgerock.demo://oauth2redirect"
    oidcValue.discoveryEndpoint = "https://auth.pingone.ca/02fb4743-189a-4bc7-9d6c-a919edfe6447/as/.well-known/openid-configuration"
  }
}

public let davinciProd = DaVinci.createDaVinci { config in
  //config.debug = true
  
  config.module(OidcModule.config) { oidcValue in
    oidcValue.clientId = "9a452a38-0db8-4864-b9b8-11ff5edae99b"
    oidcValue.scopes = ["openid", "email", "address", "phone", "profile"]
    oidcValue.redirectUri = "org.forgerock.demo://oauth2redirect"
    oidcValue.discoveryEndpoint = "https://auth.pingone.com/4b69e4ad-03bd-4203-89bb-0504221d9a1c/as/.well-known/openid-configuration"
  }
}

// Change this to Prod/Stage
public let davinci = davinciTest

class DavinciViewModel: ObservableObject {
  
  @Published public var data: StateNode = StateNode()
  
  @Published public var isLoading: Bool = false
  
  init() {
    
    Task {
      await startDavinci()
    }
  }
  
  
  private func startDavinci() async {
    
    await MainActor.run {
      isLoading = true
    }
    
    let node = await davinci.start()
    
    await MainActor.run {
      self.data = StateNode(currentNode: node, previousNode: node)
      isLoading = false
    }
    
  }
  
  public func next(node: Node) async {
    await MainActor.run {
      isLoading = true
    }
    if let nextNode = node as? ContinueNode {
      let next = await nextNode.next()
      await MainActor.run {
        self.data = StateNode(currentNode: next, previousNode: node)
        isLoading = false
      }
    }
  }
}

class StateNode {
  var currentNode: Node? = nil
  var previousNode: Node? = nil
  
  init(currentNode: Node?  = nil, previousNode: Node? = nil) {
    self.currentNode = currentNode
    self.previousNode = previousNode
  }
}
