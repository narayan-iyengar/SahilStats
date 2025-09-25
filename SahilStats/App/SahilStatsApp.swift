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
        UITabBar.appearance().itemPositioning = .centered
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

// Fixed MainTabView with consistent icons for both iPhone and iPad


struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingAuth = false
    
    var body: some View {
        TabView {
            // MARK: - Games Tab
            NavigationView {
                GameListView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Image(systemName: "chart.bar.fill")
                Text("Games")
            }
            
            // MARK: - New Game Tab (Admin Only)
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
            
            // MARK: - Settings Tab
            NavigationView {
                SettingsView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Image(systemName: "gearshape.fill")
                Text("Settings")
            }
        }
        .environment(\.horizontalSizeClass, .compact) // Force compact size class for bottom tabs
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
