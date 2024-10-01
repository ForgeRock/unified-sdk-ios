//
//  TokenViewModel.swift
//  PingExample
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingLogger

class TokenViewModel: ObservableObject {
    
    @Published var accessToken: String = ""
    
    init() {
        Task {
            await accessToken()
        }
    }
    
    func accessToken() async {
        let token = await ConfigurationManager.shared.davinci?.user()?.token()
        switch token {
        case .success(let accessToken):
            await MainActor.run {
                self.accessToken = String(describing: accessToken)
            }
            LogManager.standard.i("AccessToken: \(self.accessToken)")
        case .failure(let error):
            await MainActor.run {
                self.accessToken = "Error: \(error.localizedDescription)"
            }
            LogManager.standard.e("", error: error)
        case .none:
            await MainActor.run {
                self.accessToken = "Error: Token nil, need to log in"
            }
        }

    }
}
