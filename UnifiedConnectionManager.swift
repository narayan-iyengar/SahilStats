//
//  UnifiedConnectionManager.swift
//  SahilStats
//
//  Consolidated connection management - combines background discovery, multipeer connectivity, and state management
//

import Foundation
import MultipeerConnectivity
import Combine
import SwiftUI

@MainActor
class UnifiedConnectionManager: NSObject, ObservableObject {
    static let shared = UnifiedConnectionManager()
    
    // MARK: - Published State (UI Bindings)
    @Published var connectionStatus: ConnectionStatus = .unavailable
    @Published var connectedDevice: ConnectedDevice?
    @Published var discoveredPeers: [MCPeerID] = []
    @Published var pendingInvitations: [PendingInvitation] = []
    @Published var isBackgroundScanningEnabled = true
    
    // MARK: - Connection Status
    enum ConnectionStatus: Equatable {
        case scanning
        case foundTrustedDevice(name: String)
        case connecting(name: String)
        case connected(name: String)
        case unavailable
        case disabled
        case error(String)
        
        var displayText: String {
            switch self {
            case .scanning: return "Scanning..."
            case .foundTrustedDevice(let name): return "Found \(name)"
            case .connecting(let name): return "Connecting to \(name)..."
            case .connected(let name): return "Connected to \(name)"
            case .unavailable: return "No devices"
            case .disabled: return ""
            case .error: return "Connection Error"
            }
        }
        
        var isConnected: Bool {
            if case .connected = self { return true }
            return false
        }
        
        var canUseMultiDevice: Bool {
            return isConnected
        }
        
        var color: Color {
            switch self {
            case .scanning, .foundTrustedDevice, .connecting: return .orange
            case .connected: return .green
            case .unavailable, .disabled: return .gray
            case .error: return .red
            }
        }
    }
    
    struct ConnectedDevice {
        let name: String
        let role: DeviceRoleManager.DeviceRole
        let peerID: MCPeerID
        let connectedAt: Date
    }
    
    struct PendingInvitation: Identifiable {
        let id = UUID()
        let peerID: MCPeerID
        let invitationHandler: ((Bool, MCSession?) -> Void)?
        let discoveryInfo: [String: String]?
        let timestamp: Date
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 30
        }
    }
    
    // MARK: - Message System
    let messagePublisher = PassthroughSubject<GameMessage, Never>()
    
    struct GameMessage: Codable {
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
    
    enum MessageType: String, Codable {
        // Recording control
        case startRecording
        case stopRecording
        case recordingStateUpdate
        
        // Game flow  
        case gameStarting
        case gameEnded
        case gameStateUpdate
        
        // Connection management
        case ping
        case pong
        case deviceRole
        case connectionReady
    }
    
    // MARK: - Private Properties
    private var peerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    
    private var scanTimer: Timer?
    private var connectionTimeout: Timer?
    private var keepAliveTimer: Timer?
    
    private let scanDuration: TimeInterval = 10.0
    private let connectionTimeoutDuration: TimeInterval = 15.0
    private let serviceType = "sahilstats"
    
    private let trustedDevices = TrustedDevicesManager.shared
    private var messageRetryQueue: [GameMessage] = []
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupMultipeer()
        print("🚀 UnifiedConnectionManager: Initialized")
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
        
        print("📱 UnifiedConnectionManager: Multipeer setup complete for device: \(deviceName)")
    }
    
    // MARK: - Public Interface
    
    func initializeOnAppLaunch() {
        print("🚀 UnifiedConnectionManager: Initializing on app launch")
        
        guard isBackgroundScanningEnabled else {
            connectionStatus = .disabled
            return
        }
        
        // Only start if we have trusted devices
        if trustedDevices.hasTrustedDevice(for: .controller) || trustedDevices.hasTrustedDevice(for: .recorder) {
            startBackgroundScanning()
        } else {
            connectionStatus = .unavailable
        }
    }
    
    func startBackgroundScanning() {
        guard isBackgroundScanningEnabled else {
            print("❌ Background scanning disabled")
            connectionStatus = .disabled
            return
        }
        
        print("🔍 UnifiedConnectionManager: Starting background scanning")
        print("🔍 Trusted devices - Controller: \(trustedDevices.hasTrustedDevice(for: .controller))")
        print("🔍 Trusted devices - Recorder: \(trustedDevices.hasTrustedDevice(for: .recorder))")
        print("🔍 All trusted device IDs: \(trustedDevices.getAllTrustedPeers())")
        
        connectionStatus = .scanning
        
        // Determine behavior based on what role this device expects to connect to
        if trustedDevices.hasTrustedDevice(for: .controller) {
            // This device expects to connect to a controller, so it should browse
            print("🔍 This device will browse for controller")
            startBrowsing()
        } else if trustedDevices.hasTrustedDevice(for: .recorder) {
            // This device expects to connect to a recorder, so it should advertise as controller
            print("📡 This device will advertise as controller")
            startAdvertising(as: "controller")
        } else {
            // No trusted devices, fall back to browsing
            print("🔍 No trusted devices found, defaulting to browse")
            startBrowsing()
        }
        
        // Set timeout for scanning
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: scanDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleScanTimeout()
            }
        }
        
        // Also log after a short delay to see if any peers are discovered
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            print("🔍 Scanning update - Discovered peers: \(self.discoveredPeers.count)")
            self.discoveredPeers.forEach { peer in
                print("🔍 Found peer: \(peer.displayName) (trusted: \(self.trustedDevices.isTrusted(peer)))")
            }
        }
    }
    
    func stopBackgroundScanning() {
        print("🛑 UnifiedConnectionManager: Stopping background scanning")
        scanTimer?.invalidate()
        connectionTimeout?.invalidate()
        stopBrowsing()
        
        if !connectionStatus.isConnected {
            connectionStatus = .unavailable
        }
    }
    
    func startBrowsing() {
        guard browser == nil else { return }
        
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        
        print("🔍 Started browsing for peers")
    }
    
    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
        discoveredPeers.removeAll()
        print("🔍 Stopped browsing")
    }
    
    func startAdvertising(as role: String) {
        guard advertiser == nil else { return }
        
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
        
        print("📡 Started advertising as: \(role)")
    }
    
    func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        print("📡 Stopped advertising")
    }
    
    func disconnect() {
        session.disconnect()
        stopKeepAlive()
        connectedDevice = nil
        connectionStatus = .unavailable
        messageRetryQueue.removeAll()
        print("🔌 Disconnected from all peers")
    }
    
    func reconnect() {
        print("🔄 UnifiedConnectionManager: Attempting to reconnect")
        disconnect()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.startBackgroundScanning()
        }
    }
    
    func enable() {
        isBackgroundScanningEnabled = true
        startBackgroundScanning()
    }
    
    func disable() {
        isBackgroundScanningEnabled = false
        stopBackgroundScanning()
        disconnect()
        connectionStatus = .disabled
    }
    
    // MARK: - Message Sending
    func sendMessage(_ message: GameMessage) {
        guard let connectedDevice = connectedDevice else {
            print("⚠️ No connected device - queuing message")
            messageRetryQueue.append(message)
            return
        }
        
        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: [connectedDevice.peerID], with: .reliable)
            print("📤 Sent message: \(message.type.rawValue)")
            
        } catch {
            print("❌ Failed to send message: \(error)")
            messageRetryQueue.append(message)
        }
    }
    
    // Convenience message methods
    func sendGameStarting(gameId: String) {
        let message = GameMessage(type: .gameStarting, payload: ["gameId": gameId])
        sendMessage(message)
        
        // Send multiple times for reliability
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.sendMessage(message)
        }
    }
    
    func sendStartRecording() {
        sendMessage(GameMessage(type: .startRecording))
    }
    
    func sendStopRecording() {
        sendMessage(GameMessage(type: .stopRecording))
    }
    
    func sendGameEnded(gameId: String) {
        let message = GameMessage(type: .gameEnded, payload: ["gameId": gameId])
        sendMessage(message)
    }
    
    // MARK: - App Lifecycle
    func handleAppWillEnterForeground() {
        if isBackgroundScanningEnabled && !connectionStatus.isConnected {
            startBackgroundScanning()
        }
    }
    
    func handleAppDidEnterBackground() {
        // Keep connections alive but stop active scanning
        scanTimer?.invalidate()
        stopBrowsing()
    }
    
    // MARK: - Private Helpers
    private func attemptConnectionTo(_ peer: MCPeerID) {
        print("🤝 UnifiedConnectionManager: Attempting connection to \(peer.displayName)")
        connectionStatus = .connecting(name: peer.displayName)
        
        // Set connection timeout
        connectionTimeout?.invalidate()
        connectionTimeout = Timer.scheduledTimer(withTimeInterval: connectionTimeoutDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleConnectionTimeout(peer)
            }
        }
        
        // Invite the peer
        guard let browser = browser else { return }
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 30)
    }
    
    private func handleScanTimeout() {
        print("⏰ UnifiedConnectionManager: Scan timeout reached")
        
        if !connectionStatus.isConnected && discoveredPeers.isEmpty {
            connectionStatus = .unavailable
            stopBrowsing()
        }
    }
    
    private func handleConnectionTimeout(_ peer: MCPeerID) {
        print("⏰ UnifiedConnectionManager: Connection timeout for \(peer.displayName)")
        
        if case .connecting(let name) = connectionStatus, name == peer.displayName {
            connectionStatus = .error("Connection timeout")
            
            // Retry scanning
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.startBackgroundScanning()
            }
        }
    }
    
    private func startKeepAlive() {
        stopKeepAlive()
        
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sendMessage(GameMessage(type: .ping))
            }
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
    
    private func getDeviceRoleForPeer(_ peer: MCPeerID) -> DeviceRoleManager.DeviceRole {
        // Get the role from trusted devices
        if let trustedPeer = trustedDevices.getTrustedPeerForAutoConnect(role: .controller),
           trustedPeer.deviceName == peer.displayName {
            return .controller
        } else if let trustedPeer = trustedDevices.getTrustedPeerForAutoConnect(role: .recorder),
                  trustedPeer.deviceName == peer.displayName {
            return .recorder
        }
        return .none
    }
    
    private func handleReceivedMessage(_ message: GameMessage) {
        print("📥 Received: \(message.type.rawValue)")
        
        // Handle ping/pong automatically
        if message.type == .ping {
            sendMessage(GameMessage(type: .pong))
        }
        
        // Publish all messages for subscribers
        messagePublisher.send(message)
    }
}

// MARK: - MCSessionDelegate
extension UnifiedConnectionManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        print("🔄 Peer \(peerID.displayName) state: \(state.rawValue)")
        
        DispatchQueue.main.async {
            switch state {
            case .notConnected:
                if self.connectedDevice?.peerID == peerID {
                    print("📱 Lost connection to \(peerID.displayName)")
                    self.connectedDevice = nil
                    self.stopKeepAlive()
                    
                    // Attempt to reconnect
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.startBackgroundScanning()
                    }
                }
                
            case .connecting:
                self.connectionStatus = .connecting(name: peerID.displayName)
                
            case .connected:
                if self.trustedDevices.isTrusted(peerID) {
                    let deviceRole = self.getDeviceRoleForPeer(peerID)
                    let device = ConnectedDevice(
                        name: peerID.displayName,
                        role: deviceRole,
                        peerID: peerID,
                        connectedAt: Date()
                    )
                    
                    self.connectedDevice = device
                    self.connectionStatus = .connected(name: peerID.displayName)
                    
                    self.stopBackgroundScanning()
                    self.startKeepAlive()
                    self.sendQueuedMessages()
                    
                    print("✅ Connected to trusted device: \(peerID.displayName)")
                    
                    // Update trusted device last seen
                    self.trustedDevices.updateLastConnected(peerID)
                }
                
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let message = try JSONDecoder().decode(GameMessage.self, from: data)
            DispatchQueue.main.async {
                self.handleReceivedMessage(message)
            }
        } catch {
            print("❌ Failed to decode message: \(error)")
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceBrowserDelegate
extension UnifiedConnectionManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        print("🔍 Found peer: \(peerID.displayName)")
        
        DispatchQueue.main.async {
            if !self.discoveredPeers.contains(where: { $0.displayName == peerID.displayName }) {
                self.discoveredPeers.append(peerID)
            }
            
            // Auto-connect to trusted devices
            if self.trustedDevices.isTrusted(peerID) && !self.connectionStatus.isConnected {
                print("🔄 Found trusted device: \(peerID.displayName) - attempting connection")
                self.connectionStatus = .foundTrustedDevice(name: peerID.displayName)
                
                // Delay to ensure session is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.attemptConnectionTo(peerID)
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

// MARK: - MCNearbyServiceAdvertiserDelegate
extension UnifiedConnectionManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        
        print("📨 Invitation from: \(peerID.displayName)")
        
        // Auto-accept trusted devices
        if trustedDevices.isTrusted(peerID) {
            print("✅ Auto-accepting trusted peer: \(peerID.displayName)")
            invitationHandler(true, session)
            trustedDevices.updateLastConnected(peerID)
            return
        }
        
        // Store for manual approval
        let invitation = PendingInvitation(
            peerID: peerID,
            invitationHandler: invitationHandler,
            discoveryInfo: nil,
            timestamp: Date()
        )
        
        DispatchQueue.main.async {
            self.pendingInvitations.append(invitation)
        }
    }
}
