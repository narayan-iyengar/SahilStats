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
    @StateObject private var liveGameManager = LiveGameManager.shared // Add this
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
        // This is the master controller for showing live game views
        .fullScreenCover(isPresented: .constant(liveGameManager.gameState != .idle)) {
            LiveGameContainerView()
        }
    }
}

// This new container view decides what to show during a live session
struct LiveGameContainerView: View {
    @StateObject private var liveGameManager = LiveGameManager.shared
    
    var body: some View {
        Group {
            switch liveGameManager.gameState {
            case .connecting(let role), .connected(let role):
                // ** THIS IS THE FIX **
                // Removed the extra 'liveGame' argument from the call below.
                ConnectionWaitingRoomView(role: role)
                
            case .inProgress(let role):
                if let liveGame = liveGameManager.liveGame {
                     if role == .recorder {
                        CleanVideoRecordingView(liveGame: liveGame)
                     } else {
                        LiveGameControllerView(liveGame: liveGame)
                     }
                } else {
                    // This shows while the liveGame object is loading from Firebase
                    ProgressView("Loading Game Data...")
                }
            case .idle:
                // This case is handled by the `isPresented` binding, but it's good practice
                // to have a fallback.
                EmptyView()
            }
        }
    }
}

private func startAutoDiscovery() {
    let roleManager = DeviceRoleManager.shared
    let multipeer = MultipeerConnectivityManager.shared
    
    print("📱 Checking device role for auto-discovery...")
    print("📱 Current role: \(roleManager.deviceRole.displayName)")
    
    switch roleManager.deviceRole {
    case .controller:
        print("🎮 Starting browsing for recorders...")
        multipeer.startBrowsing()
    case .recorder:
        print("📹 Starting advertising as recorder...")
        multipeer.startAdvertising(as: "recorder")
        multipeer.startBrowsing()
    case .none, .viewer:
        print("ℹ️ No active role - not starting discovery")
        break
    }
}

/*
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
 */

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
