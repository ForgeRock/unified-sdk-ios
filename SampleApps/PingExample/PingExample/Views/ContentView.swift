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
                    LogoutView(path: $path)
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

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
