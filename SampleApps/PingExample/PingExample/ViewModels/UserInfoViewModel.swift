// 
//  UserInfoViewModel.swift
//  PingExample
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingLogger

class UserInfoViewModel: ObservableObject {
    
    @Published var userInfo: String = ""
    
    init() {
        Task {
            await fetchUserInfo()
        }
    }
    
    func fetchUserInfo() async {
        let userInfo = await ConfigurationManager.shared.davinci?.user()?.userinfo(cache: false)
        switch userInfo {
        case .success(let userInfoDictionary):
            await MainActor.run {
                var userInfoDescription = ""
                userInfoDictionary.forEach { userInfoDescription += "\($0): \($1)\n" }
                self.userInfo = userInfoDescription
            }
            LogManager.standard.i("UserInfo: \(String(describing: self.userInfo))")
        case .failure(let error):
            await MainActor.run {
                self.userInfo = "Error: \(error.localizedDescription)"
            }
            LogManager.standard.e("", error: error)
        case .none:
            await MainActor.run {
                self.userInfo = "Error: Userinfo nil, need to log in"
            }
        }
    }
}
