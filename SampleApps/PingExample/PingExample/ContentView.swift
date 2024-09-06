import SwiftUI


struct ContentView: View {

  
  @State private var startDavinici = false
  
  @State private var path: [String] = []
  
  var body: some View {
    NavigationStack(path: $path) {
      List {
        NavigationLink(value: "Davinci") {
          Text("Launch Davinci")
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
        
        NavigationLink(value: "Logger") {
          Text("Logger")
        }
        NavigationLink(value: "Storage") {
          Text("Storage")
        }
      }.navigationDestination(for: String.self) { item in
        switch item {
        case "Davinci":
          DavinciView(path: $path)
        case "Token":
          AccessTokenView()
        case "User":
          UserInfoView()
        case "Logout":
          LogOutView(path: $path)
        case "Logger":
          LoggerView()
        case "Storage":
          StorageView()
        default:
          EmptyView()
        }
      }.navigationBarTitle("Ping Davinci")
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
        path.append("Davinci")
      }
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
