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

class TrustedDevicesManager {
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
    
    private var trustedPeers: [TrustedPeer] {
        get {
            guard let data = userDefaults.data(forKey: trustedPeersKey),
                  let peers = try? JSONDecoder().decode([TrustedPeer].self, from: data) else {
                return []
            }
            return peers
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                userDefaults.set(data, forKey: trustedPeersKey)
            }
        }
    }
    
    private init() {}
    
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
        var peers = trustedPeers
        peers.removeAll { $0.id == peerID.displayName }
        trustedPeers = peers
        
        print("🗑️ Removed trusted peer: \(peerID.displayName)")
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
    func getAllTrustedPeers() -> [TrustedPeer] {
        return trustedPeers
    }
    
    /// Get trusted peers for a specific role
    func getTrustedPeers(forRole role: DeviceRoleManager.DeviceRole) -> [TrustedPeer] {
        return trustedPeers.filter { $0.role == role.rawValue }
    }
    
    /// Clear all trusted devices
    func clearAllTrustedDevices() {
        trustedPeers = []
        print("🗑️ Cleared all trusted devices")
    }
    
    /// Get count of trusted devices
    var trustedDeviceCount: Int {
        return trustedPeers.count
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
