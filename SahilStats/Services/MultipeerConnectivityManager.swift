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
    
    // IMPROVED: Connection health monitoring
    private var connectionHealthTimer: Timer?
    private var lastPongReceived: Date?
    private var missedPongCount = 0
    private let maxMissedPongs = 3
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupMultipeer()
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        // Monitor for network changes that might affect connectivity
        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handlePowerStateChange()
        }
    }
    
    private func handlePowerStateChange() {
        print("🔋 Power state changed - checking connections")
        
        // Give the system a moment to settle, then check connection health
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.connectionState.isConnected && self.connectedPeers.isEmpty {
                print("⚠️ Connection state mismatch after power change - resetting")
                self.connectionState = .disconnected
            }
        }
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
            
            // IMPROVED: Use unreliable mode for ping messages to reduce network congestion
            let deliveryMode: MCSessionSendDataMode = (message.type == .ping || message.type == .pong) ? .unreliable : .reliable
            
            try session.send(data, toPeers: actuallyConnectedPeers, with: deliveryMode)
            
            // Only log non-ping messages to reduce console spam
            if message.type != .ping && message.type != .pong {
                print("📤 Sent message: \(message.type.rawValue) to \(actuallyConnectedPeers.count) peer(s)")
                
                if let payload = message.payload {
                    print("📤 Payload: \(payload)")
                }
            }
            
        } catch let error as NSError {
            // IMPROVED: More detailed error handling for different error types
            let errorDescription = handleSendError(error, messageType: message.type)
            print("❌ Failed to send message: \(errorDescription)")
            
            DispatchQueue.main.async {
                self.lastError = error.localizedDescription
            }
            
            // Only queue non-ping messages for retry to avoid ping spam
            if error.code == 1 && message.type != .ping && message.type != .pong {
                print("🔄 Queuing message for retry due to connection issue")
                messageRetryQueue.append(message)
            }
        }
    }
    
    private func handleSendError(_ error: NSError, messageType: MessageType) -> String {
        switch error.code {
        case 1:
            return "Peers not connected (network issue)"
        case 2:
            return "Data too large"
        case 3:
            return "Session not connected"
        case -1004:
            return "Could not connect to host"
        case -1009:
            return "Internet connection offline"
        default:
            return "Error \(error.code): \(error.localizedDescription)"
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
        // Only log non-ping/pong messages to reduce console spam
        if message.type != .ping && message.type != .pong {
            print("📥 Received: \(message.type.rawValue)")
        }
        
        // Special handling for certain message types
        switch message.type {
        case .ping:
            // Auto-respond to pings
            sendMessage(Message(type: .pong))
            
        case .pong:
            // Track pong responses for connection health
            lastPongReceived = Date()
            missedPongCount = 0
            
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
        
        // IMPROVED: Less aggressive keep-alive to reduce network load during camera operations
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Only send ping if we have connected peers and no recent message activity
            if !self.connectedPeers.isEmpty && self.connectionState.isConnected {
                self.sendPing()
                self.checkConnectionHealth()
            } else {
                print("⚠️ Skip ping - no connected peers or connection issue")
            }
        }
        
        lastPongReceived = Date()
        missedPongCount = 0
        print("💓 Keep-alive started (10s interval)")
    }
    
    private func checkConnectionHealth() {
        guard let lastPong = lastPongReceived else {
            missedPongCount += 1
            print("⚠️ No pong received yet, missed count: \(missedPongCount)")
            return
        }
        
        let timeSinceLastPong = Date().timeIntervalSince(lastPong)
        
        if timeSinceLastPong > 15.0 { // 15 seconds without pong
            missedPongCount += 1
            print("⚠️ Connection health check failed - missed pongs: \(missedPongCount)")
            
            if missedPongCount >= maxMissedPongs {
                print("❌ Connection appears dead - attempting reconnection")
                handleConnectionFailure()
            }
        } else {
            missedPongCount = 0
        }
    }
    
    private func handleConnectionFailure() {
        print("🔄 Handling connection failure")
        
        // Force disconnect and attempt reconnection
        let peersToReconnect = connectedPeers
        session.disconnect()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            for peer in peersToReconnect {
                if TrustedDevicesManager.shared.isTrusted(peer) {
                    self.attemptReconnection(to: peer)
                }
            }
        }
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
                self.handlePeerDisconnected(peerID)
                
            case .connecting:
                self.connectionState = .connecting(to: peerID.displayName)
                
            case .connected:
                self.handlePeerConnected(peerID)
                
            @unknown default:
                break
            }
        }
    }
    
    private func handlePeerDisconnected(_ peerID: MCPeerID) {
        connectedPeers.removeAll { $0 == peerID }
        
        if connectedPeers.isEmpty {
            connectionState = .disconnected
            stopKeepAlive()
            print("🔌 All peers disconnected")
            
            // IMPROVED: Attempt auto-reconnection for trusted devices
            if TrustedDevicesManager.shared.isTrusted(peerID) {
                print("🔄 Attempting auto-reconnect to trusted device: \(peerID.displayName)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.attemptReconnection(to: peerID)
                }
            }
        }
    }
    
    private func handlePeerConnected(_ peerID: MCPeerID) {
        if !connectedPeers.contains(peerID) {
            connectedPeers.append(peerID)
        }
        
        connectionState = .connected
        startKeepAlive()
        sendQueuedMessages()
        
        // Update trusted device last seen
        if TrustedDevicesManager.shared.isTrusted(peerID) {
            TrustedDevicesManager.shared.updateLastConnected(peerID)
        }
        
        // Stop discovery after stable connection (with delay to ensure stability)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if self.connectionState.isConnected {
                self.stopBrowsing()
                self.stopAdvertising()
                print("🛑 Stopped discovery services after stable connection")
            }
        }
    }
    
    private func attemptReconnection(to peerID: MCPeerID) {
        guard connectionState != .connected else {
            print("✅ Already connected, skipping reconnection attempt")
            return
        }
        
        print("🔄 Starting reconnection attempt to: \(peerID.displayName)")
        
        // Start both browsing and advertising for maximum discovery chances
        if !isBrowsing {
            startBrowsing()
        }
        
        if !isAdvertising {
            startAdvertising(as: DeviceRoleManager.shared.deviceRole.rawValue)
        }
        
        // Try to invite the peer if we find them
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.discoveredPeers.contains(where: { $0.displayName == peerID.displayName }) {
                self.invitePeer(peerID)
            }
        }
        
        // Stop reconnection attempt after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            if self.connectionState != .connected {
                print("⏰ Reconnection attempt timed out")
                self.stopBrowsing()
                self.stopAdvertising()
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
