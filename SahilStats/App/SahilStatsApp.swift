// File: SahilStats/SahilStatsApp.swift (Create this new file in the root)

import SwiftUI
import FirebaseCore

@main
struct SahilStatsApp: App {
    @StateObject private var authService = AuthService()
    
    init() {
        // Configure Firebase
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !authService.isSignedIn || authService.userRole == .guest {
                    Button("Sign In") {
                        showingAuth = true
                    }
                    .foregroundColor(.orange)
                }
            }
        }
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
    }
}

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingAuth = false
    
    var body: some View {
        List {
            Section("Account") {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(authService.userRole.displayName)
                        .foregroundColor(.secondary)
                }
                
                if authService.isSignedIn && !authService.currentUser!.isAnonymous {
                    if let email = authService.currentUser?.email {
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(email)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button("Sign Out") {
                        Task {
                            try? await authService.signOut()
                        }
                    }
                    .foregroundColor(.red)
                } else {
                    Button("Sign In") {
                        showingAuth = true
                    }
                    .foregroundColor(.orange)
                }
            }
            
            if authService.showAdminFeatures {
                Section("Admin Features") {
                    NavigationLink("Team Management") {
                        Text("Team Management")
                            .navigationTitle("Teams")
                    }
                    
                    NavigationLink("Game Settings") {
                        Text("Game Settings")
                            .navigationTitle("Settings")
                    }
                }
            }
            
            Section("App Info") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingAuth) {
            AuthView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService())
}
