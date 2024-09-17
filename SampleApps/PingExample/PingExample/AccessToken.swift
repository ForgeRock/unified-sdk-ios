//
//  AccessToken.swift
//  PingExample
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI

struct AccessTokenView: View {
    
    @Binding var path: [String]
    
    @StateObject var tokenViewModel = TokenViewModel()
    
    var body: some View {
        VStack {
            
            TextEditor(text: $tokenViewModel.accessToken)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .navigationTitle("AccessToken")
            NextButton(title: "Procced to logout") {
                Task {
                    await ConfigurationManager.shared.davinci?.user()?.logout()
                    path.removeLast()
                }
            }
        }
        
        
    }
}

struct UserInfoView: View {
    @Binding var path: [String]
    
    @StateObject var vm = UserInfoViewModel()
    
    var body: some View {
        
        TextEditor(text: $vm.userInfo)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .navigationTitle("User Info")
        
        NextButton(title: "Procced to logout") {
            Task {
                await ConfigurationManager.shared.davinci?.user()?.logout()
                path.removeLast()
            }
        }
    }
}
