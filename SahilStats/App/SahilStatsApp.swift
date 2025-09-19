// File: SahilStats/App/SahilStatsApp.swift (Fixed for iPad)

import SwiftUI
import FirebaseCore
import FirebaseAuth


@main
struct SahilStatsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authService = AuthService()
    
    init() {
        // Configure Firebase
        FirebaseApp.configure()
        
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .onAppear {
                    AppDelegate.orientationLock = .portrait
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
            }
        }
        .sheet(isPresented: $showingAuth) {
            AuthView()
        }
        .onChange(of: authService.isSignedIn) { oldValue, newValue in
            // Handle auth state changes if needed
            if !newValue && !authService.isLoading {
                // User signed out, you might want to show a message or take other actions
            }
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
            // Dashboard tab - Always available
            // Use NavigationStack instead of NavigationView for iOS 16+
            if #available(iOS 16.0, *) {
                NavigationStack {
                    GameListView()
                }
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Games")
                }
            } else {
                NavigationView {
                    GameListView()
                        .navigationViewStyle(StackNavigationViewStyle()) // Force stack style on iPad
                }
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Games")
                }
            }
            
            // Game Setup tab - Admin only
            if authService.showAdminFeatures {
                if #available(iOS 16.0, *) {
                    NavigationStack {
                        GameSetupView()
                    }
                    .tabItem {
                        Image(systemName: "plus.circle.fill")
                        Text("New Game")
                    }
                } else {
                    NavigationView {
                        GameSetupView()
                            .navigationViewStyle(StackNavigationViewStyle()) // Force stack style on iPad
                    }
                    .tabItem {
                        Image(systemName: "plus.circle.fill")
                        Text("New Game")
                    }
                }
            }
            
            // Settings tab - Always available
            if #available(iOS 16.0, *) {
                NavigationStack {
                    SettingsView()
                }
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
            } else {
                NavigationView {
                    SettingsView()
                        .navigationViewStyle(StackNavigationViewStyle()) // Force stack style on iPad
                }
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
            }
        }
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
