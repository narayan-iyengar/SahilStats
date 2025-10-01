//
//  MultipeerConnectivityManager.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/29/25.
//

// File: SahilStats/Services/MultipeerConnectivityManager.swift
// Bluetooth connectivity for direct device-to-device communication

import Foundation
import MultipeerConnectivity
import Combine

class MultipeerConnectivityManager: NSObject, ObservableObject {
    static let shared = MultipeerConnectivityManager()
    
    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var connectedPeers: [MCPeerID] = []
    @Published var nearbyPeers: [MCPeerID] = []
    @Published var isAdvertising = false
    @Published var isBrowsing = false
    @Published var connectionState: ConnectionState = .disconnected
    @Published var lastError: String?
    @Published var pendingInvitation: (peerID: MCPeerID, handler: (Bool) -> Void)?
    var onRecordingStateChanged: ((Bool) -> Void)?
    
    // MARK: - Connection State
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        
        var displayName: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .connecting: return "Connecting..."
            case .connected: return "Connected"
            }
        }
    }
    
    // MARK: - Message Types
    enum MessageType: String, Codable {
        case startRecording
        case stopRecording
        case gameStateUpdate
        case deviceRole
        case ping
        case pong
        case controllerReady
        case recorderReady
        case gameStarting
        case approvalRequest
        case approvalResponse
        case recordingStateUpdate
    }
    
    struct Message: Codable {
        let type: MessageType
        let payload: [String: String]?
        let timestamp: Date
        
        init(type: MessageType, payload: [String: String]? = nil) {
            self.type = type
            self.payload = payload
            self.timestamp = Date()
        }
    }
    
    // MARK: - Multipeer Components
    private var peerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    private let trustedDevices = TrustedDevicesManager.shared
    private var isProcessingInvitation = false
    
    // Service type must be 15 characters or less, no uppercase
    private let serviceType = "sahilstats"
    
    // MARK: - Callbacks
    var onRecordingStartRequested: (() -> Void)?
    var onRecordingStopRequested: (() -> Void)?
    var onGameStateReceived: (([String: String]) -> Void)?
    var onPeerDiscovered: ((MCPeerID) -> Void)?
    var onGameStarting: ((String) -> Void)? // Receives gameId when game starts
    var onConnectionEstablished: (() -> Void)?
    var onPendingInvitation: ((MCPeerID) -> Void)? // Triggers approval dialog
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupMultipeer()
    }
    
    func sendRecordingStateUpdate(isRecording: Bool) {
        let message = Message(
            type: .recordingStateUpdate,
            payload: ["isRecording": isRecording ? "true" : "false"]
        )
        sendMessage(message)
    }
    
    /// Automatically connect to trusted peer if found
    func autoConnectIfTrusted(_ peerID: MCPeerID) {
        if trustedDevices.isTrusted(peerID) {
            print("🔐 Auto-connecting to trusted peer: \(peerID.displayName)")
            invitePeer(peerID)
        } else {
            print("❓ New peer discovered: \(peerID.displayName) - requires approval")
            onPendingInvitation?(peerID)
        }
    }
    
    /// Connect to peer after user approval
    func connectAfterApproval(_ peerID: MCPeerID, approved: Bool, rememberDevice: Bool = false) {
        if approved {
            if rememberDevice {
                // We'll add role after connection is established
                print("✅ User approved connection - will remember device")
            }
            guard browser != nil else {
                print("❌ Cannot invite peer - browser not initialized. This device should be receiving invitations, not sending them.")
                return
            }
            invitePeer(peerID)
        } else {
            print("❌ User declined connection to: \(peerID.displayName)")
            nearbyPeers.removeAll { $0 == peerID }
        }
    }
    
    // MARK: - Game Start Signal Methods
    
    /// Send game starting signal with game ID (controller sends this)
    func sendGameStarting(gameId: String) {
        let message = Message(
            type: .gameStarting,
            payload: ["gameId": gameId]
        )
        sendMessage(message)
        print("🎮 Sent game starting signal with ID: \(gameId)")
    }
    
    /// Send controller ready signal (after controller is in waiting room)
    func sendControllerReady() {
        let message = Message(type: .controllerReady)
        sendMessage(message)
    }
    
    /// Send recorder ready signal (after recorder connects)
    func sendRecorderReady() {
        let message = Message(type: .recorderReady)
        sendMessage(message)
    }
    
    private func setupMultipeer() {
        // Create peer ID with device name
        let deviceName = UIDevice.current.name
        peerID = MCPeerID(displayName: deviceName)
        
        // Create session
        session = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        session.delegate = self
        
        print("📱 Multipeer setup complete for: \(deviceName)")
    }
    
    // MARK: - Start/Stop Services
    
    /// Start advertising as a recorder device
    func startAdvertising(as role: DeviceRoleManager.DeviceRole) {
        guard !isAdvertising else { return }
        
        let discoveryInfo = [
            "role": role.rawValue,
            "deviceType": UIDevice.current.model
        ]
        
        advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: discoveryInfo,
            serviceType: serviceType
        )
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        
        isAdvertising = true
        print("📡 Started advertising as: \(role.displayName)")
    }
    
    /// Start browsing for devices (controller looks for recorder)
    func startBrowsing() {
        guard !isBrowsing else { return }
        
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        
        isBrowsing = true
        print("🔍 Started browsing for peers")
    }
    
    func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        isAdvertising = false
        print("📡 Stopped advertising")
    }
    
    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        isBrowsing = false
        nearbyPeers.removeAll()
        print("🔍 Stopped browsing")
    }
    
    func stopAll() {
        stopAdvertising()
        stopBrowsing()
        session.disconnect()
        connectedPeers.removeAll()
        nearbyPeers.removeAll()
        isConnected = false
        connectionState = .disconnected
        print("🔌 Disconnected from all peers")
    }
    
    // MARK: - Connection Management
    
    /// Invite a peer to connect
    func invitePeer(_ peerID: MCPeerID) {
        guard connectedPeers.isEmpty else {
            print("⚠️ Already connected to a peer")
            return
        }
        
        // Prevent duplicate invitations if already connecting
        guard connectionState != .connecting else {
            print("⚠️ Already connecting to a peer")
            return
        }
        
        connectionState = .connecting
        browser.invitePeer(
            peerID,
            to: session,
            withContext: nil,
            timeout: 30
        )
        print("📤 Invited peer: \(peerID.displayName)")
    }
    
    /// Disconnect from current peer
    func disconnect() {
        session.disconnect()
        connectedPeers.removeAll()
        isConnected = false
        connectionState = .disconnected
        print("🔌 Disconnected")
    }
    
    // MARK: - Message Sending
    
    /// Send a message to all connected peers
    func sendMessage(_ message: Message) {
        guard !connectedPeers.isEmpty else {
            print("⚠️ No connected peers to send message to")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: connectedPeers, with: .reliable)
            print("📤 Sent message: \(message.type.rawValue)")
        } catch {
            print("❌ Failed to send message: \(error)")
            lastError = "Failed to send: \(error.localizedDescription)"
        }
    }
    
    /// Start recording on connected recorder device
    func sendStartRecording() {
        let message = Message(type: .startRecording)
        sendMessage(message)
    }
    
    /// Stop recording on connected recorder device
    func sendStopRecording() {
        let message = Message(type: .stopRecording)
        sendMessage(message)
    }
    
    /// Send game state update
    func sendGameState(_ gameState: [String: String]) {
        let message = Message(type: .gameStateUpdate, payload: gameState)
        sendMessage(message)
    }
    
    /// Send device role information
    func sendDeviceRole(_ role: DeviceRoleManager.DeviceRole) {
        let message = Message(
            type: .deviceRole,
            payload: ["role": role.rawValue]
        )
        sendMessage(message)
    }
    
    /// Send ping to check connection
    func sendPing() {
        let message = Message(type: .ping)
        sendMessage(message)
    }
    
    // MARK: - Message Receiving
    
    private func handleReceivedMessage(_ message: Message) {
        print("📥 Received message: \(message.type.rawValue)")
        
        DispatchQueue.main.async {
            switch message.type {
            case .startRecording:
                self.onRecordingStartRequested?()
                
            case .stopRecording:
                self.onRecordingStopRequested?()
                
            case .gameStateUpdate:
                if let payload = message.payload {
                    self.onGameStateReceived?(payload)
                }
                
            case .gameStarting:
                // Recorder receives this when controller starts game
                if let gameId = message.payload?["gameId"] {
                    print("🎮 Game starting with ID: \(gameId)")
                    self.onGameStarting?(gameId)
                }
                
            case .ping:
                self.sendMessage(Message(type: .pong))
                
            case .pong:
                print("🏓 Received pong")
                
            case .controllerReady:
                print("✅ Controller is ready")
                
            case .recorderReady:
                print("✅ Recorder is ready")
                
            case .deviceRole:
                if let role = message.payload?["role"] {
                    print("📱 Peer role: \(role)")
                }
            case .recordingStateUpdate:
                if let isRecordingStr = message.payload?["isRecording"] {
                    self.onRecordingStateChanged?(isRecordingStr == "true")
                }
                
            case .approvalRequest, .approvalResponse:
                // These are handled in the advertiser delegate
                break
            }
        }
    }
    
}

// MARK: - MCSessionDelegate

extension MultipeerConnectivityManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                print("✅ Connected to: \(peerID.displayName)")
                self.isProcessingInvitation = false
                self.connectedPeers.append(peerID)
                self.isConnected = true
                self.connectionState = .connected
                
                // Update last connected timestamp if trusted
                if self.trustedDevices.isTrusted(peerID) {
                    self.trustedDevices.updateLastConnected(peerID)
                }
                
                // Remove from nearby peers
                self.nearbyPeers.removeAll { $0 == peerID }
                
                // Trigger connection established callback
                self.onConnectionEstablished?()
                
            case .connecting:
                print("🔄 Connecting to: \(peerID.displayName)")
                self.connectionState = .connecting
                
            case .notConnected:
                print("❌ Disconnected from: \(peerID.displayName)")
                self.connectedPeers.removeAll { $0 == peerID }
                self.isConnected = !self.connectedPeers.isEmpty
                self.connectionState = self.isConnected ? .connected : .disconnected
                
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let message = try JSONDecoder().decode(Message.self, from: data)
            handleReceivedMessage(message)
        } catch {
            print("❌ Failed to decode message: \(error)")
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Not used for this implementation
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Not used for this implementation
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // Not used for this implementation
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultipeerConnectivityManager: MCNearbyServiceAdvertiserDelegate {
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("📨 Received invitation from: \(peerID.displayName)")
        
        DispatchQueue.main.async {
            // Already connected or processing
            guard self.connectedPeers.isEmpty && !self.isProcessingInvitation else {
                print("⚠️ Already connected or processing, rejecting invitation")
                invitationHandler(false, nil)
                return
            }
            
            self.isProcessingInvitation = true
            
            if self.trustedDevices.isTrusted(peerID) {
                print("🔐 Auto-accepting invitation from trusted peer")
                invitationHandler(true, self.session)
            } else {
                print("❓ New peer - storing invitation for user approval")
                self.pendingInvitation = (peerID, { approved in
                    invitationHandler(approved, approved ? self.session : nil)
                    self.isProcessingInvitation = false
                })
                self.onPendingInvitation?(peerID)
            }
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultipeerConnectivityManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        print("🔍 Found peer: \(peerID.displayName)")
        
        DispatchQueue.main.async {
            guard !self.connectedPeers.contains(peerID) && !self.nearbyPeers.contains(peerID) else {
                return
            }
            
            self.nearbyPeers.append(peerID)
            self.onPeerDiscovered?(peerID)
            
            // If we're browsing and found someone, we should invite them
            if self.trustedDevices.isTrusted(peerID) {
                print("🔐 Auto-connecting to trusted peer: \(peerID.displayName)")
                self.invitePeer(peerID)
            } else {
                print("❓ New peer discovered: \(peerID.displayName) - requires approval")
                self.onPendingInvitation?(peerID)
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("❌ Lost peer: \(peerID.displayName)")
        
        DispatchQueue.main.async {
            self.nearbyPeers.removeAll { $0 == peerID }
        }
    }
    func markConnectedPeerAsTrusted(role: DeviceRoleManager.DeviceRole) {
        guard let peer = connectedPeers.first else { return }
        trustedDevices.addTrustedPeer(peer, role: role)
    }
}
