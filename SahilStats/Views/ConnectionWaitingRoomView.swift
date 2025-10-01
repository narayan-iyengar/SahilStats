//
//  ConnectionWaitingRoomView.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/30/25.
//
//
//  ConnectionWaitingRoomView.swift
//  SahilStats
//
//  Waiting room for establishing Bluetooth connection before game starts
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
    let onGameStart: () -> Void // Called when controller starts game or recorder receives signal
    
    @State private var showingApprovalDialog = false
    @State private var pendingPeer: MCPeerID?
    @State private var rememberDevice = true
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        NavigationView {
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
                setupConnection()
                UIApplication.shared.isIdleTimerDisabled = true
            }
            
            .onDisappear {
                //cleanup()
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
                    .trim(from: 0, to: multipeer.isConnected ? 1 : 0.3)
                    .stroke(statusColor, lineWidth: 8)
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(multipeer.isConnected ? .easeIn : .easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: multipeer.isConnected)
                
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
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Connected to \(peer.displayName)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if trustedDevices.isTrusted(peer) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Action Buttons
    
    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 16) {
            if role == .controller {
                // Controller can start game when connected
                Button("Start Game") {
                    startGameAsController()
                }
                .buttonStyle(UnifiedPrimaryButtonStyle(isIPad: isIPad))
                .disabled(!multipeer.isConnected)
                
                if !multipeer.isConnected {
                    Text("Waiting for recorder to connect...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if role == .recorder {
                // Recorder waits for controller to start
                if multipeer.isConnected {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Waiting for controller to start game...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Searching for controller...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Manual connection button if auto-connect fails
            if !multipeer.isConnected && !multipeer.nearbyPeers.isEmpty {
                Button("Connect Manually") {
                    // This would open BluetoothConnectionView for manual selection
                }
                .buttonStyle(UnifiedSecondaryButtonStyle(isIPad: isIPad))
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusIcon: String {
        if multipeer.isConnected {
            return "checkmark.circle.fill"
        } else if multipeer.connectionState == .connecting {
            return "arrow.triangle.2.circlepath"
        } else {
            return "antenna.radiowaves.left.and.right"
        }
    }
    
    private var statusColor: Color {
        switch multipeer.connectionState {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .blue
        }
    }
    
    private var statusTitle: String {
        if multipeer.isConnected {
            return "Connected"
        } else if multipeer.connectionState == .connecting {
            return "Connecting..."
        } else {
            return role == .controller ? "Waiting for Recorder" : "Looking for Controller"
        }
    }
    
    private var statusDescription: String {
        if multipeer.isConnected {
            return role == .controller
                ? "Ready to start the game"
                : "Connected to controller"
        } else if multipeer.connectionState == .connecting {
            return "Establishing secure connection"
        } else {
            return role == .controller
                ? "Make sure the recorder device has selected Recorder mode"
                : "Make sure the controller has started the setup process"
        }
    }
    
    // MARK: - Setup and Cleanup
    
    private func setupConnection() {
        // Set up callbacks
        multipeer.onPendingInvitation = { peer in
            pendingPeer = peer
            showingApprovalDialog = true
        }
        
        multipeer.onConnectionEstablished = {
            // Mark device as trusted if user chose to remember
            if rememberDevice, let peer = multipeer.connectedPeers.first {
                let peerRole: DeviceRoleManager.DeviceRole = role == .controller ? .recorder : .controller
                trustedDevices.addTrustedPeer(peer, role: peerRole)
            }
            
            // Send ready signal
            if role == .controller {
                multipeer.sendControllerReady()
            } else {
                multipeer.sendRecorderReady()
            }
        }
        
        multipeer.onGameStarting = { gameId in
            // Recorder receives this signal
            print("🎬 onGameStarting callback fired for role: \(role)")
                if role == .recorder {
                    print("🎬 Calling onGameStart closure")
                    onGameStart()
            }
        }
        
        // Start appropriate service based on role
        if role == .controller {
            // Controller advertises
            multipeer.startAdvertising(as: .controller)
        } else {
            // Recorder browses
            multipeer.startBrowsing()
        }
    }
    
    private func cleanup() {
        multipeer.onPendingInvitation = nil
        multipeer.onConnectionEstablished = nil
        multipeer.onGameStarting = nil
        
        // Don't disconnect - maintain connection for the game
        // Just stop advertising/browsing
        //if role == .controller {
        //    multipeer.stopAdvertising()
        //} else {
        //    multipeer.stopBrowsing()
        //}
    }
    
    private func cleanupAndDismiss() {
        multipeer.stopAll()
        dismiss()
    }
    
    // MARK: - Actions
    
    private func approveConnection(remember: Bool) {
        rememberDevice = remember
        guard let peer = pendingPeer else { return }
        
        // Check if this is from a pending invitation (advertiser side)
        if let (invitationPeer, handler) = multipeer.pendingInvitation, invitationPeer == peer {
            // Accept the invitation using the stored handler
            handler(true)
            multipeer.pendingInvitation = nil
        } else {
            // This is from discovery (browser side) - send invitation
            multipeer.connectAfterApproval(peer, approved: true, rememberDevice: remember)
        }
        pendingPeer = nil
    }
    
    private func declineConnection() {
        guard let peer = pendingPeer else { return }
        multipeer.connectAfterApproval(peer, approved: false)
        pendingPeer = nil
    }
    
    private func startGameAsController() {
        // This will be called from GameSetupView to create the game
        // and send the game starting signal
        onGameStart()
    }
}

// MARK: - Preview

#Preview {
    ConnectionWaitingRoomView(role: .controller) {
        print("Game started")
    }
}
