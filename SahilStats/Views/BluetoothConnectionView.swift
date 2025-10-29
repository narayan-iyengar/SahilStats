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
    @ObservedObject private var multipeer = MultipeerConnectivityManager.shared
    @ObservedObject private var roleManager = DeviceRoleManager.shared
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

            // Show error message if present
            if let error = multipeer.lastError {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Connection Error")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }

                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Try: Check Bluetooth & WiFi are ON, move closer together, or restart both devices")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .padding(.top, 4)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }

            // Retry button when searching or disconnected, or when there's an error
            if shouldShowRetryButton {
                Button(action: {
                    // Clear error and restart session with current role
                    multipeer.lastError = nil
                    if roleManager.deviceRole != .none {
                        multipeer.stopSession()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            multipeer.startSession(role: roleManager.deviceRole)
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry Connection")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.small)
            }

            if multipeer.connectionState.isConnected {
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
        // Show error icon if there's an error, regardless of connection state
        if multipeer.lastError != nil {
            return "exclamationmark.triangle.fill"
        }

        switch multipeer.connectionState {
        case .idle: return "antenna.radiowaves.left.and.right.slash"
        case .searching: return "antenna.radiowaves.left.and.right"
        case .disconnected: return "antenna.radiowaves.left.and.right.slash"
        case .connecting: return "antenna.radiowaves.left.and.right"
        case .connected: return "checkmark.circle.fill"
        }
    }

    private var statusColor: Color {
        // Show red if there's an error, regardless of connection state
        if multipeer.lastError != nil {
            return .red
        }

        switch multipeer.connectionState {
        case .idle: return .gray
        case .searching: return .orange
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        }
    }

    private var statusDescription: String {
        // Show error description if there's an error
        if multipeer.lastError != nil {
            return "Connection failed"
        }

        switch multipeer.connectionState {
        case .idle:
            return "Not active"
        case .searching:
            return "Searching for devices..."
        case .disconnected:
            return "Not connected to any device"
        case .connecting:
            return "Establishing connection..."
        case .connected:
            return "Connected via Bluetooth"
        }
    }

    private var shouldShowRetryButton: Bool {
        if multipeer.lastError != nil {
            return true
        }

        switch multipeer.connectionState {
        case .searching, .disconnected:
            return true
        default:
            return false
        }
    }

    // MARK: - Controller View
    
    @ViewBuilder
    private var controllerView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Controller Mode")
                .font(.headline)

            if !multipeer.connectionState.isConnected {
                // Check if we have trusted devices - if so, show auto-connecting status
                let trustedDevices = TrustedDevicesManager.shared

                if trustedDevices.hasTrustedDevices && multipeer.isBrowsingActive {
                    // AUTO-CONNECTING MODE (like AirPods)
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)

                        Text("Auto-connecting to trusted recorder...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Text("Trusted devices connect automatically")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        // Only show discovered trusted devices (not for pairing)
                        if !multipeer.discoveredPeers.isEmpty {
                            let trustedPeers = multipeer.discoveredPeers.filter { trustedDevices.isTrusted($0) }
                            if !trustedPeers.isEmpty {
                                VStack(spacing: 8) {
                                    ForEach(trustedPeers, id: \.displayName) { peer in
                                        HStack {
                                            Image(systemName: "checkmark.shield.fill")
                                                .foregroundColor(.green)
                                            Text(peer.displayName)
                                                .font(.caption)
                                            Spacer()
                                            ProgressView()
                                                .scaleEffect(0.7)
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                                .padding(.vertical, 8)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }

                        Button("Cancel") {
                            multipeer.stopSession()
                        }
                        .buttonStyle(UnifiedSecondaryButtonStyle(isIPad: isIPad))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else if !trustedDevices.hasTrustedDevices {
                    // FIRST-TIME PAIRING MODE (no trusted devices yet)
                    if multipeer.isBrowsingActive {
                        if multipeer.discoveredPeers.isEmpty {
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

                                ForEach(multipeer.discoveredPeers, id: \.displayName) { peer in
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
                            multipeer.stopSession()
                        }
                        .buttonStyle(UnifiedSecondaryButtonStyle(isIPad: isIPad))
                    } else {
                        Button("Search for Recorder") {
                            // Use proper startSession instead of legacy startBrowsing
                            multipeer.startSession(role: .controller)
                        }
                        .buttonStyle(UnifiedPrimaryButtonStyle(isIPad: isIPad))
                    }
                } else {
                    // Has trusted devices but not browsing yet - start auto-connect
                    Button("Connect to Recorder") {
                        multipeer.startAutoConnectionIfNeeded()
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

            if !multipeer.connectionState.isConnected {
                // Check if we have trusted devices
                let trustedDevices = TrustedDevicesManager.shared

                if trustedDevices.hasTrustedDevices && multipeer.isAdvertisingActive {
                    // AUTO-CONNECTING MODE (like AirPods)
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)

                        Text("Ready for auto-connect...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Text("Trusted controller will connect automatically")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                            .padding()

                        Button("Cancel") {
                            multipeer.stopSession()
                        }
                        .buttonStyle(UnifiedSecondaryButtonStyle(isIPad: isIPad))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else if !trustedDevices.hasTrustedDevices {
                    // FIRST-TIME PAIRING MODE
                    if multipeer.isAdvertisingActive {
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
                            multipeer.stopSession()
                        }
                        .buttonStyle(UnifiedSecondaryButtonStyle(isIPad: isIPad))
                    } else {
                        Button("Make Visible to Controller") {
                            // Use proper startSession instead of legacy startAdvertising
                            multipeer.startSession(role: .recorder)
                        }
                        .buttonStyle(UnifiedPrimaryButtonStyle(isIPad: isIPad))
                    }
                } else {
                    // Has trusted devices but not advertising yet - start auto-connect
                    Button("Ready for Connection") {
                        multipeer.startAutoConnectionIfNeeded()
                    }
                    .buttonStyle(UnifiedPrimaryButtonStyle(isIPad: isIPad))
                }
            } else {
                // CONNECTED - Show simple ready state
                VStack(spacing: 20) {
                    // Big checkmark like AirPods
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    
                    Text("Connected & Ready")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let peer = multipeer.connectedPeers.first {
                        Text("Connected to \(peer.displayName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                        .padding(.vertical)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "circle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("Waiting for game to start")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("The controller will signal when ready")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                    
                    // Disconnect button at the bottom
                    Button("Disconnect") {
                        multipeer.disconnect()
                        dismiss()
                    }
                    .buttonStyle(UnifiedSecondaryButtonStyle(isIPad: isIPad))
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
    @ObservedObject private var multipeer = MultipeerConnectivityManager.shared
    
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
        case .idle: return "antenna.radiowaves.left.and.right.slash"
        case .searching: return "antenna.radiowaves.left.and.right"
        case .disconnected: return "antenna.radiowaves.left.and.right.slash"
        case .connecting: return "antenna.radiowaves.left.and.right"
        case .connected: return "checkmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch multipeer.connectionState {
        case .idle: return .gray
        case .searching: return .orange
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        }
    }
}

#Preview {
    BluetoothConnectionView()
}
