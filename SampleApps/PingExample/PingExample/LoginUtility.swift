//
//  LoginView.swift
//  PingDavinci
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import SwiftUI

struct LogoView: View {
    var body: some View {
        Image(systemName: "person.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 100, height: 100)
            .foregroundColor(.blue)
    }
}

struct UsernameTextField: View {
    
    @Binding var username: String
    
    var body: some View {
        TextField("Username", text: $username)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .autocapitalization(.none) // Set autocapitalization to none
            .padding()
    }
}

struct PasswordTextField: View {
    @Binding var password: String
    
    var body: some View {
        SecureField("Password", text: $password)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .autocapitalization(.none) // Set autocapitalization to none
            .padding()
    }
}

struct LoginButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text("Login")
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
    }
}

struct HavingTrouble: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text("Having Trouble Loggin In")
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
    }
}

struct RegisterNow: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text("Register now")
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
    }
}


