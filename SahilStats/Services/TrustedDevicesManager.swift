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
    func hasTrustedDevice(for role: DeviceRoleManager.DeviceRole) -> Bool {
        return _trustedPeers.contains { $0.role == role.rawValue }
    }
    
    // Get trusted device for auto-connect
    func getTrustedPeerForAutoConnect(role: DeviceRoleManager.DeviceRole) -> TrustedPeer? {
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
        var role: String // "controller" or "recorder" - NOW MUTABLE for role switching
        var myRole: String // What role THIS device uses when connecting to this peer
        let dateAdded: Date
        let lastConnected: Date?

        init(peerID: MCPeerID, role: String, myRole: String) {
            self.id = peerID.displayName
            self.deviceName = peerID.displayName
            self.role = role
            self.myRole = myRole
            self.dateAdded = Date()
            self.lastConnected = nil
        }

        // Legacy init for backward compatibility
        init(peerID: MCPeerID, role: String) {
            self.id = peerID.displayName
            self.deviceName = peerID.displayName
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
    func addTrustedPeer(_ peerID: MCPeerID, theirRole: DeviceRoleManager.DeviceRole, myRole: DeviceRoleManager.DeviceRole) {
        // Don't add duplicates
        guard !isTrusted(peerID) else {
            print("⚠️ Peer already trusted: \(peerID.displayName)")
            updateLastConnected(peerID)
            return
        }

        var peers = trustedPeers
        let newPeer = TrustedPeer(peerID: peerID, role: theirRole.rawValue, myRole: myRole.rawValue)
        peers.append(newPeer)
        trustedPeers = peers

        print("✅ Added trusted peer: \(peerID.displayName) - They: \(theirRole.displayName), Me: \(myRole.displayName)")
    }

    /// Legacy method for backward compatibility
    func addTrustedPeer(_ peerID: MCPeerID, role: DeviceRoleManager.DeviceRole) {
        // Infer my role as opposite
        let myRole: DeviceRoleManager.DeviceRole = role == .controller ? .recorder : .controller
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
                role: peer.myRole,
                myRole: tempRole,
                dateAdded: peer.dateAdded,
                lastConnected: peer.lastConnected
            )
            peers[index] = peer
            trustedPeers = peers
            print("🔄 Switched roles with \(peerID.displayName) - They: \(peer.role), Me: \(peer.myRole)")
        }
    }

    /// Get my role when connecting to a specific peer
    func getMyRole(for peerID: MCPeerID) -> DeviceRoleManager.DeviceRole? {
        guard let peer = trustedPeers.first(where: { $0.id == peerID.displayName }) else {
            return nil
        }
        return DeviceRoleManager.DeviceRole(rawValue: peer.myRole)
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
                print("🗑️ Removed trusted peer: \(peerID.displayName)")
            } else {
                print("⚠️ Peer not found for removal: \(peerID.displayName)")
            }
        }
    }
    
    /// Update last connected timestamp for a peer
    func updateLastConnected(_ peerID: MCPeerID) {
        var peers = trustedPeers
        if let index = peers.firstIndex(where: { $0.id == peerID.displayName }) {
            var peer = peers[index]
            peer = TrustedPeer(
                id: peer.id,
                deviceName: peer.deviceName,
                role: peer.role,
                myRole: peer.myRole,
                dateAdded: peer.dateAdded,
                lastConnected: Date()
            )
            peers[index] = peer
            trustedPeers = peers
        }
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
    func getTrustedPeers(forRole role: DeviceRoleManager.DeviceRole) -> [TrustedPeer] {
        return trustedPeers.filter { $0.role == role.rawValue }
    }
    
    /// Clear all trusted devices
    func clearAllTrustedDevices() {
        DispatchQueue.main.async { [weak self] in
            self?.trustedPeers = []
            print("🗑️ Cleared all trusted devices")
        }
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
                role: DeviceRoleManager.DeviceRole(rawValue: peer.role) ?? .none,
                lastConnected: peer.lastConnected ?? peer.dateAdded
            )
        }
    }
}

// MARK: - TrustedDevice model for compatibility
struct TrustedDevice: Identifiable {
    let id: String
    let displayName: String
    let role: DeviceRoleManager.DeviceRole
    let lastConnected: Date
}

// MARK: - TrustedPeer Extension for updating

extension TrustedDevicesManager.TrustedPeer {
    init(id: String, deviceName: String, role: String, myRole: String, dateAdded: Date, lastConnected: Date?) {
        self.id = id
        self.deviceName = deviceName
        self.role = role
        self.myRole = myRole
        self.dateAdded = dateAdded
        self.lastConnected = lastConnected
    }

    // Legacy init for backward compatibility with old data
    init(id: String, deviceName: String, role: String, dateAdded: Date, lastConnected: Date?) {
        self.id = id
        self.deviceName = deviceName
        self.role = role
        self.myRole = role == "controller" ? "recorder" : "controller"
        self.dateAdded = dateAdded
        self.lastConnected = lastConnected
    }
}

struct TrustedDevicesSettingsView: View {
    @ObservedObject private var trustedDevices = TrustedDevicesManager.shared
    @State private var showingClearAlert = false
    
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
                                Text(peer.deviceName)
                                    .font(.headline)
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
                                // Create MCPeerID to remove the peer
                                let peerID = MCPeerID(displayName: peer.id)
                                trustedDevices.removeTrustedPeer(peerID)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Trusted Devices")
            } footer: {
                Text("Trusted devices will automatically connect without approval")
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
    }
}
