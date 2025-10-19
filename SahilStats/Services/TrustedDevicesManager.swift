//
//  TrustedDevicesManager.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/30/25.
//
//
//  TrustedDevicesManager.swift
//  SahilStats
//
//  Manages trusted Bluetooth peer devices for seamless auto-connection
//

import Foundation
import MultipeerConnectivity
import SwiftUI
import Combine

// MARK: - Device Role Enum (if not defined elsewhere)
extension TrustedDevicesManager {
    // Check if we have any trusted devices for a specific role
    func hasTrustedDevice(for role: DeviceRole) -> Bool {
        return _trustedPeers.contains { $0.role == role.rawValue }
    }
    
    // Get trusted device for auto-connect
    func getTrustedPeerForAutoConnect(role: DeviceRole) -> TrustedPeer? {
        // Return the most recently added trusted device for the given role
        return _trustedPeers
            .filter { $0.role == role.rawValue }
            .sorted { ($0.lastConnected ?? $0.dateAdded) > ($1.lastConnected ?? $1.dateAdded) }
            .first
    }
}

class TrustedDevicesManager: ObservableObject {
    static let shared = TrustedDevicesManager()
    
    private let userDefaults = UserDefaults.standard
    private let trustedPeersKey = "com.sahilstats.trustedPeers"
    
    // MARK: - Trusted Peer Model

    struct TrustedPeer: Codable, Identifiable {
        let id: String // Peer ID display name (unique identifier)
        let deviceName: String
        var friendlyName: String? // Optional user-defined friendly name
        var role: String // "controller" or "recorder" - NOW MUTABLE for role switching
        var myRole: String // What role THIS device uses when connecting to this peer
        let dateAdded: Date
        let lastConnected: Date?

        var displayName: String {
            return friendlyName ?? deviceName
        }

        init(peerID: MCPeerID, role: String, myRole: String) {
            self.id = peerID.displayName
            self.deviceName = peerID.displayName
            self.friendlyName = nil
            self.role = role
            self.myRole = myRole
            self.dateAdded = Date()
            self.lastConnected = nil
        }

        // Legacy init for backward compatibility
        init(peerID: MCPeerID, role: String) {
            self.id = peerID.displayName
            self.deviceName = peerID.displayName
            self.friendlyName = nil
            self.role = role
            // Infer myRole as opposite of their role
            self.myRole = role == "controller" ? "recorder" : "controller"
            self.dateAdded = Date()
            self.lastConnected = nil
        }
    }
    
    // MARK: - Private Properties
    
    @Published private var _trustedPeers: [TrustedPeer] = []
    
    private var trustedPeers: [TrustedPeer] {
        get { _trustedPeers }
        set {
            _trustedPeers = newValue
            saveTrustedPeers()
        }
    }
    
    private func loadTrustedPeers() {
        guard let data = userDefaults.data(forKey: trustedPeersKey),
              let peers = try? JSONDecoder().decode([TrustedPeer].self, from: data) else {
            _trustedPeers = []
            return
        }
        _trustedPeers = peers
    }
    
    private func saveTrustedPeers() {
        if let data = try? JSONEncoder().encode(_trustedPeers) {
            userDefaults.set(data, forKey: trustedPeersKey)
        }
    }
    
    private init() {
        loadTrustedPeers()
    }
    
    // MARK: - Public Methods
    
    /// Check if a peer is trusted
    func isTrusted(_ peerID: MCPeerID) -> Bool {
        return trustedPeers.contains { $0.id == peerID.displayName }
    }
    
    /// Add a peer to trusted devices with both roles specified
    func addTrustedPeer(_ peerID: MCPeerID, theirRole: DeviceRole, myRole: DeviceRole) {
        // Don't add duplicates
        guard !isTrusted(peerID) else {
            debugPrint("⚠️ Peer already trusted: \(peerID.displayName)")
            updateLastConnected(peerID)
            return
        }

        var peers = trustedPeers
        let newPeer = TrustedPeer(peerID: peerID, role: theirRole.rawValue, myRole: myRole.rawValue)
        peers.append(newPeer)
        trustedPeers = peers

        debugPrint("✅ Added trusted peer: \(peerID.displayName) - They: \(theirRole.displayName), Me: \(myRole.displayName)")
    }

    /// Legacy method for backward compatibility
    func addTrustedPeer(_ peerID: MCPeerID, role: DeviceRole) {
        // Infer my role as opposite
        let myRole: DeviceRole = role == .controller ? .recorder : .controller
        addTrustedPeer(peerID, theirRole: role, myRole: myRole)
    }

    /// Switch roles with a trusted peer
    func switchRoles(for peerID: MCPeerID) {
        var peers = trustedPeers
        if let index = peers.firstIndex(where: { $0.id == peerID.displayName }) {
            var peer = peers[index]
            // Swap the roles
            let tempRole = peer.role
            peer = TrustedPeer(
                id: peer.id,
                deviceName: peer.deviceName,
                friendlyName: peer.friendlyName,
                role: peer.myRole,
                myRole: tempRole,
                dateAdded: peer.dateAdded,
                lastConnected: peer.lastConnected
            )
            peers[index] = peer
            trustedPeers = peers
            debugPrint("🔄 Switched roles with \(peerID.displayName) - They: \(peer.role), Me: \(peer.myRole)")
        }
    }

    /// Get my role when connecting to a specific peer
    func getMyRole(for peerID: MCPeerID) -> DeviceRole? {
        guard let peer = trustedPeers.first(where: { $0.id == peerID.displayName }) else {
            debugPrint("⚠️ No saved role found for peer: \(peerID.displayName)")
            debugPrint("   📝 Available trusted peers: \(trustedPeers.map { "\($0.id) (myRole: \($0.myRole))" }.joined(separator: ", "))")
            return nil
        }
        forcePrint("✅ Found saved role for \(peerID.displayName): myRole=\(peer.myRole), theirRole=\(peer.role)")
        return DeviceRole(rawValue: peer.myRole)
    }
    
    /// Remove a peer from trusted devices
    func removeTrustedPeer(_ peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var peers = self.trustedPeers
            let initialCount = peers.count
            peers.removeAll { $0.id == peerID.displayName }

            if peers.count < initialCount {
                self.trustedPeers = peers
                debugPrint("🗑️ Removed trusted peer: \(peerID.displayName)")
            } else {
                debugPrint("⚠️ Peer not found for removal: \(peerID.displayName)")
            }
        }
    }

    /// Remove a peer from trusted devices using TrustedPeer object
    func removeTrustedPeer(_ peer: TrustedPeer) {
        let peerID = MCPeerID(displayName: peer.id)
        removeTrustedPeer(peerID)
    }
    
    /// Update last connected timestamp for a peer
    func updateLastConnected(_ peerID: MCPeerID) {
        var peers = trustedPeers
        if let index = peers.firstIndex(where: { $0.id == peerID.displayName }) {
            var peer = peers[index]
            peer = TrustedPeer(
                id: peer.id,
                deviceName: peer.deviceName,
                friendlyName: peer.friendlyName,
                role: peer.role,
                myRole: peer.myRole,
                dateAdded: peer.dateAdded,
                lastConnected: Date()
            )
            peers[index] = peer
            trustedPeers = peers
        }
    }

    /// Update friendly name for a trusted peer
    func updateFriendlyName(_ peerID: MCPeerID, friendlyName: String?) {
        var peers = trustedPeers
        if let index = peers.firstIndex(where: { $0.id == peerID.displayName }) {
            var peer = peers[index]
            peer = TrustedPeer(
                id: peer.id,
                deviceName: peer.deviceName,
                friendlyName: friendlyName?.isEmpty == true ? nil : friendlyName,
                role: peer.role,
                myRole: peer.myRole,
                dateAdded: peer.dateAdded,
                lastConnected: peer.lastConnected
            )
            peers[index] = peer
            trustedPeers = peers
            debugPrint("✏️ Updated friendly name for \(peerID.displayName) to '\(friendlyName ?? "default")'")
        }
    }

    /// Update friendly name for a trusted peer using TrustedPeer object
    func updateFriendlyName(for peer: TrustedPeer, friendlyName: String?) {
        let peerID = MCPeerID(displayName: peer.id)
        updateFriendlyName(peerID, friendlyName: friendlyName)
    }
    
    /// Get all trusted peers
    var allTrustedPeers: [TrustedPeer] {
        return _trustedPeers
    }
    
    /// Get all trusted peers (for backwards compatibility)
    func getAllTrustedPeers() -> [TrustedPeer] {
        return _trustedPeers
    }
    
    /// Get trusted peers for a specific role
    func getTrustedPeers(forRole role: DeviceRole) -> [TrustedPeer] {
        return trustedPeers.filter { $0.role == role.rawValue }
    }
    
    /// Clear all trusted devices
    func clearAllTrustedDevices() {
        DispatchQueue.main.async { [weak self] in
            self?.trustedPeers = []
            debugPrint("🗑️ Cleared all trusted devices")
        }
    }

    /// Clear all trusted peers (alias for clearAllTrustedDevices)
    func clearAllTrustedPeers() {
        clearAllTrustedDevices()
    }
    
    /// Remove a trusted device by TrustedDevice object
    func removeTrustedDevice(_ device: TrustedDevice) {
        let peerID = MCPeerID(displayName: device.id)
        removeTrustedPeer(peerID)
    }
    
    /// Get count of trusted devices
    var trustedDeviceCount: Int {
        return _trustedPeers.count
    }
    
    /// Check if there are any trusted devices
    var hasTrustedDevices: Bool {
        return !_trustedPeers.isEmpty
    }
    
    /// Computed property for backwards compatibility
    var trustedDevices: [TrustedDevice] {
        return _trustedPeers.map { peer in
            TrustedDevice(
                id: peer.id,
                displayName: peer.deviceName,
                role: DeviceRole(rawValue: peer.role) ?? .none,
                lastConnected: peer.lastConnected ?? peer.dateAdded
            )
        }
    }
}

// MARK: - TrustedDevice model for compatibility
struct TrustedDevice: Identifiable {
    let id: String
    let displayName: String
    let role: DeviceRole
    let lastConnected: Date
}

// MARK: - TrustedPeer Extension for updating

extension TrustedDevicesManager.TrustedPeer {
    init(id: String, deviceName: String, friendlyName: String?, role: String, myRole: String, dateAdded: Date, lastConnected: Date?) {
        self.id = id
        self.deviceName = deviceName
        self.friendlyName = friendlyName
        self.role = role
        self.myRole = myRole
        self.dateAdded = dateAdded
        self.lastConnected = lastConnected
    }

    // Legacy init for backward compatibility with old data
    init(id: String, deviceName: String, role: String, dateAdded: Date, lastConnected: Date?) {
        self.id = id
        self.deviceName = deviceName
        self.friendlyName = nil
        self.role = role
        self.myRole = role == "controller" ? "recorder" : "controller"
        self.dateAdded = dateAdded
        self.lastConnected = lastConnected
    }
}

struct TrustedDevicesSettingsView: View {
    @ObservedObject private var trustedDevices = TrustedDevicesManager.shared
    @State private var showingClearAlert = false
    @State private var editingPeer: TrustedDevicesManager.TrustedPeer?
    @State private var editedFriendlyName = ""

    var body: some View {
        List {
            Section {
                if trustedDevices.allTrustedPeers.isEmpty {
                    Text("No trusted devices")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(trustedDevices.allTrustedPeers) { peer in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(peer.displayName)
                                    .font(.headline)
                                if peer.friendlyName != nil {
                                    Text(peer.deviceName)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Text(peer.role.capitalized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if let lastConnected = peer.lastConnected {
                                    Text("Last connected: \(lastConnected.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Button(action: {
                                editingPeer = peer
                                editedFriendlyName = peer.friendlyName ?? ""
                            }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                // Create MCPeerID to remove the peer
                                let peerID = MCPeerID(displayName: peer.id)
                                trustedDevices.removeTrustedPeer(peerID)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Trusted Devices")
            } footer: {
                Text("Trusted devices will automatically connect without approval. Tap the pencil icon to set a friendly name.")
            }

            Section {
                Button("Clear All Trusted Devices") {
                    showingClearAlert = true
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Trusted Devices")
        .alert("Clear All Trusted Devices?", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                trustedDevices.clearAllTrustedDevices()
            }
        }
        .sheet(item: $editingPeer) { peer in
            NavigationView {
                Form {
                    Section {
                        TextField("Friendly Name", text: $editedFriendlyName)
                    } header: {
                        Text("Edit Device Name")
                    } footer: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Original name: \(peer.deviceName)")
                                .font(.caption)
                            Text("Leave empty to use the original device name")
                                .font(.caption)
                        }
                    }
                }
                .navigationTitle("Rename Device")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            editingPeer = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let peerID = MCPeerID(displayName: peer.id)
                            trustedDevices.updateFriendlyName(peerID, friendlyName: editedFriendlyName)
                            editingPeer = nil
                        }
                    }
                }
            }
        }
    }
}
