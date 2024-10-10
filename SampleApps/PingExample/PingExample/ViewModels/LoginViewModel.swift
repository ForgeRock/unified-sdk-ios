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
import SwiftUI
import Observation

class LoginViewModel: ObservableObject {
    
    @Published public var isLoading: Bool = false
    @ObservedObject var davinciViewModel: DavinciViewModel
    
    init(
         isLoading: Bool = false,
         davinciViewModel: DavinciViewModel) {
       
        self.isLoading = isLoading
        self.davinciViewModel = davinciViewModel
    }
    
    public func next() async {
        isLoading = true
        if let connector = davinciViewModel.data.currentNode as? Connector  {
            await davinciViewModel.next(node: connector)
            isLoading = false
        }
    }
    
}

