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
import FirebaseFirestore
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
            
            // Removed Beta Features - pivoting to NAS-based processing

            // Admin Features
            if authService.showAdminFeatures {

                Section("Game Management") {
                    NavigationLink("Teams") {
                        TeamsSettingsView()
                    }

                    NavigationLink("Game Format") {
                        GameFormatSettingsView()
                    }

                    NavigationLink("Calendar Settings") {
                        CalendarSettingsView()
                    }

                    LiveGameStatusRow()
                }
                
                Section("Media & Recording") {
                    NavigationLink("Camera") {
                        CameraSettingsView()
                    }

                    NavigationLink("YouTube") {
                        YouTubeSettingsView()
                    }

                    NavigationLink("NAS Upload") {
                        NASSettingsView()
                    }

                    NavigationLink("Storage") {
                        StorageSettingsView()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Keep Videos After Upload", isOn: $settingsManager.keepVideosAfterUpload)
                            .toggleStyle(SwitchToggleStyle(tint: .orange))

                        if settingsManager.keepVideosAfterUpload {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.caption)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Videos Preserved")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)

                                    Text("Videos and timeline data will be saved after YouTube upload for NAS processing.")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                
                Section {
                    // Consolidated: Device Pairing shows trusted devices inline
                    NavigationLink("Device Pairing & Trusted Devices") {
                        DevicePairingMainView()
                    }

                    Toggle("Auto-connect to Trusted Devices", isOn: $settingsManager.autoConnectEnabled)
                        .disabled(!trustedDevicesManager.hasTrustedDevices)
                        .toggleStyle(SwitchToggleStyle(tint: .orange))

                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Verbose Logging", isOn: $settingsManager.verboseLoggingEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: .orange))

                        if settingsManager.verboseLoggingEnabled {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Performance Impact")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.orange)

                                    Text("Turn OFF before games at the gym. Logging slows down performance and clutters the console.")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(8)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                } header: {
                    Text("Devices & Connectivity")
                } footer: {
                    if settingsManager.verboseLoggingEnabled {
                        Text("⚠️ Verbose logging is ON - remember to disable before recording")
                            .foregroundColor(.orange)
                    }
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
            saveSettings()
        }
    }

    @Published var quarterLength: Int {
        didSet {
            saveSettings()
        }
    }

    @Published var enableMultiDevice: Bool = false {
        didSet {
            saveSettings()
        }
    }

    @Published var videoQuality: String = "High" {
        didSet {
            saveSettings()
        }
    }

    @Published var autoConnectEnabled: Bool = true {
        didSet {
            saveSettings()
        }
    }

    @Published var verboseConnectionLogging: Bool = false {
        didSet {
            saveSettings()
            // Update MultipeerConnectivityManager when this changes
            MultipeerConnectivityManager.shared.setVerboseLogging(verboseConnectionLogging)
        }
    }

    @Published var verboseLoggingEnabled: Bool {
        didSet {
            saveSettings()
        }
    }

    @Published var betaFeaturesEnabled: Bool {
        didSet {
            saveSettings()
        }
    }

    @Published var keepVideosAfterUpload: Bool {
        didSet {
            saveSettings()
        }
    }

    @Published var nasUploadURL: String {
        didSet {
            saveSettings()
        }
    }

    private var userId: String?

    private init() {
        // Load from local cache first (instant load)
        // Initialize @Published properties from UserDefaults BEFORE calling super.init
        if let savedFormat = UserDefaults.standard.string(forKey: "gameFormat"),
           let format = GameFormat(rawValue: savedFormat) {
            self.gameFormat = format
        } else {
            self.gameFormat = .halves
        }

        let savedLength = UserDefaults.standard.integer(forKey: "quarterLength")
        self.quarterLength = savedLength > 0 ? savedLength : 20

        self.enableMultiDevice = UserDefaults.standard.bool(forKey: "enableMultiDevice")
        self.videoQuality = UserDefaults.standard.string(forKey: "videoQuality") ?? "High"

        if let autoConnect = UserDefaults.standard.object(forKey: "autoConnectEnabled") as? Bool {
            self.autoConnectEnabled = autoConnect
        } else {
            self.autoConnectEnabled = true
        }

        self.verboseConnectionLogging = UserDefaults.standard.bool(forKey: "verboseConnectionLogging")
        self.verboseLoggingEnabled = UserDefaults.standard.bool(forKey: "verboseLoggingEnabled")
        self.betaFeaturesEnabled = UserDefaults.standard.bool(forKey: "betaFeaturesEnabled")

        // Default to false (delete videos as before) until user opts in to keep them
        if let keepVideos = UserDefaults.standard.object(forKey: "keepVideosAfterUpload") as? Bool {
            self.keepVideosAfterUpload = keepVideos
        } else {
            self.keepVideosAfterUpload = false
        }

        self.nasUploadURL = UserDefaults.standard.string(forKey: "nasUploadURL") ?? ""

        debugPrint("📱 Loaded settings from local cache")

        // Apply verbose logging setting to MultipeerConnectivityManager
        MultipeerConnectivityManager.shared.setVerboseLogging(verboseConnectionLogging)

        // Load from Firebase in background
        Task {
            await loadFromFirebase()
        }
    }

    func setUserId(_ userId: String) {
        self.userId = userId
        Task {
            await loadFromFirebase()
        }
    }

    private func loadFromFirebase() async {
        guard let userId = userId ?? FirebaseAuth.Auth.auth().currentUser?.uid else {
            print("⚠️ No user ID available - using local settings only")
            return
        }

        do {
            let db = FirebaseFirestore.Firestore.firestore()
            let document = try await db.collection("userSettings").document(userId).getDocument()

            if let data = document.data() {
                await MainActor.run {
                    if let formatString = data["gameFormat"] as? String,
                       let format = GameFormat(rawValue: formatString) {
                        self.gameFormat = format
                        UserDefaults.standard.set(formatString, forKey: "gameFormat")
                    }

                    if let length = data["quarterLength"] as? Int {
                        self.quarterLength = length
                        UserDefaults.standard.set(length, forKey: "quarterLength")
                    }

                    if let multiDevice = data["enableMultiDevice"] as? Bool {
                        self.enableMultiDevice = multiDevice
                        UserDefaults.standard.set(multiDevice, forKey: "enableMultiDevice")
                    }

                    if let quality = data["videoQuality"] as? String {
                        self.videoQuality = quality
                        UserDefaults.standard.set(quality, forKey: "videoQuality")
                    }

                    if let autoConnect = data["autoConnectEnabled"] as? Bool {
                        self.autoConnectEnabled = autoConnect
                        UserDefaults.standard.set(autoConnect, forKey: "autoConnectEnabled")
                    }

                    if let verboseLogging = data["verboseConnectionLogging"] as? Bool {
                        self.verboseConnectionLogging = verboseLogging
                        UserDefaults.standard.set(verboseLogging, forKey: "verboseConnectionLogging")
                    }

                    if let verboseEnabled = data["verboseLoggingEnabled"] as? Bool {
                        self.verboseLoggingEnabled = verboseEnabled
                        UserDefaults.standard.set(verboseEnabled, forKey: "verboseLoggingEnabled")
                    }

                    if let betaEnabled = data["betaFeaturesEnabled"] as? Bool {
                        self.betaFeaturesEnabled = betaEnabled
                        UserDefaults.standard.set(betaEnabled, forKey: "betaFeaturesEnabled")
                    }

                    if let keepVideos = data["keepVideosAfterUpload"] as? Bool {
                        self.keepVideosAfterUpload = keepVideos
                        UserDefaults.standard.set(keepVideos, forKey: "keepVideosAfterUpload")
                    }

                    if let nasURL = data["nasUploadURL"] as? String {
                        self.nasUploadURL = nasURL
                        UserDefaults.standard.set(nasURL, forKey: "nasUploadURL")
                    }

                    debugPrint("☁️ Loaded settings from Firebase")
                }
            } else {
                debugPrint("📱 No settings in Firebase - saving current settings")
                await saveToFirebase()
            }
        } catch {
            debugPrint("❌ Failed to load settings from Firebase: \(error)")
        }
    }

    private func saveSettings() {
        // Save to local cache immediately
        UserDefaults.standard.set(gameFormat.rawValue, forKey: "gameFormat")
        UserDefaults.standard.set(quarterLength, forKey: "quarterLength")
        UserDefaults.standard.set(enableMultiDevice, forKey: "enableMultiDevice")
        UserDefaults.standard.set(videoQuality, forKey: "videoQuality")
        UserDefaults.standard.set(autoConnectEnabled, forKey: "autoConnectEnabled")
        UserDefaults.standard.set(verboseConnectionLogging, forKey: "verboseConnectionLogging")
        UserDefaults.standard.set(verboseLoggingEnabled, forKey: "verboseLoggingEnabled")
        UserDefaults.standard.set(betaFeaturesEnabled, forKey: "betaFeaturesEnabled")
        UserDefaults.standard.set(keepVideosAfterUpload, forKey: "keepVideosAfterUpload")
        UserDefaults.standard.set(nasUploadURL, forKey: "nasUploadURL")

        // Save to Firebase in background
        Task {
            await saveToFirebase()
        }
    }

    private func saveToFirebase() async {
        guard let userId = userId ?? FirebaseAuth.Auth.auth().currentUser?.uid else {
            debugPrint("⚠️ No user ID available - skipping Firebase save")
            return
        }

        do {
            let db = FirebaseFirestore.Firestore.firestore()
            try await db.collection("userSettings").document(userId).setData([
                "gameFormat": gameFormat.rawValue,
                "quarterLength": quarterLength,
                "enableMultiDevice": enableMultiDevice,
                "videoQuality": videoQuality,
                "autoConnectEnabled": autoConnectEnabled,
                "verboseConnectionLogging": verboseConnectionLogging,
                "verboseLoggingEnabled": verboseLoggingEnabled,
                "betaFeaturesEnabled": betaFeaturesEnabled,
                "keepVideosAfterUpload": keepVideosAfterUpload,
                "nasUploadURL": nasUploadURL
            ], merge: true)

            debugPrint("☁️ Settings saved to Firebase")
        } catch {
            debugPrint("❌ Failed to save settings to Firebase: \(error)")
        }
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
    @State private var editingDevice: TrustedDevicesManager.TrustedPeer?
    @State private var showingClearAllAlert = false

    var body: some View {
        List {
            Section {
                if trustedDevicesManager.allTrustedPeers.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No Trusted Devices")
                            .foregroundColor(.secondary)
                        Text("Pair devices to enable instant auto-connect for recording")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(trustedDevicesManager.allTrustedPeers) { device in
                        Button(action: {
                            editingDevice = device
                        }) {
                            HStack {
                                Image(systemName: device.role == "controller" ? "gamecontroller.fill" : "video.fill")
                                    .foregroundColor(device.role == "controller" ? .blue : .red)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.displayName)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    HStack(spacing: 4) {
                                        Text(device.role.capitalized)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if device.friendlyName != nil {
                                            Text("•")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text("Custom name")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                }

                                Spacer()

                                if multipeer.connectedPeers.contains(where: { $0.displayName == device.id }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            trustedDevicesManager.removeTrustedPeer(trustedDevicesManager.allTrustedPeers[index])
                        }
                    }
                }
            } header: {
                Text("Paired Devices")
            } footer: {
                if !trustedDevicesManager.allTrustedPeers.isEmpty {
                    Text("Tap a device to edit its name. Swipe to delete.")
                        .font(.caption)
                }
            }

            Section {
                NavigationLink(destination: DevicePairingView(isPairing: $isPairing)) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Pair New Device")
                    }
                    .foregroundColor(.orange)
                }

                if !trustedDevicesManager.allTrustedPeers.isEmpty {
                    Button(action: {
                        showingClearAllAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Clear All Devices")
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .navigationTitle("Device Pairing")
        .sheet(item: $editingDevice) { device in
            EditDeviceNameView(device: device)
        }
        .alert("Clear All Devices?", isPresented: $showingClearAllAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                trustedDevicesManager.clearAllTrustedPeers()
            }
        } message: {
            Text("This will remove all trusted devices. You'll need to pair them again.")
        }
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
        if multipeer.pendingInvitations.first(where: { $0.peerID == peer }) != nil {
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

struct LiveGameStatusRow: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var showingDeleteAlert = false

    var body: some View {
        HStack {
            // Status indicator
            if firebaseService.hasLiveGame {
                Image(systemName: "circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Text("\(firebaseService.liveGames.count) live game\(firebaseService.liveGames.count == 1 ? "" : "s") active")
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "circle.fill")
                    .foregroundColor(.gray)
                    .font(.caption)
                Text("No live games")
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Delete button (only show if there are live games)
            if firebaseService.hasLiveGame {
                Button("Delete All") {
                    showingDeleteAlert = true
                }
                .foregroundColor(.red)
                .font(.subheadline)
            }
        }
        .alert("Delete Live Games", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteAllLiveGames()
            }
        } message: {
            Text("Are you sure you want to delete \(firebaseService.liveGames.count) live game\(firebaseService.liveGames.count == 1 ? "" : "s")?")
        }
        .onAppear {
            firebaseService.startListening()
        }
    }

    private func deleteAllLiveGames() {
        Task {
            do {
                try await firebaseService.deleteAllLiveGames()
            } catch {
                print("Failed to delete live games: \(error)")
            }
        }
    }
}

// MARK: - Edit Device Name Sheet

struct EditDeviceNameView: View {
    let device: TrustedDevicesManager.TrustedPeer
    @ObservedObject private var trustedDevicesManager = TrustedDevicesManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var friendlyName: String
    @State private var showingDeleteAlert = false

    init(device: TrustedDevicesManager.TrustedPeer) {
        self.device = device
        _friendlyName = State(initialValue: device.friendlyName ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Image(systemName: device.role == "controller" ? "gamecontroller.fill" : "video.fill")
                            .foregroundColor(device.role == "controller" ? .blue : .red)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.deviceName)
                                .font(.body)
                            Text(device.role.capitalized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Device Info")
                }

                Section {
                    TextField("Friendly Name (optional)", text: $friendlyName)
                        .textInputAutocapitalization(.words)

                    if !friendlyName.isEmpty {
                        Text("This name will be shown instead of '\(device.deviceName)'")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Custom Name")
                } footer: {
                    Text("Give this device a friendly name like 'Dad's iPhone' or 'Recording iPad'")
                }

                Section {
                    Button(role: .destructive, action: {
                        showingDeleteAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Remove Device")
                        }
                    }
                } footer: {
                    Text("Remove this device from trusted devices. You'll need to pair it again to reconnect.")
                }
            }
            .navigationTitle("Edit Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Remove Device?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    trustedDevicesManager.removeTrustedPeer(device)
                    dismiss()
                }
            } message: {
                Text("This device will be removed from trusted devices. You'll need to pair it again to reconnect.")
            }
        }
    }

    private func saveChanges() {
        let trimmedName = friendlyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let newFriendlyName = trimmedName.isEmpty ? nil : trimmedName

        trustedDevicesManager.updateFriendlyName(for: device, friendlyName: newFriendlyName)
        dismiss()
    }
}

#Preview {
    NavigationView {
        SettingsView()
            .environmentObject(AuthService())
    }
}
