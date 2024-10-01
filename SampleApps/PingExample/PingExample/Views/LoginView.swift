//
//  LoginView.swift
//  PingExample
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import SwiftUI
import PingOrchestrate
import PingDavinci

struct ConnectorView: View {
    
    @ObservedObject var viewmodel: DavinciViewModel
    public var connector: Connector
    
    var body: some View {
        VStack {
            Image("Logo").resizable().scaledToFill().frame(width: 100, height: 100)
                .padding(.vertical, 32)
            HeaderView(name: connector.name)
            LoginView(
                davinciViewModel: viewmodel,
                connector: connector, collectorsList: connector.collectors)
        }
    }
}

struct ErrorView: View {
    var name: String = ""
    
    var body: some View {
        VStack {
            Text("Oops! Something went wrong.\(name)")
                .foregroundColor(.red).padding(.top, 20)
        }
    }
}

struct HeaderView: View {
    var name: String = ""
    var body: some View {
        VStack {
            Text(name)
                .font(.title)
        }
    }
}

struct LoginView: View {
    // MARK: - Propertiers
    @ObservedObject var davinciViewModel: DavinciViewModel
    
    public var connector: Connector
    
    public var collectorsList: Collectors
    
    // MARK: - View
    var body: some View {
        
        VStack {
            
            ForEach(collectorsList, id: \.id) { field in
                
                VStack {
                    /*
                     Add integration to present fields
                     */
                    if let text = field as? TextCollector {
                        InputView(text: text.value, placeholderString: text.label, field: text)
                    }
                    
                    if let password = field as? PasswordCollector {
                        InputView(placeholderString: password.label, secureField: true, field: password)
                    }
                    
                    if let submitButton = field as? SubmitCollector {
                        InputButton(title: submitButton.label, field: submitButton) {
                            Task {
                                /*
                                 Call next
                                 */
                                await davinciViewModel.next(node: connector)
                            }
                        }
                    }
                    
                }.padding(.horizontal, 5).padding(.top, 20)
                
                
                if let flowButton = field as? FlowCollector {
                    Button(action: {
                        flowButton.value = "action"
                        Task {
                            await davinciViewModel.next(node: connector)
                        }
                    }) {
                        Text(flowButton.label)
                            .foregroundColor(.black)
                    }
                }
            }
        }
    }
}

