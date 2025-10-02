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

class TrustedDevicesManager: ObservableObject {
    static let shared = TrustedDevicesManager()
    
    private let userDefaults = UserDefaults.standard
    private let trustedPeersKey = "com.sahilstats.trustedPeers"
    
    // MARK: - Trusted Peer Model
    
    struct TrustedPeer: Codable, Identifiable {
        let id: String // Peer ID display name (unique identifier)
        let deviceName: String
        let role: String // "controller" or "recorder"
        let dateAdded: Date
        let lastConnected: Date?
        
        init(peerID: MCPeerID, role: String) {
            self.id = peerID.displayName
            self.deviceName = peerID.displayName
            self.role = role
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
    
    /// Add a peer to trusted devices
    func addTrustedPeer(_ peerID: MCPeerID, role: DeviceRoleManager.DeviceRole) {
        // Don't add duplicates
        guard !isTrusted(peerID) else {
            print("⚠️ Peer already trusted: \(peerID.displayName)")
            updateLastConnected(peerID)
            return
        }
        
        var peers = trustedPeers
        let newPeer = TrustedPeer(peerID: peerID, role: role.rawValue)
        peers.append(newPeer)
        trustedPeers = peers
        
        print("✅ Added trusted peer: \(peerID.displayName) as \(role.displayName)")
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
    
    /// Get count of trusted devices
    var trustedDeviceCount: Int {
        return _trustedPeers.count
    }
    
    /// Check if there are any trusted devices
    var hasTrustedDevices: Bool {
        return !_trustedPeers.isEmpty
    }
}

// MARK: - TrustedPeer Extension for updating

extension TrustedDevicesManager.TrustedPeer {
    init(id: String, deviceName: String, role: String, dateAdded: Date, lastConnected: Date?) {
        self.id = id
        self.deviceName = deviceName
        self.role = role
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
