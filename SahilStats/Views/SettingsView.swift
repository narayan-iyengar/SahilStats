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
                    UserStatusIndicator()
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
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                AdminStatusIndicator()
            }
        }
        .sheet(isPresented: $showingAuth) {
            AuthView()
        }
    }
    
    @ObservedObject private var settingsManager = SettingsManager.shared
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


struct RoleSelectionCard: View {
    let role: DeviceRole
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: role == .controller ? "gamecontroller.fill" : "video.fill")
                    .font(.largeTitle)
                    .foregroundColor(isSelected ? .white : (role == .controller ? .blue : .red))
                
                Text(role.displayName)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(role == .controller ? "Manage games" : "Record games")
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? .orange : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? .orange : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct DevicePairingView: View {
    @Binding var isPairing: Bool
    @ObservedObject private var multipeer = MultipeerConnectivityManager.shared
    @ObservedObject private var roleManager = DeviceRoleManager.shared
    @ObservedObject private var trustedDevicesManager = TrustedDevicesManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedRole: DeviceRole = .controller
    @State private var showingPairingConfirmation = false
    @State private var deviceToPair: MCPeerID?
    @State private var cancellables = Set<AnyCancellable>() // Add this for subscriptions
    
    // Use discoveredPeers and pendingInvitations directly from multipeer
    private var nearbyDevices: [MCPeerID] {
        var allPeers = multipeer.discoveredPeers
        
        // Add peers from pending invitations
        for invitation in multipeer.pendingInvitations {
            if !allPeers.contains(where: { $0.displayName == invitation.peerID.displayName }) {
                allPeers.append(invitation.peerID)
            }
        }
        
        return allPeers
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
                    
                    if !nearbyDevices.isEmpty {
                        Text("\(nearbyDevices.count) found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if isPairing {
                    LoadingView()
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
            setupMessageSubscriptions()
            startScanning()
        }
        .onDisappear {
            print("🔵 DevicePairingView disappeared")
            // Only stop scanning if NOT connected (user cancelled)
            if !multipeer.connectionState.isConnected {
                print("🛑 User cancelled pairing, stopping scan")
                stopScanning()
            } else {
                print("✅ Keeping connection alive after successful pairing")
                // Just stop browsing/advertising, keep the session alive
                multipeer.stopBrowsing()
                multipeer.stopAdvertising()
            }
            cancellables.removeAll()
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
    
    private func setupMessageSubscriptions() {
        // Subscribe to connection state changes
        multipeer.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { state in
                if case .connected = state {
                    handleConnectionEstablished()
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleConnectionEstablished() {
        print("✅ Connection established for pairing")

        // Get the connected peer
        guard let peer = multipeer.connectedPeers.first else { return }

        // Determine roles: my role and their role
        let myRole = selectedRole
        let theirRole: DeviceRole = (selectedRole == .controller) ? .recorder : .controller

        print("📝 Saving pairing - Me: \(myRole.displayName), Them: \(theirRole.displayName)")

        // Save the peer with BOTH roles (theirs and mine)
        trustedDevicesManager.addTrustedPeer(peer, theirRole: theirRole, myRole: myRole)

        // Set my preferred role for future connections
        roleManager.setPreferredRole(myRole)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("✅ Pairing complete, keeping connection alive")
            // DON'T call stopScanning() - that kills the connection!
            // Just stop browsing/advertising since we're already connected
            multipeer.stopBrowsing()
            multipeer.stopAdvertising()
            dismiss()
        }
    }
    
    private func startScanning() {
        print("🔍 Starting scan for role: \(selectedRole.displayName)")
        isPairing = true

        // Clear previous discoveries
        multipeer.clearDiscoveredPeers()

        // Use startSession with the selected role for proper symmetric discovery
        print("🔍📡 Starting session as \(selectedRole.displayName) for pairing")
        multipeer.startSession(role: selectedRole)

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
    }
    
    private func pairDevice() {
        guard let peer = deviceToPair else { return }
        
        print("🔗 Attempting to pair with: \(peer.displayName)")
        
        // Check if we have a pending invitation from this peer
        if let invitation = multipeer.pendingInvitations.first(where: { $0.peerID == peer }) {
            print("✅ Found pending invitation from this peer, accepting it")
            multipeer.approveConnection(for: peer, remember: true)
        } else {
            print("📤 Sending invitation to peer")
            multipeer.invitePeer(peer)
        }
    }
}

struct BackgroundConnectionIndicator: View {
    @ObservedObject private var multipeer = MultipeerConnectivityManager.shared
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                HStack(spacing: 8) {
                    if multipeer.connectionState.isConnected {
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
