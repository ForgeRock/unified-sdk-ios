// 
//  LoggerView.swift
//  PingExample
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI

struct LoggerView: View {
    var loggerViewModel = LoggerViewModel()
    var body: some View {
        Text("This View is for testing Logger functionality.\nPlease check the Console Logs")
            .font(.title3)
            .multilineTextAlignment(.center)
            .navigationBarTitle("Logger", displayMode: .inline)
            .onAppear() {
                loggerViewModel.setupLogger()
            }
    }
}
