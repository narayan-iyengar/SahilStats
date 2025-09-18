// File: SahilStats/App/SahilStatsApp.swift (Updated)

import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct SahilStatsApp: App {
    @StateObject private var authService = AuthService()
    
    init() {
        // Configure Firebase - moved from AppDelegate
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
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
        }
    }
}

struct SplashView: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "basketball.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }
                
                Text("Sahil's Stats")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
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
            NavigationView {
                GameListView()
            }
            .tabItem {
                Image(systemName: "chart.bar.fill")
                Text("Games")
            }
            
            // Game Setup tab - Admin only
            if authService.showAdminFeatures {
                NavigationView {
                    GameSetupView()
                }
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("New Game")
                }
            }
            
            // Settings tab - Always available
            NavigationView {
                SettingsView()
            }
            .tabItem {
                Image(systemName: "gearshape.fill")
                Text("Settings")
            }
        }
        .accentColor(.orange)
        .sheet(isPresented: $showingAuth) {
            AuthView()
        }
    }
}

// Placeholder views
struct GameSetupView: View {
    var body: some View {
        VStack {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Game Setup")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Create new games and manage live scoring")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .navigationTitle("New Game")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService())
}
