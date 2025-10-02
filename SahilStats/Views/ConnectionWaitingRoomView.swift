//
//  ConnectionWaitingRoomView.swift
//  SahilStats
//

import SwiftUI
import MultipeerConnectivity
import Combine

struct ConnectionWaitingRoomView: View {
    @StateObject private var multipeer = MultipeerConnectivityManager.shared
    @StateObject private var roleManager = DeviceRoleManager.shared
    @State private var hasSetupConnection = false
    
    private let trustedDevices = TrustedDevicesManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    let role: DeviceRoleManager.DeviceRole
    let onGameStart: () -> Void
    
    @State private var showingApprovalDialog = false
    @State private var pendingPeer: MCPeerID?
    @State private var rememberDevice = true
    
    // Game start protection
    @State private var hasStartedGame = false
    @State private var isProcessingGameStart = false
    
    // Connection stability tracking
    @State private var connectionStableTime: Date?
    @State private var isConnectionStable = false
    @State private var stabilityCheckTimer: Timer?
    
    // NEW: Toast notification state
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIcon = "checkmark.circle.fill"
    @State private var toastColor = Color.green
    
    // NEW: Check if already connected to trusted device
    @State private var connectedToTrustedDevice = false
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 32) {
                    // Role indicator
                    VStack(spacing: 12) {
                        Image(systemName: role.icon)
                            .font(.system(size: 60))
                            .foregroundColor(role.color)
                        
                        Text(role.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .padding(.top, 40)
                    
                    // Connection status
                    connectionStatusSection
                    
                    Spacer()
                    
                    // Action buttons
                    actionButtons
                    
                    Spacer()
                }
                .padding()
                .navigationTitle("Connection")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            cleanupAndDismiss()
                        }
                    }
                }
                .onAppear {
                    guard !hasSetupConnection else {
                        print("Connection already setup, skipping")
                        return
                    }
                    hasSetupConnection = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        setupConnection()
                        UIApplication.shared.isIdleTimerDisabled = true
                    }
                }
                .onDisappear {
                    stopStabilityCheck()
                    UIApplication.shared.isIdleTimerDisabled = false
                }
                .alert("Connect to \(pendingPeer?.displayName ?? "Device")?", isPresented: $showingApprovalDialog) {
                    Button("Connect Once") {
                        approveConnection(remember: false)
                    }
                    
                    Button("Connect & Trust") {
                        approveConnection(remember: true)
                    }
                    
                    Button("Decline", role: .cancel) {
                        declineConnection()
                    }
                } message: {
                    Text("Do you want to connect to this device? Trusting the device will allow automatic connection in the future.")
                }
                
                // NEW: Toast notification overlay
                ToastView(
                    message: toastMessage,
                    icon: toastIcon,
                    color: toastColor,
                    isShowing: $showToast
                )
            }
        }
    }
    
    // MARK: - Connection Status Section
    
    @ViewBuilder
    private var connectionStatusSection: some View {
        VStack(spacing: 24) {
            // Status indicator
            ZStack {
                Circle()
                    .stroke(statusColor.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: progressValue)
                    .stroke(statusColor, lineWidth: 8)
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(animationType, value: progressValue)
                
                Image(systemName: statusIcon)
                    .font(.system(size: 40))
                    .foregroundColor(statusColor)
            }
            
            // Status text
            VStack(spacing: 8) {
                Text(statusTitle)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(statusDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Connected peer info
            if multipeer.isConnected, let peer = multipeer.connectedPeers.first {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: connectedIcon)
                            .foregroundColor(connectedColor)
                        
                        Text(connectedStatusText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if trustedDevices.isTrusted(peer) {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(connectedColor.opacity(0.1))
                    .cornerRadius(12)
                    
                    Text("Connected to \(peer.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Action Buttons
    
    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 16) {
            if role == .controller {
                Button("Start Game") {
                    startGameAsController()
                }
                .buttonStyle(UnifiedPrimaryButtonStyle(isIPad: isIPad))
                .disabled(!isConnectionStable || isProcessingGameStart)
                .opacity((isConnectionStable && !isProcessingGameStart) ? 1.0 : 0.6)
                
                if isProcessingGameStart {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Starting game...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if !multipeer.isConnected {
                    Text("Waiting for recorder to connect...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if !isConnectionStable {
                    Text("Waiting for stable connection...")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            } else if role == .recorder {
                if multipeer.isConnected {
                    VStack(spacing: 8) {
                        if connectedToTrustedDevice && isConnectionStable {
                            // NEW: Better message when already connected to trusted device
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)
                            
                            Text("Connected & Ready!")
                                .font(.headline)
                            
                            Text("Waiting for controller to start the game")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        } else if isConnectionStable {
                            ProgressView()
                            Text("Ready! Waiting for controller to start...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        } else {
                            ProgressView()
                            Text("Stabilizing connection...")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.center)
                        }
                    }
                } else {
                    Text("Searching for controller...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusIcon: String {
        if multipeer.isConnected {
            return isConnectionStable ? "checkmark.circle.fill" : "hourglass"
        } else if multipeer.connectionState == .connecting {
            return "arrow.triangle.2.circlepath"
        } else {
            return "antenna.radiowaves.left.and.right"
        }
    }
    
    private var statusColor: Color {
        if multipeer.isConnected {
            return isConnectionStable ? .green : .orange
        }
        switch multipeer.connectionState {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .blue
        }
    }
    
    private var progressValue: Double {
        if multipeer.isConnected {
            return isConnectionStable ? 1.0 : 0.7
        } else {
            return 0.3
        }
    }
    
    private var animationType: Animation {
        if multipeer.isConnected && isConnectionStable {
            return .easeIn
        } else {
            return .easeInOut(duration: 1.5).repeatForever(autoreverses: false)
        }
    }
    
    private var statusTitle: String {
        if multipeer.isConnected {
            if connectedToTrustedDevice && isConnectionStable {
                return "Connected!"
            }
            return isConnectionStable ? "Ready" : "Stabilizing"
        } else if multipeer.connectionState == .connecting {
            return "Connecting..."
        } else {
            return role == .controller ? "Waiting for Recorder" : "Looking for Controller"
        }
    }
    
    private var statusDescription: String {
        if multipeer.isConnected {
            if connectedToTrustedDevice && isConnectionStable {
                return "Connected to trusted device"
            }
            if isConnectionStable {
                return role == .controller ? "Ready to start the game" : "Connected and ready"
            } else {
                return "Ensuring stable connection..."
            }
        } else if multipeer.connectionState == .connecting {
            return "Establishing secure connection"
        } else {
            return role == .controller
                ? "Make sure the recorder device has selected Recorder mode"
                : "Make sure the controller has started the setup process"
        }
    }
    
    // NEW: Computed properties for connected device display
    private var connectedIcon: String {
        if connectedToTrustedDevice && isConnectionStable {
            return "checkmark.circle.fill"
        } else if isConnectionStable {
            return "checkmark.circle.fill"
        } else {
            return "hourglass"
        }
    }
    
    private var connectedColor: Color {
        if connectedToTrustedDevice && isConnectionStable {
            return .green
        } else if isConnectionStable {
            return .green
        } else {
            return .orange
        }
    }
    
    private var connectedStatusText: String {
        if connectedToTrustedDevice && isConnectionStable {
            return "Trusted Device Connected"
        } else if isConnectionStable {
            return "Connection Stable"
        } else {
            return "Stabilizing..."
        }
    }
    
    // MARK: - Setup and Cleanup
    
    private func setupConnection() {
        print("🔵 Setting up connection for role: \(role)")
        
        multipeer.onPendingInvitation = { peer in
            print("📱 onPendingInvitation callback fired for: \(peer.displayName)")
            DispatchQueue.main.async {
                self.pendingPeer = peer
                self.showingApprovalDialog = true
                print("📱 Set showingApprovalDialog = true")
            }
        }
        
        if let existingPending = multipeer.pendingInvitations.first {
            print("📱 Found existing pending invitation for: \(existingPending.peerID.displayName)")
            DispatchQueue.main.async {
                self.pendingPeer = existingPending.peerID
                self.showingApprovalDialog = true
                print("📱 Set showingApprovalDialog = true for existing invitation")
            }
        }
        
        multipeer.onConnectionEstablished = {
            print("✅ Connection established - starting stability timer")
            
            if rememberDevice, let peer = multipeer.connectedPeers.first {
                let peerRole: DeviceRoleManager.DeviceRole = role == .controller ? .recorder : .controller
                trustedDevices.addTrustedPeer(peer, role: peerRole)
            }
            
            // NEW: Check if this is a trusted device
            if let peer = multipeer.connectedPeers.first {
                connectedToTrustedDevice = trustedDevices.isTrusted(peer)
            }
            
            connectionStableTime = Date()
            isConnectionStable = false
            startStabilityCheck()
        }
        
        multipeer.onGameStarting = { gameId in
            print("🎬 onGameStarting callback fired for role: \(role), gameId: \(gameId)")
            
            guard !hasStartedGame else {
                print("⚠️ Game already started, ignoring duplicate call")
                return
            }
            
            if role == .recorder {
                hasStartedGame = true
                print("🎬 Recorder handling game start...")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onGameStart()
                }
            }
        }
        
        print("🔵 Connection already initiated in GameSetupView")
    }
    
    private func startStabilityCheck() {
        stopStabilityCheck()
        
        print("⏱️ Starting connection stability check...")
        
        stabilityCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            guard let startTime = connectionStableTime else {
                timer.invalidate()
                return
            }
            
            let elapsed = Date().timeIntervalSince(startTime)
            
            if elapsed >= 2.0 && !isConnectionStable {
                print("✅ Connection stable after 2 seconds")
                isConnectionStable = true
                
                // NEW: Show toast notification
                showConnectionToast()
                
                // Send ready signals
                if role == .controller {
                    multipeer.sendControllerReady()
                } else {
                    multipeer.sendRecorderReady()
                }
                
                timer.invalidate()
            }
        }
    }
    
    // NEW: Show toast notification method
    private func showConnectionToast() {
        guard let peer = multipeer.connectedPeers.first else { return }
        
        if role == .controller {
            toastMessage = "Connected to \(peer.displayName)"
            toastIcon = "checkmark.circle.fill"
            toastColor = .green
        } else {
            // RECORDER TOAST
            toastMessage = "Connected to Controller"
            toastIcon = "checkmark.circle.fill"
            toastColor = .green
        }
        
        withAnimation {
            showToast = true
        }
        
        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation {
                showToast = false
            }
        }
    }
    
    private func stopStabilityCheck() {
        stabilityCheckTimer?.invalidate()
        stabilityCheckTimer = nil
    }
    
    private func cleanup() {
        stopStabilityCheck()
        multipeer.onPendingInvitation = nil
        multipeer.onConnectionEstablished = nil
        multipeer.onGameStarting = nil
    }
    
    private func cleanupAndDismiss() {
        cleanup()
        multipeer.stopAll()
        dismiss()
    }
    
    // MARK: - Actions
    
    private func approveConnection(remember: Bool) {
        rememberDevice = remember
        guard let peer = pendingPeer else { return }
        
        print("✅ Approving connection to: \(peer.displayName), remember: \(remember)")
        
        multipeer.approveConnection(for: peer, remember: remember)
        pendingPeer = nil
    }
    
    private func declineConnection() {
        guard let peer = pendingPeer else { return }
        print("❌ Declining connection to: \(peer.displayName)")
        
        multipeer.declineConnection(for: peer)
        pendingPeer = nil
    }
    
    private func startGameAsController() {
        guard !isProcessingGameStart && !hasStartedGame && isConnectionStable else {
            print("⚠️ Cannot start game - processing:\(isProcessingGameStart) started:\(hasStartedGame) stable:\(isConnectionStable)")
            return
        }
        
        print("🎮 Controller starting game - connection is stable")
        print("🔍 Multipeer has \(multipeer.connectedPeers.count) connected peers")
        print("🎮 Calling onGameStart callback...")
        isProcessingGameStart = true
        hasStartedGame = true
        isProcessingGameStart = false
        onGameStart()
        print("🎮 onGameStart callback completed")
    }
}


struct ToastView: View {
    let message: String
    let icon: String
    let color: Color
    @Binding var isShowing: Bool
    
    var body: some View {
        VStack {
            Spacer()
            
            if isShowing {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                    
                    Text(message)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 50)
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isShowing)
    }
}


// MARK: - Preview

#Preview {
    ConnectionWaitingRoomView(role: .controller) {
        print("Game started")
    }
}
