//
//  RootNavigationView.swift
//  SahilStats
//
//  Single source of truth for app navigation
//

import SwiftUI

struct RootNavigationView: View {
    @StateObject private var navigation = NavigationCoordinator.shared
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        Group {
            switch navigation.currentFlow {
            case .dashboard:
                GameListView()
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
        .animation(.easeInOut(duration: 0.3), value: navigation.currentFlow)
    }
}

// MARK: - Simplified Role Selection

struct RoleSelectionView: View {
    @StateObject private var navigation = NavigationCoordinator.shared
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
    @StateObject private var navigation = NavigationCoordinator.shared
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
    }
}

struct ConnectionStatusIndicator: View {
    let state: NavigationCoordinator.ConnectionFlow
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Animation
            LottieView(name: animationName)
                .frame(width: isIPad ? 200 : 150, height: isIPad ? 200 : 150)
            
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