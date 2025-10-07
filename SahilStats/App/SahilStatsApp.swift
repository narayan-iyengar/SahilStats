// File: SahilStats/App/SahilStatsApp.swift (Fixed for iPad)

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import Network

@main
struct SahilStatsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authService = AuthService()
    
    init() {
        FirebaseApp.configure()
        let settings = FirestoreSettings()
        settings.cacheSettings = MemoryCacheSettings()
        Firestore.firestore().settings = settings
        UITabBar.appearance().itemPositioning = .centered
        _ = WifiNetworkMonitor.shared
        _ = YouTubeUploadManager.shared
        _ = LiveGameManager.shared // Initialize the new manager
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .onAppear {
                    AppDelegate.orientationLock = .portrait
                    _ = FirebaseYouTubeAuthManager.shared
                }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingAuth = false

    var body: some View {
        Group {
            if authService.isLoading {
                SplashView()
            } else {
                MainTabView()
                    .environmentObject(authService)
            }
        }
        .sheet(isPresented: $showingAuth) {
            AuthView()
        }
    }
}

struct SplashView: View {
    @State private var rotation: Double = 0
    @State private var scale: Double = 1.0
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "basketball.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                    .rotationEffect(.degrees(rotation))
                    .scaleEffect(scale)
                    .onAppear {
                        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                            scale = 1.1
                        }
                    }
                
                Text("Sahil's Stats")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                
                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingAuth = false
    
    var body: some View {
        TabView {
            NavigationView {
                GameListView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Image(systemName: "chart.bar.fill")
                Text("Games")
            }
            
            if authService.showAdminFeatures {
                NavigationView {
                    GameSetupView()
                }
                .navigationViewStyle(.stack)
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("New Game")
                }
            }
            
            NavigationView {
                SettingsView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Image(systemName: "gearshape.fill")
                Text("Settings")
            }
        }
        .environment(\.horizontalSizeClass, .compact)
        .accentColor(.orange)
        .sheet(isPresented: $showingAuth) {
            AuthView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService())
}

class AppDelegate: UIResponder, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.all

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}
