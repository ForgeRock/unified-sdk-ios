import SwiftUI


struct ContentView: View {
    
    
    @State private var startDavinici = false
    
    @State private var path: [String] = []
    
    @State private var configurationViewModel: ConfigurationViewModel = ConfigurationManager.shared.loadConfigurationViewModel()
    
    var body: some View {
        NavigationStack(path: $path) {
            List {
                NavigationLink(value: "Configuration") {
                    Text("Edit configuration")
                }
                NavigationLink(value: "DaVinci") {
                    Text("Launch DaVinci")
                }
                NavigationLink(value: "Token") {
                    Text("Access Token")
                }
                NavigationLink(value: "User") {
                    Text("User Info")
                }
                NavigationLink(value: "Logout") {
                    Text("Logout")
                }
            }.navigationDestination(for: String.self) { item in
                switch item {
                case "Configuration":
                    ConfigurationView(viewmodel: $configurationViewModel)
                case "DaVinci":
                    DavinciView(path: $path)
                case "Token":
                    AccessTokenView(path: $path)
                case "User":
                    UserInfoView(path: $path)
                case "Logout":
                    LogOutView(path: $path)
                default:
                    EmptyView()
                }
            }.navigationBarTitle("Ping DaVinci")
            Image(uiImage: UIImage(named: "Logo")!)
                .resizable()
                .frame(width: 180.0, height: 180.0).clipped()
        }.onAppear{
            ConfigurationManager.shared.createDavinciWorkflow()
        }
    }
}


struct LogOutView: View {
    
    @Binding var path: [String]
    
    @StateObject private var viewmodel =  LogOutViewModel()
    
    var body: some View {
        
        Text("Logout")
            .font(.title)
            .navigationBarTitle("Logout", displayMode: .inline)
        
        NextButton(title: "Procced to logout") {
            Task {
                await viewmodel.logout()
                path.removeLast()
            }
        }
        
    }
}

struct ConfigurationView: View {
    @Binding var viewmodel: ConfigurationViewModel
    @State private var scopes: String = ""
    
    var body: some View {
        Form {
            Section {
                Text("Client Id:")
                TextField("Client Id", text: $viewmodel.clientId)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
            }
            Section {
                Text("Redirect URI:")
                TextField("Redirect URI", text: $viewmodel.redirectUri)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
            }
            Section {
                Text("Discovery Endpoint:")
                TextField("Discovery Endpoint", text: $viewmodel.discoveryEndpoint)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
            }
            Section {
                Text("Scopes:")
                TextField("scopes:", text: $scopes)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
            }
        }
        .navigationTitle("Edit Configuration")
        .onAppear{
            scopes = $viewmodel.scopes.wrappedValue.joined(separator: ",")
        }
        .onDisappear{
            viewmodel.scopes = scopes.components(separatedBy: ",")
            ConfigurationManager.shared.saveConfiguration()
        }
    }
}

struct SecondTabView: View {
    var body: some View {
        Text("LogOut")
            .font(.title)
            .navigationBarTitle("LogOut", displayMode: .inline)
        
    }
}

struct Register: View {
    var body: some View {
        Text("Register")
            .font(.title)
            .navigationBarTitle("Register", displayMode: .inline)
    }
}

struct ForgotPassword: View {
    var body: some View {
        Text("ForgotPassword")
            .font(.title)
            .navigationBarTitle("ForgotPassword", displayMode: .inline)
    }
}

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

struct StorageView: View {
    var storageViewModel = StorageViewModel()
    var body: some View {
        Text("This View is for testing Storage functionality.\nPlease check the Console Logs")
            .font(.title3)
            .multilineTextAlignment(.center)
            .navigationBarTitle("Storage", displayMode: .inline)
            .onAppear() {
                Task {
                    await storageViewModel.setupMemoryStorage()
                    await storageViewModel.setupKeychainStorage()
                }
            }
    }
}

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ActivityIndicatorView: View {
    @Binding var isAnimating: Bool
    let style: UIActivityIndicatorView.Style
    let color: Color
    
    var body: some View {
        if isAnimating {
            VStack {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: color))
                    .padding()
                Spacer()
            }
            .background(Color.black.opacity(0.4).ignoresSafeArea())
        }
    }
}
