//
//  BluetoothConnectionView.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/29/25.
//
// File: SahilStats/Views/BluetoothConnectionView.swift
// UI for managing Bluetooth peer-to-peer connections

import SwiftUI
import MultipeerConnectivity

struct BluetoothConnectionView: View {
    @StateObject private var multipeer = MultipeerConnectivityManager.shared
    @StateObject private var roleManager = DeviceRoleManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var rememberDevice = true
    
    
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Connection Status
                connectionStatusCard
                if !multipeer.pendingInvitations.isEmpty {
                        pendingInvitationsSection
                }
                
                // Role-specific content
                if roleManager.deviceRole == .controller {
                    controllerView
                } else if roleManager.deviceRole == .recorder {
                    recorderView
                } else {
                    roleSelectionPrompt
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Bluetooth Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
        private var pendingInvitationsSection: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Connection Requests")
                    .font(.headline)
                
                ForEach(multipeer.pendingInvitations) { invitation in
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.title2)
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(invitation.peerID.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if let role = invitation.discoveryInfo?["role"] {
                                Text("Role: \(role)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let deviceType = invitation.discoveryInfo?["deviceType"] {
                                Text(deviceType)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 8) {
                            Button(action: {
                                multipeer.approveConnection(
                                    for: invitation.peerID,
                                    remember: rememberDevice
                                )
                            }) {
                                HStack {
                                    Image(systemName: "checkmark")
                                    Text("Connect")
                                }
                                .font(.caption)
                                .fontWeight(.medium)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            
                            Button(action: {
                                multipeer.declineConnection(for: invitation.peerID)
                            }) {
                                HStack {
                                    Image(systemName: "xmark")
                                    Text("Decline")
                                }
                                .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
                }
                
                Toggle("Remember this device for auto-connect", isOn: $rememberDevice)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    
    // MARK: - Connection Status Card
    
    @ViewBuilder
    private var connectionStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: statusIcon)
                    .font(.title)
                    .foregroundColor(statusColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(multipeer.connectionState.displayName)
                        .font(.headline)
                        .foregroundColor(statusColor)
                    
                    Text(statusDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if multipeer.isConnected {
                ForEach(multipeer.connectedPeers, id: \.displayName) { peer in
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(.green)
                        
                        Text(peer.displayName)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Button("Disconnect") {
                            multipeer.disconnect()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var statusIcon: String {
        switch multipeer.connectionState {
        case .disconnected: return "antenna.radiowaves.left.and.right.slash"
        case .connecting: return "antenna.radiowaves.left.and.right"
        case .connected: return "checkmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch multipeer.connectionState {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        }
    }
    
    private var statusDescription: String {
        switch multipeer.connectionState {
        case .disconnected:
            return "Not connected to any device"
        case .connecting:
            return "Establishing connection..."
        case .connected:
            return "Connected via Bluetooth"
        }
    }
    
    // MARK: - Controller View
    
    @ViewBuilder
    private var controllerView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Controller Mode")
                .font(.headline)
            
            if !multipeer.isConnected {
                // Browse for recorders
                if multipeer.isBrowsing {
                    if multipeer.nearbyPeers.isEmpty {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Searching for recorder devices...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Available Recorders")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            ForEach(multipeer.nearbyPeers, id: \.displayName) { peer in
                                Button(action: {
                                    multipeer.invitePeer(peer)
                                }) {
                                    HStack {
                                        Image(systemName: "video.fill")
                                            .foregroundColor(.red)
                                        
                                        VStack(alignment: .leading) {
                                            Text(peer.displayName)
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    Button("Stop Searching") {
                        multipeer.stopBrowsing()
                    }
                    .buttonStyle(UnifiedSecondaryButtonStyle(isIPad: isIPad))
                } else {
                    Button("Search for Recorder") {
                        multipeer.startBrowsing()
                    }
                    .buttonStyle(UnifiedPrimaryButtonStyle(isIPad: isIPad))
                }
            } else {
                // Connected - show controls
                VStack(spacing: 12) {
                    Text("Recording Controls")
                        .font(.headline)
                    
                    Button("Start Recording") {
                        multipeer.sendStartRecording()
                    }
                    .buttonStyle(UnifiedPrimaryButtonStyle(isIPad: isIPad))
                    
                    Button("Stop Recording") {
                        multipeer.sendStopRecording()
                    }
                    .buttonStyle(UnifiedSecondaryButtonStyle(isIPad: isIPad))
                }
            }
        }
    }
    
    // MARK: - Recorder View
    
    @ViewBuilder
    private var recorderView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recorder Mode")
                .font(.headline)
            
            if !multipeer.isConnected {
                if multipeer.isAdvertising {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Waiting for controller to connect...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Make sure the controller is searching")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    
                    Button("Stop Advertising") {
                        multipeer.stopAdvertising()
                    }
                    .buttonStyle(UnifiedSecondaryButtonStyle(isIPad: isIPad))
                } else {
                    Button("Make Visible to Controller") {
                        multipeer.startAdvertising(as: "recorder")
                    }
                    .buttonStyle(UnifiedPrimaryButtonStyle(isIPad: isIPad))
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Connected to Controller")
                        .font(.headline)
                    
                    Text("Recording will start automatically when the controller begins the game")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
    }
    
    // MARK: - Role Selection Prompt
    
    @ViewBuilder
    private var roleSelectionPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Select Device Role")
                .font(.headline)
            
            Text("Choose your role to enable Bluetooth connection")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Go Back to Setup") {
                dismiss()
            }
            .buttonStyle(UnifiedPrimaryButtonStyle(isIPad: isIPad))
        }
        .padding()
    }
}

// MARK: - Bluetooth Status Indicator

struct BluetoothStatusIndicator: View {
    @StateObject private var multipeer = MultipeerConnectivityManager.shared
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.caption)
                .foregroundColor(statusColor)
            
            Text(multipeer.connectionState.displayName)
                .font(.caption2)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var statusIcon: String {
        switch multipeer.connectionState {
        case .disconnected: return "antenna.radiowaves.left.and.right.slash"
        case .connecting: return "antenna.radiowaves.left.and.right"
        case .connected: return "checkmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch multipeer.connectionState {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        }
    }
}

#Preview {
    BluetoothConnectionView()
}
