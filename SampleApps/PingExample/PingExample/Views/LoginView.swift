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
            //TODO: Integration Point. STEP 5
            /*
             At this point the DaVinci flow has returned Collectors to present.
             As a developer you will need to go though the returned collectors (`collectorsList` in this case)
             and build your view. Notice that Flows, similar to PingAM Journeys can be dynamic and you views
             will need to adapt to what the server sends.
             
             As mentioned on previous steps the `Connector` object contains a list of `Collectors`. Those `Collectors`
             contain input and outputs. In this ViewModel, a conviniece property to access the collectors directly has been set up.
             
             To use this loop through the `collectorsList` and create `InputViews` for each collector based on its type.
             The SDK at the moment supports the following collectors returned from DaVinci through the use of an HTML Connector:
             1. `TextCollector`
             2. `PasswordCollector`
             3. `SubmitCollector`
             4. `FlowCollector`
             
             Example for `TextCollector`:
             if let text = field as? TextCollector {
                 InputView(text: text.value, placeholderString: text.label, field: text)
             }
             
             Example for `PasswordCollector`
             if let password = field as? PasswordCollector {
                 InputView(placeholderString: password.label, secureField: true, field: password)
             }
             
             Example for `SubmitCollector`
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
             
             If the type is `FlowCollector` you will need to submit to DaVinci by calling `.next()`
             Example:
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
            */
            ForEach(collectorsList, id: \.id) { field in
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

