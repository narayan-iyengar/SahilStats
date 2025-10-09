//
//  MultipeerConnectivityManager.swift
//  SahilStats
//
//  Refactored for clean pub/sub pattern
//

import Foundation
import MultipeerConnectivity
import Combine
import UIKit

// MARK: - Main Manager Class

class MultipeerConnectivityManager: NSObject, ObservableObject {
    static let shared = MultipeerConnectivityManager()
    
    // MARK: - Published Properties (UI State)
    
    @Published var connectionState: ConnectionState = .disconnected
    @Published var connectedPeers: [MCPeerID] = []
    @Published var discoveredPeers: [MCPeerID] = []
    @Published var pendingInvitations: [PendingInvitation] = []
    @Published var isAdvertising = false
    @Published var isBrowsing = false
    @Published var isAutoConnecting = false
    @Published var autoConnectStatus = ""
    @Published var lastError: String?
    @Published var isRemoteRecording: Bool? = nil
    
    // MARK: - Message Publisher (Primary Communication)
    
    let messagePublisher = PassthroughSubject<Message, Never>()
    
    // MARK: - Connection State Enum
    
    enum ConnectionState: Equatable {
        case disconnected
        case connecting(to: String)
        case connected
        
        var displayName: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .connecting(let peer): return "Connecting to \(peer)..."
            case .connected: return "Connected"
            }
        }
        
        var isConnected: Bool {
            if case .connected = self { return true }
            return false
        }
    }
    
    // MARK: - Message Types
    
    enum MessageType: String, Codable {
        // Recording control
        case startRecording
        case stopRecording
        case recordingStateUpdate
        case requestRecordingState
        
        // Game flow
        case gameStarting
        case gameAlreadyStarted
        case gameEnded
        case gameStateUpdate
        
        // Connection management
        case ping
        case pong
        case deviceRole
        case connectionReady
        
        // Control flow
        case controllerReady
        case recorderReady
    }
    
    struct Message: Codable {
        let id: UUID
        let type: MessageType
        let payload: [String: String]?
        let timestamp: Date
        let senderDeviceId: String
        
        init(type: MessageType, payload: [String: String]? = nil) {
            self.id = UUID()
            self.type = type
            self.payload = payload
            self.timestamp = Date()
            self.senderDeviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        }
    }
    
    struct PendingInvitation: Identifiable {
        let id = UUID()
        let peerID: MCPeerID
        let invitationHandler: ((Bool, MCSession?) -> Void)?
        let discoveryInfo: [String: String]?
        let timestamp: Date
        
        init(peerID: MCPeerID,
             invitationHandler: ((Bool, MCSession?) -> Void)? = nil,
             discoveryInfo: [String: String]? = nil) {
            self.peerID = peerID
            self.invitationHandler = invitationHandler
            self.discoveryInfo = discoveryInfo
            self.timestamp = Date()
        }
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 30 // 30 second timeout
        }
    }
    
    // MARK: - Private Properties
    
    private var peerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var keepAliveTimer: Timer?
    private var messageRetryQueue: [Message] = []
    private let serviceType = "sahilstats"
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupMultipeer()
    }
    
    private func setupMultipeer() {
        let deviceName = UIDevice.current.name
        peerID = MCPeerID(displayName: deviceName)
        
        session = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        session.delegate = self
        
        print("📱 Multipeer initialized for device: \(deviceName)")
    }
    
    // MARK: - Public Connection Methods
    
    func startAdvertising(as role: String) {
        guard advertiser == nil else {
            print("⚠️ Already advertising")
            return
        }
        
        let discoveryInfo: [String: String] = [
            "role": role,
            "deviceType": UIDevice.current.model,
            "timestamp": "\(Date().timeIntervalSince1970)"
        ]
        
        advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: discoveryInfo,
            serviceType: serviceType
        )
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        
        DispatchQueue.main.async {
            self.isAdvertising = true
        }
        
        print("📡 Started advertising as: \(role)")
    }
    
    func startBrowsing() {
        guard browser == nil else {
            print("⚠️ Already browsing")
            return
        }
        
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        
        DispatchQueue.main.async {
            self.isBrowsing = true
        }
        
        print("🔍 Started browsing for peers")
    }
    
    func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        
        DispatchQueue.main.async {
            self.isAdvertising = false
        }
        
        print("📡 Stopped advertising")
    }
    
    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
        
        DispatchQueue.main.async {
            self.isBrowsing = false
            self.discoveredPeers.removeAll()
        }
        
        print("🔍 Stopped browsing")
    }
    
    func stopAll() {
        stopAdvertising()
        stopBrowsing()
        disconnect()
        
        print("🛑 All services stopped")
    }
    
    func disconnect() {
        session.disconnect()
        stopKeepAlive()
        
        DispatchQueue.main.async {
            self.connectedPeers.removeAll()
            self.connectionState = .disconnected
            self.messageRetryQueue.removeAll()
        }
        
        print("🔌 Disconnected from all peers")
    }
    
    // MARK: - Invitation Management
    
    func invitePeer(_ peerID: MCPeerID) {
        guard connectionState != .connected else {
            print("⚠️ Already connected")
            return
        }
        
        guard let browser = browser else {
            print("❌ Cannot invite - browser not active")
            return
        }
        
        DispatchQueue.main.async {
            self.connectionState = .connecting(to: peerID.displayName)
        }
        
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
        
        print("📤 Invited peer: \(peerID.displayName)")
    }
    
    func approveConnection(for peerID: MCPeerID, remember: Bool) {
        guard let invitation = pendingInvitations.first(where: { $0.peerID == peerID }) else {
            print("❌ No pending invitation for: \(peerID.displayName)")
            return
        }
        
        // Accept the invitation
        invitation.invitationHandler?(true, session)
        
        // Remove from pending
        DispatchQueue.main.async {
            self.pendingInvitations.removeAll { $0.peerID == peerID }
        }
        
        // Remember device if requested
        if remember {
            if let roleString = invitation.discoveryInfo?["role"],
               let role = DeviceRoleManager.DeviceRole(rawValue: roleString) {
                TrustedDevicesManager.shared.addTrustedPeer(peerID, role: role)
            }
        }
        
        print("✅ Approved connection to: \(peerID.displayName)")
    }
    
    func declineConnection(for peerID: MCPeerID) {
        guard let invitation = pendingInvitations.first(where: { $0.peerID == peerID }) else {
            return
        }
        
        invitation.invitationHandler?(false, nil)
        
        DispatchQueue.main.async {
            self.pendingInvitations.removeAll { $0.peerID == peerID }
        }
        
        print("❌ Declined connection from: \(peerID.displayName)")
    }
    
    // MARK: - Message Sending
    
    func sendMessage(_ message: Message) {
        guard !connectedPeers.isEmpty else {
            print("⚠️ No peers connected - queuing message for later retry")
            messageRetryQueue.append(message)
            return
        }
        
        // IMPROVED: Filter only actually connected peers
        let actuallyConnectedPeers = connectedPeers.filter { peer in
            session.connectedPeers.contains(peer)
        }
        
        guard !actuallyConnectedPeers.isEmpty else {
            print("⚠️ No peers actually connected according to session - queuing message")
            messageRetryQueue.append(message)
            return
        }
        
        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: actuallyConnectedPeers, with: .reliable)
            
            print("📤 Sent message: \(message.type.rawValue) to \(actuallyConnectedPeers.count) peer(s)")
            
            // Log payload for debugging
            if let payload = message.payload {
                print("📤 Payload: \(payload)")
            }
            
        } catch let error as NSError {
            print("❌ Failed to send message: \(error)")
            print("   Error code: \(error.code), domain: \(error.domain)")
            print("   Connected peers: \(connectedPeers.map { $0.displayName })")
            print("   Session connected peers: \(session.connectedPeers.map { $0.displayName })")
            
            DispatchQueue.main.async {
                self.lastError = error.localizedDescription
            }
            
            // Only queue for retry if it's a temporary connection issue
            if error.code == 1 { // MCSession peer not connected error
                print("🔄 Queuing message for retry due to connection issue")
                messageRetryQueue.append(message)
            }
        }
    }
    
    // MARK: - Convenience Message Methods
    
    func sendGameStarting(gameId: String) {
        let message = Message(
            type: .gameStarting,
            payload: ["gameId": gameId]
        )
        
        print("""
        🎮 =============================
        🎮 SENDING GAME START SIGNAL
        🎮 Game ID: \(gameId)
        🎮 Connected: \(connectedPeers.count) peers
        🎮 =============================
        """)
        
        // Send multiple times for reliability
        sendMessage(message)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.sendMessage(message)
        }
    }
    
    func sendStartRecording() {
        sendMessage(Message(type: .startRecording))
    }
    
    func sendStopRecording() {
        sendMessage(Message(type: .stopRecording))
    }
    
    func sendRecordingStateUpdate(isRecording: Bool) {
        let message = Message(
            type: .recordingStateUpdate,
            payload: ["isRecording": isRecording ? "true" : "false"]
        )
        sendMessage(message)
    }
    
    func sendRequestForRecordingState() {
        sendMessage(Message(type: .requestRecordingState))
    }
    
    func sendGameEnded(gameId: String) {
        let message = Message(
            type: .gameEnded,
            payload: ["gameId": gameId]
        )
        sendMessage(message)
    }
    
    func sendGameState(_ gameState: [String: String]) {
        let message = Message(
            type: .gameStateUpdate,
            payload: gameState
        )
        sendMessage(message)
    }
    
    func sendPing() {
        sendMessage(Message(type: .ping))
    }
    
    // MARK: - Private Helper Methods
    
    private func handleReceivedMessage(_ message: Message) {
        print("📥 Received: \(message.type.rawValue)")
        
        // Special handling for certain message types
        switch message.type {
        case .ping:
            // Auto-respond to pings
            sendMessage(Message(type: .pong))
            
        case .recordingStateUpdate:
            if let isRecording = message.payload?["isRecording"] {
                DispatchQueue.main.async {
                    self.isRemoteRecording = (isRecording == "true")
                }
            }
            
        default:
            break
        }
        
        // Publish all messages for subscribers
        DispatchQueue.main.async {
            self.messagePublisher.send(message)
        }
    }
    
    private func startKeepAlive() {
        stopKeepAlive()
        
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
        
        print("💓 Keep-alive started")
    }
    
    private func stopKeepAlive() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
        
        print("💔 Keep-alive stopped")
    }
    
    private func sendQueuedMessages() {
        let queue = messageRetryQueue
        messageRetryQueue.removeAll()
        
        for message in queue {
            sendMessage(message)
        }
        
        if !queue.isEmpty {
            print("📤 Sent \(queue.count) queued messages")
        }
    }
    
    private func cleanupExpiredInvitations() {
        DispatchQueue.main.async {
            self.pendingInvitations.removeAll { $0.isExpired }
        }
    }
}

// MARK: - MCSessionDelegate

extension MultipeerConnectivityManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        print("🔄 Peer \(peerID.displayName) state: \(state.rawValue)")
        
        DispatchQueue.main.async {
            switch state {
            case .notConnected:
                self.connectedPeers.removeAll { $0 == peerID }
                
                if self.connectedPeers.isEmpty {
                    self.connectionState = .disconnected
                    self.stopKeepAlive()
                }
                
            case .connecting:
                self.connectionState = .connecting(to: peerID.displayName)
                
            case .connected:
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                }
                
                self.connectionState = .connected
                self.startKeepAlive()
                self.sendQueuedMessages()
                
                // Update trusted device last seen
                if TrustedDevicesManager.shared.isTrusted(peerID) {
                    TrustedDevicesManager.shared.updateLastConnected(peerID)
                }
                
                // Stop discovery after stable connection
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if self.connectionState.isConnected {
                        self.stopBrowsing()
                        self.stopAdvertising()
                    }
                }
                
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
        // Not used
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Not used
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // Not used
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultipeerConnectivityManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                   didReceiveInvitationFromPeer peerID: MCPeerID,
                   withContext context: Data?,
                   invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        
        print("📨 Invitation from: \(peerID.displayName)")
        
        // Check if already connected
        if connectedPeers.contains(peerID) {
            print("⚠️ Already connected to \(peerID.displayName)")
            invitationHandler(false, nil)
            return
        }
        
        // Auto-accept trusted devices
        if TrustedDevicesManager.shared.isTrusted(peerID) {
            print("✅ Auto-accepting trusted peer: \(peerID.displayName)")
            invitationHandler(true, session)
            TrustedDevicesManager.shared.updateLastConnected(peerID)
            return
        }
        
        // Store for manual approval
        let invitation = PendingInvitation(
            peerID: peerID,
            invitationHandler: invitationHandler,
            discoveryInfo: nil
        )
        
        DispatchQueue.main.async {
            self.pendingInvitations.append(invitation)
        }
    }
}


extension MultipeerConnectivityManager {
    func clearDiscoveredPeers() {
        DispatchQueue.main.async {
            self.discoveredPeers.removeAll()
            print("🧹 Cleared discovered peers")
        }
    }
}


// MARK: - MCNearbyServiceBrowserDelegate

extension MultipeerConnectivityManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser,
                 foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String: String]?) {
        
        print("🔍 Found peer: \(peerID.displayName)")
        
        DispatchQueue.main.async {
            if !self.discoveredPeers.contains(where: { $0.displayName == peerID.displayName }) {
                self.discoveredPeers.append(peerID)
            }
            
            // Auto-connect to trusted devices
            if TrustedDevicesManager.shared.isTrusted(peerID) && !self.connectionState.isConnected {
                print("🔄 Auto-connecting to trusted peer: \(peerID.displayName)")
                self.isAutoConnecting = true
                self.autoConnectStatus = "Connecting to \(peerID.displayName)..."
                
                // Delay to ensure session is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.invitePeer(peerID)
                }
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("👋 Lost peer: \(peerID.displayName)")
        
        DispatchQueue.main.async {
            self.discoveredPeers.removeAll { $0.displayName == peerID.displayName }
        }
    }
}

// MARK: - Debug Helpers

extension MultipeerConnectivityManager {
    func printDebugState() {
        print("""
        
        📱 ===== MULTIPEER STATE =====
        Connection: \(connectionState.displayName)
        Connected Peers: \(connectedPeers.map { $0.displayName })
        Discovered: \(discoveredPeers.count) peers
        Pending Invitations: \(pendingInvitations.count)
        Browsing: \(isBrowsing)
        Advertising: \(isAdvertising)
        =============================
        
        """)
    }
}
