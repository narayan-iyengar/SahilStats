//
//  ConnectionStatusNotification.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 10/3/25.
//

// ConnectionStatusNotification.swift
// Native iOS-style banner that shows connection progress

import SwiftUI
import Combine
import MultipeerConnectivity

struct ConnectionStatusNotification: View {
    let status: ConnectionStatus
    @Binding var isShowing: Bool
    
    enum ConnectionStatus {
        case searching
        case connecting(deviceName: String)
        case connected(deviceName: String, role: DeviceRoleManager.DeviceRole)
        case failed(error: String)
        
        var icon: String {
            switch self {
            case .searching: return "antenna.radiowaves.left.and.right"
            case .connecting: return "arrow.triangle.2.circlepath"
            case .connected: return "checkmark.circle.fill"
            case .failed: return "exclamationmark.triangle.fill"
            }
        }
        
        var iconColor: Color {
            switch self {
            case .searching: return .blue
            case .connecting: return .orange
            case .connected: return .green
            case .failed: return .red
            }
        }
        
        var title: String {
            switch self {
            case .searching: return "Searching for devices..."
            case .connecting(let name): return "Connecting to \(name)"
            case .connected(let name, _): return "\(name) Connected"
            case .failed: return "Connection Failed"
            }
        }
        
        var subtitle: String {
            switch self {
            case .searching: return "Looking for trusted devices"
            case .connecting: return "Establishing secure connection"
            case .connected(_, let role):
                return role == .controller ? "Ready to control" : "Ready to record"
            case .failed(let error): return error
            }
        }
    }
    
    var body: some View {
        VStack {
            if isShowing {
                HStack(spacing: 12) {
                    // Animated icon
                    ZStack {
                        if case .searching = status {
                            ProgressView()
                                .tint(.blue)
                        } else if case .connecting = status {
                            ProgressView()
                                .tint(.orange)
                        } else {
                            Image(systemName: status.icon)
                                .font(.title2)
                                .foregroundColor(status.iconColor)
                        }
                    }
                    .frame(width: 28, height: 28)
                    
                    // Text content
                    VStack(alignment: .leading, spacing: 2) {
                        Text(status.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(status.subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Dismiss button (only for failed state)
                    if case .failed = status {
                        Button(action: {
                            withAnimation {
                                isShowing = false
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                )
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Spacer()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isShowing)
        .onAppear {
            // Trigger haptic for connected state
            if case .connected = status {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }
}

// MARK: - Enhanced No Live Game View with Lottie

struct NoLiveGameLottieView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: isIPad ? 40 : 32) {
                Spacer()
                
                // Lottie animation
                LottieView(name: "no-game-animation")
                    .frame(width: isIPad ? 300 : 200, height: isIPad ? 300 : 200)
                
                VStack(spacing: isIPad ? 20 : 16) {
                    Text("No Live Game")
                        .font(isIPad ? .system(size: 44, weight: .bold) : .largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("The game has ended or is no longer available")
                        .font(isIPad ? .title3 : .body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, isIPad ? 60 : 40)
                }
                
                Spacer()
                
                // Action button
                Button("Back to Dashboard") {
                    dismissToRoot()
                }
                .buttonStyle(UnifiedPrimaryButtonStyle(isIPad: isIPad))
                .padding(.horizontal, isIPad ? 80 : 40)
                
                Spacer()
            }
        }
    }
    
    private func dismissToRoot() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            dismiss()
            return
        }
        
        var currentVC = rootViewController
        while let presented = currentVC.presentedViewController {
            currentVC = presented
        }
        
        currentVC.dismiss(animated: true)
    }
}

// MARK: - Simplified Connection Flow (Replace ConnectionWaitingRoomView)

struct SeamlessConnectionFlow: View {
    let role: DeviceRoleManager.DeviceRole
    let onGameStart: (String) -> Void
    let liveGame: LiveGame
    
    @StateObject private var multipeer = MultipeerConnectivityManager.shared
    @StateObject private var roleManager = DeviceRoleManager.shared
    @StateObject private var firebaseService = FirebaseService.shared
    @ObservedObject private var trustedDevices = TrustedDevicesManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @State private var connectionStatus: ConnectionStatusNotification.ConnectionStatus = .searching
    @State private var showNotification = false
    @State private var hasStartedGame = false
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        ZStack {
            // Main content based on role
            if role == .controller {
                // Controller proceeds directly to game form
                Color.clear
                    .onAppear {
                        // Just connect in background
                        startBackgroundConnection()
                    }
            } else {
                // Recorder waits for game start
                waitingView
            }
            
            // Connection notification overlay (appears at top)
            ConnectionStatusNotification(
                status: connectionStatus,
                isShowing: $showNotification
            )
            .padding(.top, 8)
            .zIndex(1000)
        }
        .onAppear {
            setupSeamlessConnection()
        }
        .onDisappear {
            // Keep connection alive - don't cleanup!
        }
    }
    
    @ViewBuilder
    private var waitingView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Lottie animation
            LottieView(name: "Loading")
                .frame(width: isIPad ? 200 : 150, height: isIPad ? 200 : 150)
            
            VStack(spacing: 12) {
                Text("Connected & Ready")
                    .font(isIPad ? .title : .title2)
                    .fontWeight(.bold)
                
                Text("Waiting for controller to start the game")
                    .font(isIPad ? .body : .subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(UnifiedSecondaryButtonStyle(isIPad: isIPad))
            .padding(.horizontal, 40)
        }
        .padding()
    }
    
    private func setupSeamlessConnection() {
        print("🔵 Starting seamless connection for \(role.displayName)")
        
        // Show searching notification
        connectionStatus = .searching
        showNotification = true
        
        // Auto-hide searching after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if case .searching = connectionStatus {
                withAnimation {
                    showNotification = false
                }
            }
        }
        
        // If already connected, skip to connected state
        if multipeer.isConnected {
            if let peer = multipeer.connectedPeers.first {
                handleConnectionEstablished(peer: peer)
            }
            return
        }
        
        // Setup connection callbacks
        multipeer.onPeerDiscovered = { peer in
            print("👀 Discovered peer: \(peer.displayName)")
            connectionStatus = .connecting(deviceName: peer.displayName)
            showNotification = true
        }
        
        multipeer.onConnectionEstablished = {
            if let peer = multipeer.connectedPeers.first {
                handleConnectionEstablished(peer: peer)
            }
        }
        
        multipeer.onGameStarting = { gameId in
            guard !hasStartedGame else { return }
            
            if role == .recorder {
                hasStartedGame = true
                print("🎬 Recorder received game start - transitioning...")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onGameStart(gameId)
                }
            }
        }
        
        multipeer.onGameAlreadyStarted = { gameId in
            guard !hasStartedGame else { return }
            
            if role == .recorder {
                hasStartedGame = true
                DispatchQueue.main.async {
                    onGameStart(gameId)
                }
            }
        }
        
        // Start connection based on role
        startBackgroundConnection()
    }
    
    private func startBackgroundConnection() {
        if role == .controller {
            multipeer.startBrowsing()
        } else {
            multipeer.startAdvertising(as: "recorder")
        }
    }
    
    private func handleConnectionEstablished(peer: MCPeerID) {
        print("✅ Connection established with \(peer.displayName)")
        
        let peerRole: DeviceRoleManager.DeviceRole = role == .controller ? .recorder : .controller
        
        // Show connected notification
        connectionStatus = .connected(deviceName: peer.displayName, role: peerRole)
        showNotification = true
        
        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation {
                showNotification = false
            }
        }
        
        // Remember trusted device
        if trustedDevices.isTrusted(peer) {
            trustedDevices.addTrustedPeer(peer, role: peerRole)
        }
        
        // Controller proceeds to game form immediately
        if role == .controller {
            // Connection happens in background, controller continues
            print("🎮 Controller connected - ready to start game")
        }
    }
}
