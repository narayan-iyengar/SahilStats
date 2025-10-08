//
//  RootNavigationView.swift
//  SahilStats
//
//  Single source of truth for app navigation
//

import SwiftUI

struct RootNavigationView: View {
    @ObservedObject private var navigation = NavigationCoordinator.shared
    @EnvironmentObject var authService: AuthService
    @StateObject private var firebaseService = FirebaseService.shared
    
    var body: some View {
        Group {
            if authService.isLoading {
                SplashView()
            } else {
                // FIXED: Don't auto-navigate to recording on app start
                // Check if we should show main dashboard or specific flow
                if shouldShowMainDashboard() {
                    MainTabView()
                        .environmentObject(authService)
                } else {
                    // Handle specific navigation flows
                    switch navigation.currentFlow {
                    case .dashboard:
                        MainTabView()
                            .environmentObject(authService)
                        
                    case .gameSetup(let role):
                        if role == .none {
                            RoleSelectionView()
                        } else {
                            ConnectionFlow(role: role)
                        }
                        
                    case .liveGame(let liveGame):
                        LiveGameView()
                            .environmentObject(authService)
                            .navigationBarHidden(true)
                            .statusBarHidden(true)
                        
                    case .recording(let liveGame, let role):
                        CleanVideoRecordingView(liveGame: liveGame)
                            .ignoresSafeArea(.all)
                            .navigationBarHidden(true)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: navigation.currentFlow)
        .onAppear {
            print("🏠 RootNavigationView: Appeared with currentFlow: \(navigation.currentFlow)")
            
            // FIXED: Reset to dashboard if there's a live game but no active role
            if firebaseService.hasLiveGame && DeviceRoleManager.shared.deviceRole == .none {
                print("🏠 RootNavigationView: Live game exists but no role set, staying on dashboard")
                navigation.currentFlow = .dashboard
            }
        }
        .onChange(of: navigation.currentFlow) { oldValue, newValue in
            print("🏠 RootNavigationView: currentFlow changed from \(oldValue) to \(newValue)")
        }
    }
    
    // FIXED: Helper method to determine if we should show main dashboard
    private func shouldShowMainDashboard() -> Bool {
        // Always start at dashboard unless explicitly navigating elsewhere
        switch navigation.currentFlow {
        case .dashboard:
            return true
        case .recording(_, _):
            // Only show recording if user explicitly joined as recorder
            // Check if this is a fresh app start
            if DeviceRoleManager.shared.deviceRole == .recorder {
                // User has recorder role, but did they explicitly choose to join?
                // If there's no active multipeer connection, return to dashboard
                if !MultipeerConnectivityManager.shared.connectionState.isConnected {
                    print("🏠 No active connection, returning to dashboard")
                    return true
                }
                return false
            }
            return true
        default:
            return false
        }
    }
}

// MARK: - Splash View

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

// MARK: - Main Tab View

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


// MARK: - Simplified Role Selection

struct RoleSelectionView: View {
    @ObservedObject private var navigation = NavigationCoordinator.shared
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isIPad: Bool { horizontalSizeClass == .regular }
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("Choose Your Role")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Select how you want to participate in this game")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                RoleButton(
                    title: "Controller",
                    subtitle: "Control the game and manage stats",
                    icon: "gamecontroller.fill",
                    color: .blue
                ) {
                    navigation.selectRole(.controller)
                }
                
                RoleButton(
                    title: "Recorder",
                    subtitle: "Record video and capture highlights",
                    icon: "video.fill",
                    color: .red
                ) {
                    navigation.selectRole(.recorder)
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            Button("Cancel") {
                navigation.returnToDashboard()
            }
            .buttonStyle(UnifiedSecondaryButtonStyle(isIPad: isIPad))
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

struct RoleButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Simplified Connection Flow

struct ConnectionFlow: View {
    let role: DeviceRoleManager.DeviceRole
    @ObservedObject private var navigation = NavigationCoordinator.shared
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isIPad: Bool { horizontalSizeClass == .regular }
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Connection status indicator
            ConnectionStatusIndicator(
                state: navigation.connectionState,
                isIPad: isIPad
            )
            
            Spacer()
            
            Button("Cancel") {
                navigation.returnToDashboard()
            }
            .buttonStyle(UnifiedSecondaryButtonStyle(isIPad: isIPad))
            .padding(.horizontal, 40)
        }
        .padding()
        .onAppear {
            print("🔄 ConnectionFlow: View appeared with role: \(role), currentFlow: \(navigation.currentFlow)")
        }
        .onChange(of: navigation.currentFlow) { oldValue, newValue in
            print("🔄 ConnectionFlow: currentFlow changed from \(oldValue) to \(newValue)")
        }
    }
}

struct ConnectionStatusIndicator: View {
    let state: NavigationCoordinator.ConnectionFlow
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Animation with fallback
            if Bundle.main.path(forResource: animationName, ofType: "json") != nil {
                LottieView(name: animationName)
                    .frame(width: isIPad ? 200 : 150, height: isIPad ? 200 : 150)
            } else {
                // Fallback animation using SwiftUI
                Image(systemName: iconName)
                    .font(.system(size: isIPad ? 80 : 60))
                    .foregroundColor(iconColor)
                    .scaleEffect(animatedScale)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: animatedScale)
                    .onAppear {
                        animatedScale = 1.2
                    }
            }
            
            VStack(spacing: 8) {
                Text(title)
                    .font(isIPad ? .title : .title2)
                    .fontWeight(.bold)
                
                Text(subtitle)
                    .font(isIPad ? .body : .subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    @State private var animatedScale: CGFloat = 1.0
    
    private var iconName: String {
        switch state {
        case .idle, .selectingRole:
            return "wifi"
        case .connecting:
            return "wifi.circle"
        case .connected:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch state {
        case .idle, .selectingRole:
            return .blue
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .failed:
            return .red
        }
    }
    
    private var animationName: String {
        switch state {
        case .idle, .selectingRole:
            return "connection-animation"
        case .connecting:
            return "connection-animation"
        case .connected:
            return "success-animation"
        case .failed:
            return "error-animation"
        }
    }
    
    private var title: String {
        switch state {
        case .idle:
            return "Ready"
        case .selectingRole:
            return "Choose Role"
        case .connecting(let role):
            return "Connecting..."
        case .connected(let role):
            return "Connected!"
        case .failed:
            return "Connection Failed"
        }
    }
    
    private var subtitle: String {
        switch state {
        case .idle:
            return "Ready to start"
        case .selectingRole:
            return "Select your role to continue"
        case .connecting(let role):
            return role == .controller ? "Searching for recorder..." : "Waiting for controller..."
        case .connected(let role):
            return role == .controller ? "Ready to start game" : "Waiting for game to start"
        case .failed(let error):
            return error
        }
    }
}
