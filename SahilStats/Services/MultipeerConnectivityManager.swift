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
    @Published var isRemoteRecording: Bool? = nil
    
    // NEW: A single publisher for all incoming messages
    let messagePublisher = PassthroughSubject<Message, Never>()
    
    @Published var isAutoConnecting = false
    @Published var autoConnectStatus: String = "Looking for trusted devices..."
    var onAutoConnectCompleted: (() -> Void)?
    @Published var outgoingInvitations: Set<String> = []
    @Published var incomingInvitations: Set<String> = []
    
    @Published var isAttemptingAutoConnect = false
    @Published var discoveredPeers: [MCPeerID] = []
    var onPeerDiscovered: ((MCPeerID) -> Void)?
    
    @Published var pendingInvitations: [PendingInvitation] = []
    
    private var isInCriticalConnectionPhase = false
    private var lastNotifiedGameId: String?
    private var keepaliveTimer: Timer?
    
    struct PendingInvitation: Identifiable {
        let id = UUID()
        let peerID: MCPeerID
        let invitationHandler: ((Bool, MCSession?) -> Void)?
        let discoveryInfo: [String: String]?
    }
    
    // MARK: - Connection State
    enum ConnectionState {
        case disconnected, connecting, connected
        
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
        case startRecording, stopRecording, gameStateUpdate, deviceRole, ping, pong,
             controllerReady, recorderReady, gameStarting, approvalRequest, approvalResponse,
             recordingStateUpdate, requestRecordingState, gameEnded
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
    
    private let serviceType = "sahilstats"
    
    
////
    
    // MARK: - Callbacks
    var onRecordingStateRequested: (() -> Void)?
    var onGameStateReceived: (([String: String]) -> Void)?


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
    
    func sendRequestForRecordingState() {
        print("➡️ [Controller] Sending request for recording state...")
        let message = Message(type: .requestRecordingState)
        sendMessage(message)
    }
    
    
    private func shouldInvitePeer(_ peerID: MCPeerID) -> Bool {
        // Use alphabetical comparison of display names to determine priority
        // The "lower" name always invites the "higher" name
        let myDisplayName = session.myPeerID.displayName
        let peerDisplayName = peerID.displayName
        
        return myDisplayName < peerDisplayName
    }
    
    /// Automatically connect to trusted peer if found
    func autoConnectIfTrusted(_ peerID: MCPeerID) {
        print("🔍 Checking if peer is trusted: \(peerID.displayName)")
        print("🔍 Trusted devices count: \(trustedDevices.getAllTrustedPeers().count)")
        
        if trustedDevices.isTrusted(peerID) {
            print("🔐 Auto-connecting to trusted peer: \(peerID.displayName)")
            isAutoConnecting = true
            autoConnectStatus = "Connecting to \(peerID.displayName)..."
            invitePeer(peerID)
        } else {
            print("❓ New peer discovered: \(peerID.displayName) - requires approval")
            print("❓ Calling onPendingInvitation callback...")
            onPendingInvitation?(peerID)
            print("❓ onPendingInvitation callback was \(onPendingInvitation == nil ? "nil" : "set")")
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
        print("🎮 Preparing to send game starting signal with ID: \(gameId)")
        print("🎮 Connected peers: \(connectedPeers.count)")
        print("🎮 Connection state: \(connectionState)")
        
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
    
    /*
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
     */
    private func setupMultipeer() {
        let deviceName = UIDevice.current.name
        peerID = MCPeerID(displayName: deviceName)
        
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        
        print("📱 Multipeer setup complete for: \(deviceName)")
    }
    
    
    // MARK: - Start/Stop Services
    
    /// Start advertising as a recorder device
    func startAdvertising(as roleString: String = "recorder") {
        guard !isAdvertising else { return }
        
        let discoveryInfo = [
            "role": roleString,
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
        print("📡 Started advertising as: \(roleString)")
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
    
 
 
    func approveConnection(for peerID: MCPeerID, remember: Bool) {
        guard let invitation = pendingInvitations.first(where: { $0.peerID == peerID }) else {
            print("❌ No pending invitation found for: \(peerID.displayName)")
            return
        }
        
        print("✅ Approving connection to: \(peerID.displayName)")
        
        // ✅ CRITICAL: Accept invitation and keep session alive
        invitation.invitationHandler?(true, session)
        
        // Remove from pending
        pendingInvitations.removeAll { $0.peerID == peerID }
        
        // Don't stop browsing/advertising immediately - let connection stabilize
        print("⏳ Keeping connection active for stabilization...")
    }
    
       
       /// Called when user declines a connection from the UI
       func declineConnection(for peerID: MCPeerID) {
           print("❌ Declining connection to: \(peerID.displayName)")
           
           guard let pending = pendingInvitations.first(where: { $0.peerID == peerID }) else {
               return
           }
           
           pendingInvitations.removeAll { $0.peerID == peerID }
           
           // If this was an incoming invitation, reject it
           if let handler = pending.invitationHandler {
               handler(false, nil)
           }
       }
       
       // MARK: - Helper Methods
       
       private func storePendingInvitation(peerID: MCPeerID, invitationHandler: ((Bool, MCSession?) -> Void)? = nil, discoveryInfo: [String: String]? = nil) {
           // Don't add duplicates
           guard !pendingInvitations.contains(where: { $0.peerID == peerID }) else {
               print("⚠️ Invitation already pending for \(peerID.displayName)")
               return
           }
           
           let pending = PendingInvitation(
               peerID: peerID,
               invitationHandler: invitationHandler,
               discoveryInfo: discoveryInfo
           )
           
           DispatchQueue.main.async {
               self.pendingInvitations.append(pending)
               print("📱 Stored pending invitation from: \(peerID.displayName)")
               print("📱 Total pending invitations: \(self.pendingInvitations.count)")
               
               // 🔥 CRITICAL FIX: Call the onPendingInvitation callback
               print("📱 Calling onPendingInvitation callback for: \(peerID.displayName)")
               self.onPendingInvitation?(peerID)
           }
       }
       
    private func determineRoleForPeer(_ peerID: MCPeerID, discoveryInfo: [String: String]?) -> DeviceRoleManager.DeviceRole {
        // Check discovery info for role
        if let roleString = discoveryInfo?["role"] {
            // Convert from string to DeviceRoleManager.DeviceRole
            switch roleString.lowercased() {
            case "controller":
                return .controller
            case "recorder":
                return .recorder
            case "viewer":
                return .viewer
            default:
                return .none
            }
        }
        // Default role
        return .none
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
    
    
    //MARK: AUTO CONNECT
    // Add this method to check if peer should auto-accept:
    private func shouldAutoAcceptPeer(_ peer: MCPeerID) -> Bool {
        let trustedDevices = TrustedDevicesManager.shared
        return trustedDevices.isTrusted(peer)
    }
    
    
    // MARK: - Message Receiving
    
    private func handleReceivedMessage(_ message: Message) {
        print("📥 Received message: \(message.type.rawValue)")
        // Simply publish the message. The rest of the app will listen.
        DispatchQueue.main.async {
            self.messagePublisher.send(message)
        }
    }

    
    func sendGameEnded(gameId: String) {
        let message = Message(
            type: .gameEnded,
            payload: ["gameId": gameId]
        )
        sendMessage(message)
        print("Sent game ended signal")
    }
    
    
    private func startKeepalivePings() {
        stopKeepalivePings()
        
        keepaliveTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isConnected else { return }
            print("📡 Sending keepalive ping")
            self.sendPing()
        }
    }

    private func stopKeepalivePings() {
        keepaliveTimer?.invalidate()
        keepaliveTimer = nil
    }
}



// MARK: - MCSessionDelegate


extension MultipeerConnectivityManager {
    func debugPrintState() {
        print("""
        
        ===== MULTIPEER STATE =====
        Is browsing: \(isBrowsing)
        Is advertising: \(isAdvertising)
        Connected peers: \(connectedPeers.count)
        Discovered peers: \(discoveredPeers.count)
        Pending invitations: \(pendingInvitations.count)
        
        Discovered peers list:
        \(discoveredPeers.map { "  - \($0.displayName)" }.joined(separator: "\n"))
        
        Connected peers list:
        \(connectedPeers.map { "  - \($0.displayName)" }.joined(separator: "\n"))
        ===========================
        
        """)
    }
}

extension MultipeerConnectivityManager {
    // NEW: Callback for peer discovery (used in pairing)
    
    // Enhanced auto-connect that's truly seamless
    func attemptSeamlessAutoConnect(role: DeviceRoleManager.DeviceRole) {
        let trustedDevices = TrustedDevicesManager.shared
        let targetRole: DeviceRoleManager.DeviceRole = role == .controller ? .recorder : .controller
        
        guard let trustedDevice = trustedDevices.getTrustedPeerForAutoConnect(role: targetRole) else {
            print("⚠️ No trusted device found for auto-connect")
            return
        }
        
        print("🔄 Attempting seamless auto-connect to trusted device: \(trustedDevice.deviceName)")
        
        // Start browsing/advertising in background
        if role == .controller {
            startBrowsing()
        } else {
            startAdvertising(as: "recorder")
        }
        
        // Auto-accept connections from trusted devices
        onPendingInvitation = { [weak self] peer in
            if trustedDevices.isTrusted(peer) {
                print("✅ Auto-accepting invitation from trusted device: \(peer.displayName)")
                self?.approveConnection(for: peer, remember: true)
            }
        }
    }
}


extension MultipeerConnectivityManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        print("🔄 Connection state changed: \(peerID.displayName) -> \(state.rawValue)")
        
        DispatchQueue.main.async {
            switch state {
            case .notConnected:
                print("❌ Disconnected from \(peerID.displayName)")
                self.connectedPeers.removeAll { $0.displayName == peerID.displayName }
                
                // Stop keepalive when disconnected
                self.stopKeepalivePings()
                
                if self.connectedPeers.isEmpty {
                    self.connectionState = .disconnected
                    self.isAutoConnecting = false
                    self.autoConnectStatus = ""
                    self.isConnected = false
                }
                
            case .connecting:
                print("🔄 Connecting to \(peerID.displayName)")
                self.connectionState = .connecting
                
            case .connected:
                print("✅ Connected to \(peerID.displayName)")
                
                if !self.connectedPeers.contains(where: { $0.displayName == peerID.displayName }) {
                    self.connectedPeers.append(peerID)
                }
                
                self.connectionState = .connected
                self.isConnected = true
                self.onConnectionEstablished?()
                
                // Start keepalive immediately
                self.startKeepalivePings()
                
                // Keep discovery running for 5 seconds to ensure stable connection
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    if self.isConnected {
                        print("🛑 Connection stable, stopping discovery")
                        self.stopBrowsing()
                        self.stopAdvertising()
                    }
                }
                
                if self.isAutoConnecting && TrustedDevicesManager.shared.isTrusted(peerID) {
                    self.isAutoConnecting = false
                    DispatchQueue.main.async {
                        self.onAutoConnectCompleted?()
                    }
                }
                
                if TrustedDevicesManager.shared.isTrusted(peerID) {
                    TrustedDevicesManager.shared.updateLastConnected(peerID)
                }
                
            @unknown default:
                print("⚠️ Unknown connection state")
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


extension MultipeerConnectivityManager {
    func stopBrowsingAndAdvertising(afterDelay delay: TimeInterval = 2.0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            print("🛑 Stopping browsing and advertising after delay")
            self.stopBrowsing()
            self.stopAdvertising()
        }
    }
}


// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultipeerConnectivityManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                   didReceiveInvitationFromPeer peerID: MCPeerID,
                   withContext context: Data?,
                   invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("📱 Received invitation from: \(peerID.displayName)")
        
        // Check if already connected or connecting
        if session.connectedPeers.contains(peerID) {
            print("⚠️ Already connected to \(peerID.displayName)")
            invitationHandler(false, nil)
            return
        }
        
        if outgoingInvitations.contains(peerID.displayName) ||
           incomingInvitations.contains(peerID.displayName) {
            print("⚠️ Already processing invitation with \(peerID.displayName)")
            
            // If we're the one who should be inviting, reject this invitation
            if shouldInvitePeer(peerID) {
                invitationHandler(false, nil)
                return
            }
        }
        
        incomingInvitations.insert(peerID.displayName)
        
        // 🎯 AUTO-ACCEPT: Accept trusted peers immediately
        if TrustedDevicesManager.shared.isTrusted(peerID) {
            print("✅ Auto-accepting trusted peer: \(peerID.displayName)")
            invitationHandler(true, session)
            TrustedDevicesManager.shared.updateLastConnected(peerID)
        } else {
            // 🆕 NEW DEVICE: Store for manual approval
            print("❓ Storing invitation from new peer: \(peerID.displayName)")
            storePendingInvitation(peerID: peerID, invitationHandler: invitationHandler)
        }
    }
}


extension MultipeerConnectivityManager {
    func stopAll() {
        stopBrowsing()
        stopAdvertising()
        disconnect()
        
        // Clear discovered peers when stopping
        DispatchQueue.main.async {
            self.discoveredPeers.removeAll()
        }
        
        print("🛑 Stopped all multipeer services")
    }
    
    func clearDiscoveredPeers() {
        DispatchQueue.main.async {
            self.discoveredPeers.removeAll()
            print("🧹 Cleared discovered peers list")
        }
    }
}


// MARK: - MCNearbyServiceBrowserDelegate



extension MultipeerConnectivityManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        print("📱 Found peer: \(peerID.displayName)")
        
        // Add to discovered peers list
        DispatchQueue.main.async {
            if !self.discoveredPeers.contains(where: { $0.displayName == peerID.displayName }) {
                self.discoveredPeers.append(peerID)
                print("✅ Added to discovered peers: \(peerID.displayName)")
                
                // Trigger callback for pairing UI
                self.onPeerDiscovered?(peerID)
            }
        }
        
        // Check if this is a trusted device for auto-connect
        let trustedDevices = TrustedDevicesManager.shared
        /*
        if trustedDevices.isTrusted(peerID) {
            print("🔐 Found trusted device: \(peerID.displayName) - auto-connecting")
            isAutoConnecting = true
            autoConnectStatus = "Connecting to \(peerID.displayName)..."
            
            // ✅ CRITICAL: Delay invitation to ensure session is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("📤 Inviting trusted peer after delay: \(peerID.displayName)")
                self.invitePeer(peerID)
            }
        } else {
            print("ℹ️ Non-trusted peer discovered: \(peerID.displayName)")
        }
         */
        if trustedDevices.isTrusted(peerID) {
            print("Found trusted device: \(peerID.displayName) - auto-connecting")
            isAutoConnecting = true
            autoConnectStatus = "Connecting to \(peerID.displayName)..."
            
            // Check who should initiate based on name comparison
            if shouldInvitePeer(peerID) {
                print("Inviting trusted peer after delay: \(peerID.displayName)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.invitePeer(peerID)
                }
            } else {
                print("Waiting for invitation from \(peerID.displayName) (they have priority)")
                // Don't invite - wait for them to invite us
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("📱 Lost peer: \(peerID.displayName)")
        
        DispatchQueue.main.async {
            self.discoveredPeers.removeAll { $0.displayName == peerID.displayName }
            print("🗑️ Removed from discovered peers: \(peerID.displayName)")
        }
    }
}
