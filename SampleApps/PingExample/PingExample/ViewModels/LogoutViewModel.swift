// 
//  LogoutViewModel.swift
//  PingExample
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

class LogoutViewModel: ObservableObject {
    
    @Published var logout: String = ""
    
    func logout() async {
        //TODO: Integration Point. STEP 8
        /*
         Use the ConfigurationManager shared class to retrieve the davinci class reference.
         When wanting to logout the user, you need to call `user()?.logout()`.
         
         Example use: "await ConfigurationManager.shared.davinci?.user()?.logout()"
         */
        
        await MainActor.run {
            logout =  "Logout completed"
        }
    
    }
}
