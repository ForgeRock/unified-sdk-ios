// 
//  DavinciView.swift
//  PingExample
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingOrchestrate
import PingDavinci

struct DavinciView: View {
    
    @StateObject var viewmodel = DavinciViewModel()
    @Binding var path: [String]
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack {
                    Spacer()
                    switch viewmodel.data.currentNode {
                    case let connector as Connector:
                        ConnectorView(viewmodel: viewmodel, connector: connector)
                    case is SuccessNode:
                        VStack{}.onAppear {
                            path.removeLast()
                            path.append("Token")
                        }
                    case let errorNode as ErrorNode:
                        if let connector = viewmodel.data.previousNode as? Connector {
                            ConnectorView(viewmodel: viewmodel, connector: connector)
                        }
                        ErrorView(name: errorNode.cause.localizedDescription)
                    case let failureNode as FailureNode:
                        if let connector = viewmodel.data.previousNode as? Connector {
                            ConnectorView(viewmodel: viewmodel, connector: connector)
                        }
                        ErrorView(name: failureNode.message)
                    default:
                        EmptyView()
                    }
                }
            }
            
            Spacer()
            
            // Activity indicator
            if viewmodel.isLoading {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(4) // Increase spinner size if needed
                    .foregroundColor(.white) // Set spinner color
            }
        }
    }
}
