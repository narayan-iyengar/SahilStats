//
//  SettingsView.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/17/25.
//
// File: SahilStats/Views/SettingsView.swift (Enhanced)

import SwiftUI
import FirebaseAuth
import FirebaseCore
import Combine
import MultipeerConnectivity

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingAuth = false
    
    var body: some View {
        List {
            // Account Section
            Section("Account") {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(authService.userRole.displayName)
                        .foregroundColor(.secondary)
                }
                
                if authService.isSignedIn && !authService.currentUser!.isAnonymous {
                    NavigationLink("Account Details") {
                        AccountDetailsView()
                    }
                } else {
                    Button("Sign In") {
                        showingAuth = true
                    }
                    .foregroundColor(.orange)
                }
            }
            
            // Admin Features
            if authService.showAdminFeatures {
                Section("Game Management") {
                    NavigationLink("Teams") {
                        TeamsSettingsView()
                    }
                    
                    NavigationLink("Game Format") {
                        GameFormatSettingsView()
                    }
                    
                    NavigationLink("Live Games") {
                        LiveGamesSettingsView()
                    }
                }
                
                Section("Media & Recording") {
                    NavigationLink("Camera") {
                        CameraSettingsView()
                    }
                    
                    NavigationLink("YouTube") {
                        YouTubeSettingsView()
                    }
                    
                    NavigationLink("Storage") {
                        StorageSettingsView()
                    }
                }
                
                Section("Devices & Connectivity") {
                    NavigationLink("Device Pairing") {
                        DevicePairingMainView()
                    }
                    
                    NavigationLink("Trusted Devices") {
                        TrustedDevicesSettingsView()
                    }
                    
                    Toggle("Auto-connect to Trusted Devices", isOn: $settingsManager.autoConnectEnabled)
                        .disabled(!trustedDevicesManager.hasTrustedDevices)
                        .toggleStyle(SwitchToggleStyle(tint: .orange))
                }
            }
            
            // App Info
            Section {
                NavigationLink("About") {
                    AppInfoView()
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingAuth) {
            AuthView()
        }
    }
    
    @StateObject private var settingsManager = SettingsManager.shared
    @ObservedObject private var trustedDevicesManager = TrustedDevicesManager.shared
}

// MARK: - Settings Manager for Persistent Settings

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var gameFormat: GameFormat {
        didSet {
            UserDefaults.standard.set(gameFormat.rawValue, forKey: "gameFormat")
        }
    }
    
    @Published var quarterLength: Int {
        didSet {
            UserDefaults.standard.set(quarterLength, forKey: "quarterLength")
        }
    }
    
    @Published var enableMultiDevice: Bool = false {
        didSet {
            UserDefaults.standard.set(enableMultiDevice, forKey: "enableMultiDevice")
        }
    }

    @Published var videoQuality: String = "High" {
        didSet {
            UserDefaults.standard.set(videoQuality, forKey: "videoQuality")
        }
    }
    @Published var autoConnectEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(autoConnectEnabled, forKey: "autoConnectEnabled")
        }
    }
    
    
    private init() {
        // Load saved settings or use defaults
        if let savedFormat = UserDefaults.standard.string(forKey: "gameFormat"),
           let format = GameFormat(rawValue: savedFormat) {
            self.gameFormat = format
        } else {
            self.gameFormat = .halves // Default to halves
        }
        
        let savedLength = UserDefaults.standard.integer(forKey: "quarterLength")
        self.quarterLength = savedLength > 0 ? savedLength : 20 // Default to 20 minutes
        
        self.enableMultiDevice = UserDefaults.standard.bool(forKey: "enableMultiDevice")
        self.videoQuality = UserDefaults.standard.string(forKey: "videoQuality") ?? "High"
        self.autoConnectEnabled = UserDefaults.standard.bool(forKey: "autoConnectEnabled")
    }
    
    // Helper method to get default game settings for new games
    func getDefaultGameSettings() -> (format: GameFormat, length: Int) {
        return (gameFormat, quarterLength)
    }
}

// MARK: - Enhanced Team Model (if needed)

extension Team {
    var gamesPlayed: Int {
        // This would need to be calculated from games where this team was used
        // For now, return 0 as placeholder
        return 0
    }
}

struct DevicePairingMainView: View {
    @ObservedObject private var trustedDevicesManager = TrustedDevicesManager.shared
    @ObservedObject private var multipeer = MultipeerConnectivityManager.shared
    @State private var isPairing = false
    
    var body: some View {
        List {
            Section {
                if trustedDevicesManager.trustedDevices.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No Trusted Devices")
                            .foregroundColor(.secondary)
                        Text("Pair devices to enable instant auto-connect for recording")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(trustedDevicesManager.trustedDevices) { device in
                        HStack {
                            Image(systemName: device.role == .controller ? "gamecontroller.fill" : "video.fill")
                                .foregroundColor(device.role == .controller ? .blue : .red)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.displayName)
                                    .font(.body)
                                Text(device.role.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if multipeer.connectedPeers.contains(where: { $0.displayName == device.displayName }) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            } header: {
                Text("Paired Devices")
            }
            
            Section {
                NavigationLink(destination: DevicePairingView(isPairing: $isPairing)) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Pair New Device")
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .navigationTitle("Device Pairing")
    }
}


struct DevicePairingView: View {
    @Binding var isPairing: Bool
    @StateObject private var multipeer = MultipeerConnectivityManager.shared
    @StateObject private var roleManager = DeviceRoleManager.shared
    @ObservedObject private var trustedDevicesManager = TrustedDevicesManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedRole: DeviceRoleManager.DeviceRole = .controller
    // REMOVED: @State private var nearbyDevices: [MCPeerID] = []
    @State private var showingPairingConfirmation = false
    @State private var deviceToPair: MCPeerID?
    
    @State private var peersFromInvitations: [MCPeerID] = []
    
    // NEW: Use multipeer.discoveredPeers directly
    private var nearbyDevices: [MCPeerID] {
        let allPeers = multipeer.discoveredPeers + peersFromInvitations
        var uniquePeers: [MCPeerID] = []
        for peer in allPeers {
            if !uniquePeers.contains(where: { $0.displayName == peer.displayName }) {
                uniquePeers.append(peer)
            }
        }
        return uniquePeers
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Step 1: Choose your role
            VStack(alignment: .leading, spacing: 16) {
                Text("Step 1: Choose This Device's Role")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    RoleSelectionCard(
                        role: .controller,
                        isSelected: selectedRole == .controller
                    ) {
                        selectedRole = .controller
                        startScanning()
                    }
                    
                    RoleSelectionCard(
                        role: .recorder,
                        isSelected: selectedRole == .recorder
                    ) {
                        selectedRole = .recorder
                        startScanning()
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
            
            // Step 2: Find and pair devices
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Step 2: Select Device to Pair")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // NEW: Show device count
                    if !nearbyDevices.isEmpty {
                        Text("\(nearbyDevices.count) found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if isPairing {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Searching for \(selectedRole == .controller ? "recorders" : "controllers")...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // NEW: Show scan duration
                        Text("This may take a few seconds...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else if nearbyDevices.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No devices found")
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 4) {
                            Text("Make sure the other device:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("• Is in Settings > Pair New Device")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("• Has Bluetooth enabled")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("• Is nearby (within 30 feet)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .multilineTextAlignment(.leading)
                        
                        Button("Scan Again") {
                            startScanning()
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(nearbyDevices, id: \.displayName) { peer in
                                Button(action: {
                                    deviceToPair = peer
                                    showingPairingConfirmation = true
                                }) {
                                    HStack {
                                        Image(systemName: selectedRole == .controller ? "video.fill" : "gamecontroller.fill")
                                            .foregroundColor(selectedRole == .controller ? .red : .blue)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(peer.displayName)
                                                .foregroundColor(.primary)
                                                .fontWeight(.medium)
                                            
                                            Text(selectedRole == .controller ? "Recorder" : "Controller")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Pair Device")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            print("🔵 DevicePairingView appeared")
            setupInvitationHandler()
            startScanning()
        }
        .onDisappear {
            print("🔵 DevicePairingView disappeared")
            stopScanning()
            cleanupInvitationHandler()
        }
        .alert("Pair with \(deviceToPair?.displayName ?? "Device")?", isPresented: $showingPairingConfirmation) {
            Button("Cancel", role: .cancel) {
                deviceToPair = nil
            }
            Button("Pair") {
                pairDevice()
            }
        } message: {
            Text("This device will be trusted and automatically connect in the future.")
        }
    }
    
    private func setupInvitationHandler() {
        multipeer.onPendingInvitation = { peer in
            print("📨 Received invitation from \(peer.displayName) during pairing")
            DispatchQueue.main.async {
                if !self.peersFromInvitations.contains(where: { $0.displayName == peer.displayName }) {
                    self.peersFromInvitations.append(peer)
                    print("✅ Added invitation peer to pairing list: \(peer.displayName)")
                }
            }
        }
    }

    // ✅ ADD THIS METHOD:
    private func cleanupInvitationHandler() {
        multipeer.onPendingInvitation = nil
        peersFromInvitations.removeAll()
    }
    
    private func startScanning() {
        print("🔍 Starting scan for role: \(selectedRole.displayName)")
        isPairing = true
        
        // Clear previous discoveries
        multipeer.clearDiscoveredPeers()
        peersFromInvitations.removeAll()  // ✅ ADD THIS LINE
        
        // ✅ REPLACE the if/else with these two lines:
        print("🔍📡 Starting BOTH browsing and advertising for pairing")
        multipeer.startBrowsing()
        if selectedRole == .controller {
            multipeer.startAdvertising(as: "controller")
        } else {
            multipeer.startAdvertising(as: "recorder")
        }
        
        // Stop spinner after scan period
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            print("⏱️ Scan period completed. Found \(self.nearbyDevices.count) devices")
            
            if self.nearbyDevices.isEmpty {
                print("❌ No devices discovered during scan")
            } else {
                print("✅ Discovered devices:")
                for peer in self.nearbyDevices {
                    print("   - \(peer.displayName)")
                }
            }
            
            self.isPairing = false
        }
    }
    
    private func stopScanning() {
        print("🛑 Stopping scan")
        multipeer.stopAll()
        multipeer.onPeerDiscovered = nil
    }
    
    private func pairDevice() {
        guard let peer = deviceToPair else { return }
        
        print("🔗 Attempting to pair with: \(peer.displayName)")
        
        // ✅ ADD THIS CHECK:
        if let invitation = multipeer.pendingInvitations.first(where: { $0.peerID == peer }) {
            print("✅ Found pending invitation from this peer, accepting it")
            multipeer.approveConnection(for: peer, remember: false)
        } else {
            print("📤 Sending invitation to peer")
            multipeer.invitePeer(peer)
        }
        
        // Set up connection callback
        multipeer.onConnectionEstablished = {
            print("✅ Connection established for pairing")
            
            let peerRole: DeviceRoleManager.DeviceRole = selectedRole == .controller ? .recorder : .controller
            trustedDevicesManager.addTrustedPeer(peer, role: peerRole)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("✅ Pairing complete, dismissing")
                stopScanning()
                dismiss()
            }
        }
    }
}

struct RoleSelectionCard: View {
    let role: DeviceRoleManager.DeviceRole
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: role.icon)
                    .font(.largeTitle)
                    .foregroundColor(isSelected ? .white : role.color)
                
                Text(role.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(isSelected ? role.color : Color(.systemGray5))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct BackgroundConnectionIndicator: View {
    @StateObject private var multipeer = MultipeerConnectivityManager.shared
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                HStack(spacing: 8) {
                    if multipeer.isConnected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Connected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Connecting...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.1), radius: 4)
            }
            .padding()
            
            Spacer()
        }
    }
}


#Preview {
    NavigationView {
        SettingsView()
            .environmentObject(AuthService())
    }
}
