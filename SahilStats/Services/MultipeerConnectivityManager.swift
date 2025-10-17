// SahilStats/Services/MultipeerConnectivityManager.swift

import Foundation
@preconcurrency import MultipeerConnectivity
import Combine
import SwiftUI

@MainActor
final class MultipeerConnectivityManager: NSObject, ObservableObject {
    static let shared = MultipeerConnectivityManager()

    // MARK: - State Machine
    enum ConnectionState: Equatable {
        case idle
        case searching
        case connecting(to: String)
        case connected(to: String)
        case disconnected(to: String)

        var isConnected: Bool {
            if case .connected = self { return true }
            return false
        }

        var displayName: String {
            switch self {
            case .idle:
                return "Idle"
            case .searching:
                return "Searching"
            case .connecting(let name):
                let friendlyName = MultipeerConnectivityManager.ConnectionState.getFriendlyName(for: name)
                return "Connecting to \(friendlyName)"
            case .connected(let name):
                let friendlyName = MultipeerConnectivityManager.ConnectionState.getFriendlyName(for: name)
                return "Connected to \(friendlyName)"
            case .disconnected(let name):
                let friendlyName = MultipeerConnectivityManager.ConnectionState.getFriendlyName(for: name)
                return "Disconnected from \(friendlyName)"
            }
        }

        static func getFriendlyName(for peerDisplayName: String) -> String {
            let peerID = MCPeerID(displayName: peerDisplayName)
            if let trustedPeer = TrustedDevicesManager.shared.allTrustedPeers.first(where: { $0.id == peerDisplayName }) {
                return trustedPeer.displayName // Uses friendlyName if set, otherwise deviceName
            }
            return peerDisplayName
        }
    }

    @Published private(set) var connectionState: ConnectionState = .idle
    @Published private(set) var connectedPeer: MCPeerID?
    @Published private(set) var discoveredPeers: [MCPeerID] = []
    @Published var isRemoteRecording: Bool? = nil

    // Pending invitations (for pairing UI)
    struct PendingInvitation: Identifiable {
        let id = UUID()
        let peerID: MCPeerID
        let discoveryInfo: [String: String]?
        let invitationHandler: (Bool, MCSession?) -> Void
    }
    @Published var pendingInvitations: [PendingInvitation] = []

    // Computed property for connected peers array
    var connectedPeers: [MCPeerID] {
        return session.connectedPeers
    }

    // MARK: - Messaging
    let messagePublisher = PassthroughSubject<Message, Never>()

    enum MessageType: String, Codable {
        case gameStarting, gameAlreadyStarted, startRecording, stopRecording
        case scoreUpdate // Immediate score updates (event-driven)
        case clockControl // Clock start/stop/pause (event-driven)
        case periodChange // Quarter/period changes (event-driven)
        case clockSync // Periodic clock drift correction (every 10-15s)
        case ping, pong // Keep-alive
        case gameEnded // Game finished
        case gameState, requestRecordingState, recordingStateResponse // Additional message types
    }
    
    struct Message: Codable {
        let id = UUID()
        let type: MessageType
        let payload: [String: String]?
    }

    // MARK: - Private Properties
    private let serviceType = "sahilstats"
    private let myPeerID: MCPeerID = {
        // Create a unique, readable device identifier
        let deviceName = UIDevice.current.name
        let deviceModel = UIDevice.current.model

        // Use a PERSISTENT UUID stored in UserDefaults (survives app reinstalls within same vendor)
        let persistentUUIDKey = "com.sahilstats.persistentDeviceUUID"
        let persistentUUID: String

        if let savedUUID = UserDefaults.standard.string(forKey: persistentUUIDKey) {
            persistentUUID = savedUUID
            print("📱 Using saved persistent UUID: \(persistentUUID)")
        } else {
            // First launch - create and save a new UUID
            persistentUUID = UUID().uuidString
            UserDefaults.standard.set(persistentUUID, forKey: persistentUUIDKey)
            print("📱 Created new persistent UUID: \(persistentUUID)")
        }

        // Get short ID from persistent UUID (last 4 chars)
        let shortID = String(persistentUUID.suffix(4))

        // Format: "Name's iPhone (A1B2)" or "Name's iPad (C3D4)"
        let displayName = "\(deviceName) (\(shortID))"

        print("📱 Device ID: \(displayName)")
        return MCPeerID(displayName: displayName)
    }()

    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var keepAliveTimer: Timer?
    private var reconnectTimer: Timer?
    private var lastUsedRole: DeviceRole?
    private var shouldAutoReconnect = false

    private override init() {
        super.init()
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
    }

    // MARK: - Auto-Connection

    /// Start automatic background scanning if user has trusted devices
    func startAutoConnectionIfNeeded() {
        let trustedDevices = TrustedDevicesManager.shared
        let roleManager = DeviceRoleManager.shared

        // Only auto-connect if we have trusted devices
        guard trustedDevices.hasTrustedDevices else {
            print("⚠️ No trusted devices, skipping auto-connection")
            return
        }

        // Don't restart if already connected
        if connectionState.isConnected {
            print("✅ Already connected, skipping auto-connection")
            shouldAutoReconnect = true // Enable reconnection if disconnect happens
            return
        }

        // Get the first trusted peer to determine what role to use
        guard let firstTrustedPeer = trustedDevices.allTrustedPeers.first else {
            print("⚠️ No trusted peers available")
            return
        }

        // Create MCPeerID from the trusted peer to look up our saved role
        let peerID = MCPeerID(displayName: firstTrustedPeer.id)

        // Use the SAVED role for this specific peer (from pairing)
        // This ensures each device uses the correct role they were assigned during pairing
        let role = trustedDevices.getMyRole(for: peerID) ?? roleManager.roleForAutoConnection
        print("🔄 Starting auto-connection as \(role.displayName) (saved role for \(firstTrustedPeer.deviceName))")

        shouldAutoReconnect = true
        startSession(role: role)
    }

    /// Enable automatic reconnection
    func enableAutoReconnect() {
        shouldAutoReconnect = true
    }

    /// Disable automatic reconnection
    func disableAutoReconnect() {
        shouldAutoReconnect = false
        stopReconnectTimer()
    }

    private func startReconnectTimer() {
        stopReconnectTimer()

        guard shouldAutoReconnect else { return }

        print("🔄 Will attempt reconnection in 5 seconds...")

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            // Get the saved role for our trusted peer (same logic as startAutoConnectionIfNeeded)
            let trustedDevices = TrustedDevicesManager.shared
            guard let firstTrustedPeer = trustedDevices.allTrustedPeers.first else {
                print("⚠️ No trusted peers available for reconnection")
                return
            }

            let peerID = MCPeerID(displayName: firstTrustedPeer.id)
            let role = trustedDevices.getMyRole(for: peerID) ?? (self.lastUsedRole ?? .controller)

            print("🔄 Attempting automatic reconnection as \(role.displayName) (saved role for \(firstTrustedPeer.deviceName))")
            self.startSession(role: role)
        }
    }

    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }

    // MARK: - Public API

    func startSession(role: DeviceRole) {
        stopSession() // Ensure a clean slate
        print("🚀 Starting Multipeer Session as \(role.displayName)")
        connectionState = .searching
        lastUsedRole = role // Remember role for reconnection

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // BOTH devices browse AND advertise for symmetric discovery
            // This ensures they can find each other regardless of who starts first
            self.browser = MCNearbyServiceBrowser(peer: self.myPeerID, serviceType: self.serviceType)
            self.browser?.delegate = self
            self.browser?.startBrowsingForPeers()

            self.advertiser = MCNearbyServiceAdvertiser(peer: self.myPeerID, discoveryInfo: ["role": role.rawValue], serviceType: self.serviceType)
            self.advertiser?.delegate = self
            self.advertiser?.startAdvertisingPeer()

            print("📡 Both browsing and advertising as \(role.displayName)")
        }
    }

    func stopSession() {
        print("🛑 Stopping Multipeer Session")
        browser?.stopBrowsingForPeers(); browser = nil
        advertiser?.stopAdvertisingPeer(); advertiser = nil
        session.disconnect()
        stopKeepAlive()
        stopReconnectTimer()
        connectionState = .idle
        connectedPeer = nil
        discoveredPeers.removeAll()
    }

    /// Start generic discovery for pairing (no role required)
    /// Both devices advertise and browse to find each other
    func startGenericDiscovery() {
        stopSession() // Ensure a clean slate
        print("🔍 Starting Generic Discovery for Pairing")
        connectionState = .searching

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Start BOTH browsing and advertising for discovery
            self.browser = MCNearbyServiceBrowser(peer: self.myPeerID, serviceType: self.serviceType)
            self.browser?.delegate = self
            self.browser?.startBrowsingForPeers()

            self.advertiser = MCNearbyServiceAdvertiser(peer: self.myPeerID, discoveryInfo: ["pairing": "true"], serviceType: self.serviceType)
            self.advertiser?.delegate = self
            self.advertiser?.startAdvertisingPeer()

            print("📡 Both browsing and advertising active for pairing")
        }
    }

    func sendMessage(_ message: Message) {
        guard let peer = connectedPeer, !session.connectedPeers.isEmpty else {
            print("⚠️ Cannot send message, no connected peer.")
            return
        }
        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: [peer], with: .reliable)
            if message.type != .ping && message.type != .pong {
                print("📤 Sent message: \(message.type)")
            }
        } catch {
            print("❌ Failed to send message: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Convenience Senders
    func sendGameStarting(gameId: String) {
        // Reset recording state when starting a new game
        isRemoteRecording = false
        sendMessage(Message(type: .gameStarting, payload: ["gameId": gameId]))
    }

    func sendRecordingStateUpdate(isRecording: Bool) {
        let payload = ["isRecording": isRecording ? "true" : "false"]
        let messageType: MessageType = isRecording ? .startRecording : .stopRecording
        sendMessage(Message(type: messageType, payload: payload))
    }

    func sendStartRecording() {
        sendMessage(Message(type: .startRecording, payload: nil))
    }

    func sendStopRecording() {
        sendMessage(Message(type: .stopRecording, payload: nil))
    }

    func sendGameEnded(gameId: String) {
        sendMessage(Message(type: .gameEnded, payload: ["gameId": gameId]))
        print("📤 Sent gameEnded message with gameId: \(gameId)")
    }

    func sendPing() {
        sendMessage(Message(type: .ping, payload: nil))
    }

    func sendGameState(_ gameState: [String: String]) {
        sendMessage(Message(type: .gameState, payload: gameState))
    }

    func sendRequestForRecordingState() {
        sendMessage(Message(type: .requestRecordingState, payload: nil))
    }

    // MARK: - Event-Driven Real-Time Updates

    /// Send immediate score update (triggered by user action)
    func sendScoreUpdate(homeScore: Int, awayScore: Int) {
        let payload = [
            "homeScore": String(homeScore),
            "awayScore": String(awayScore)
        ]
        sendMessage(Message(type: .scoreUpdate, payload: payload))
        print("⚡ [Instant] Sent score update: \(homeScore)-\(awayScore)")
    }

    /// Send immediate clock control (start/stop/pause)
    func sendClockControl(isRunning: Bool, clockValue: TimeInterval, timestamp: Date) {
        let payload = [
            "isRunning": isRunning ? "true" : "false",
            "clockValue": String(format: "%.1f", clockValue),
            "timestamp": String(timestamp.timeIntervalSince1970)
        ]
        sendMessage(Message(type: .clockControl, payload: payload))
        print("⚡ [Instant] Sent clock control: \(isRunning ? "START" : "PAUSE") at \(String(format: "%.0f", clockValue))s")
    }

    /// Send immediate period/quarter change
    func sendPeriodChange(quarter: Int, clockValue: TimeInterval, gameFormat: GameFormat) {
        let payload = [
            "quarter": String(quarter),
            "clockValue": String(format: "%.1f", clockValue),
            "gameFormat": gameFormat.rawValue
        ]
        sendMessage(Message(type: .periodChange, payload: payload))
        print("⚡ [Instant] Sent period change: Q\(quarter) | Clock: \(String(format: "%.0f", clockValue))s")
    }

    /// Send periodic clock sync (for drift correction)
    func sendClockSync(clockValue: TimeInterval, isRunning: Bool) {
        let payload = [
            "clockValue": String(format: "%.1f", clockValue),
            "isRunning": isRunning ? "true" : "false",
            "timestamp": String(Date().timeIntervalSince1970)
        ]
        sendMessage(Message(type: .clockSync, payload: payload))
        // Don't log this - it's periodic and would be too verbose
    }
}

// MARK: - MCSessionDelegate
extension MultipeerConnectivityManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connecting:
                self.connectionState = .connecting(to: peerID.displayName)

                // Update Live Activity
                LiveActivityManager.shared.updateConnectionState(
                    status: self.connectionState,
                    connectedPeers: []
                )
            case .connected:
                print("✅ MPC Connected to \(peerID.displayName)")
                self.browser?.stopBrowsingForPeers() // Stop searching once connected
                self.advertiser?.stopAdvertisingPeer()
                self.connectedPeer = peerID
                self.connectionState = .connected(to: peerID.displayName)
                self.stopReconnectTimer() // Stop reconnect attempts once connected
                self.startKeepAlive()

                // Start Live Activity if not already active (for auto-connection path)
                if !LiveActivityManager.shared.isActivityActive {
                    let deviceRole = DeviceRoleManager.shared.deviceRole
                    print("🏝️ Auto-connection succeeded - starting Live Activity for \(deviceRole.displayName)")
                    LiveActivityManager.shared.startActivity(deviceRole: deviceRole)
                }

                // Update Live Activity with connection state
                LiveActivityManager.shared.updateConnectionState(
                    status: self.connectionState,
                    connectedPeers: [peerID.displayName]
                )

                // Only send notification if Live Activity is not active
                if !LiveActivityManager.shared.isActivityActive {
                    let friendlyName = ConnectionState.getFriendlyName(for: peerID.displayName)
                    NotificationManager.shared.sendConnectionNotification(
                        deviceName: friendlyName,
                        isConnected: true
                    )
                    print("📱 Sent connection notification (Live Activity not active)")
                } else {
                    print("🏝️ Skipping notification (Live Activity is active)")
                }
            case .notConnected:
                print("❌ MPC Disconnected from \(peerID.displayName)")
                if self.connectedPeer == peerID {
                    self.connectedPeer = nil
                    self.connectionState = .disconnected(to: peerID.displayName)
                    self.stopKeepAlive()

                    // Update Live Activity
                    LiveActivityManager.shared.updateConnectionState(
                        status: self.connectionState,
                        connectedPeers: []
                    )

                    // Only send notification if Live Activity is not active
                    if !LiveActivityManager.shared.isActivityActive {
                        let friendlyName = ConnectionState.getFriendlyName(for: peerID.displayName)
                        NotificationManager.shared.sendConnectionNotification(
                            deviceName: friendlyName,
                            isConnected: false
                        )
                        print("📱 Sent disconnection notification (Live Activity not active)")
                    } else {
                        print("🏝️ Skipping notification (Live Activity is active)")
                    }

                    // Attempt automatic reconnection if enabled
                    if self.shouldAutoReconnect {
                        self.startReconnectTimer()
                    }
                }
            @unknown default:
                print("❓ Unknown MPC state: \(state.rawValue)")
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let message = try? JSONDecoder().decode(Message.self, from: data) {
            DispatchQueue.main.async {
                if message.type == .ping { self.sendMessage(Message(type: .pong, payload: nil)) }

                // Update recording state based on messages from recorder
                switch message.type {
                case .startRecording:
                    print("🎬 Controller received startRecording message - updating isRemoteRecording to true")
                    self.isRemoteRecording = true
                case .stopRecording:
                    print("🎬 Controller received stopRecording message - updating isRemoteRecording to false")
                    self.isRemoteRecording = false
                default:
                    break
                }

                self.messagePublisher.send(message)
                if message.type != .ping && message.type != .pong {
                    print("📥 Received message: \(message.type)")
                }
            }
        }
    }
    
    // Unused delegate methods
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceBrowserDelegate
extension MultipeerConnectivityManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        guard peerID != self.myPeerID else { return } // Prevent self-discovery

        // Add to discovered peers list (for pairing UI)
        DispatchQueue.main.async {
            if !self.discoveredPeers.contains(where: { $0.displayName == peerID.displayName }) {
                self.discoveredPeers.append(peerID)
                print("📡 Discovered peer: \(peerID.displayName)")
            }
        }

        // Auto-invite trusted peers
        if TrustedDevicesManager.shared.isTrusted(peerID) {
            print("✅ Found trusted peer, auto-inviting: \(peerID.displayName)")
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.discoveredPeers.removeAll { $0.displayName == peerID.displayName }
            print("📡 Lost peer: \(peerID.displayName)")
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MultipeerConnectivityManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Automatically accept invitations from trusted devices
        if TrustedDevicesManager.shared.isTrusted(peerID) {
            print("✅ Auto-accepting invitation from trusted peer: \(peerID.displayName)")
            invitationHandler(true, self.session)
        } else {
            // For pairing mode: add to pending invitations for user to approve
            DispatchQueue.main.async {
                let invitation = PendingInvitation(
                    peerID: peerID,
                    discoveryInfo: nil,
                    invitationHandler: invitationHandler
                )
                self.pendingInvitations.append(invitation)
                print("📩 Received invitation from untrusted peer: \(peerID.displayName) - awaiting approval")
            }
        }
    }
}

// MARK: - Keep-Alive
private extension MultipeerConnectivityManager {
    func startKeepAlive() {
        stopKeepAlive()

        // Use RunLoop.common mode to ensure timer fires even during UI interactions and camera initialization
        keepAliveTimer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            // Send keep-alive on background queue to not block main thread during camera setup
            DispatchQueue.global(qos: .utility).async {
                self?.sendMessage(Message(type: .pong, payload: nil))
            }
        }

        // Add to common run loop modes so it continues during camera initialization
        RunLoop.main.add(keepAliveTimer!, forMode: .common)

        print("💓 Keep-alive started (2s interval, background queue)")
    }

    func stopKeepAlive() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
        print("💓 Keep-alive stopped")
    }
}

// MARK: - Compatibility Extension for UI Components
extension MultipeerConnectivityManager {
    enum UIConnectionStatus {
        case scanning
        case foundTrustedDevice(String)
        case connecting
        case connected
        case unavailable
        case disabled
        case error(String)

        var displayText: String {
            switch self {
            case .scanning: return "Scanning for devices..."
            case .foundTrustedDevice(let name): return "Found \(name)"
            case .connecting: return "Connecting..."
            case .connected: return "Connected"
            case .unavailable: return "No devices available"
            case .disabled: return "Disabled"
            case .error(let message): return message
            }
        }

        var color: Color {
            switch self {
            case .scanning, .foundTrustedDevice: return .orange
            case .connecting: return .blue
            case .connected: return .green
            case .unavailable, .disabled: return .gray
            case .error: return .red
            }
        }

        var isConnected: Bool {
            if case .connected = self { return true }
            return false
        }
    }

    struct ConnectedDeviceInfo {
        let name: String
        let role: DeviceRole
    }

    var connectionStatus: UIConnectionStatus {
        switch connectionState {
        case .idle:
            return .disabled
        case .searching:
            return .scanning
        case .connecting(let name):
            return .connecting
        case .connected(let name):
            return .connected
        case .disconnected(let name):
            return .error("Disconnected from \(name)")
        }
    }

    var connectedDevice: ConnectedDeviceInfo? {
        guard let peer = connectedPeer, case .connected = connectionState else {
            return nil
        }
        // Assume recorder role for connected peer (controller connects to recorder)
        return ConnectedDeviceInfo(name: peer.displayName, role: .recorder)
    }

    var isBackgroundScanningEnabled: Bool {
        return connectionState != .idle
    }

    func startBackgroundScanning() {
        let trustedDevices = TrustedDevicesManager.shared
        let roleManager = DeviceRoleManager.shared

        // If we have a trusted peer, use the saved role for that peer
        if let firstTrustedPeer = trustedDevices.allTrustedPeers.first {
            let peerID = MCPeerID(displayName: firstTrustedPeer.id)
            let role = trustedDevices.getMyRole(for: peerID) ?? roleManager.preferredRole
            let effectiveRole = role != .none ? role : .controller

            print("🔍 Starting background scan with saved role: \(effectiveRole.displayName) for \(firstTrustedPeer.deviceName)")
            startSession(role: effectiveRole)
        } else {
            // No trusted devices - use preferred role
            let role = roleManager.preferredRole
            let effectiveRole = role != .none ? role : .controller

            print("🔍 Starting background scan with preferred role: \(effectiveRole.displayName)")
            startSession(role: effectiveRole)
        }
    }

    func disconnect() {
        stopSession()
    }

    func startBrowsing() {
        startSession(role: .controller)
    }

    func startAdvertising(as role: String) {
        startSession(role: .recorder)
    }

    func clearDiscoveredPeers() {
        discoveredPeers.removeAll()
    }

    func stopAll() {
        stopSession()
    }

    func invitePeer(_ peer: MCPeerID) {
        browser?.invitePeer(peer, to: session, withContext: nil, timeout: 30)
    }

    func approveConnection(for peer: MCPeerID, remember: Bool) {
        // Find and accept pending invitation if exists
        // For now, we auto-accept trusted peers in the advertiser delegate
        // This method can be used for manual pairing flows
        if remember {
            // Add to trusted devices based on opposite role
            let roleManager = DeviceRoleManager.shared
            let oppositeRole: DeviceRole = roleManager.preferredRole == .controller ? .recorder : .controller
            TrustedDevicesManager.shared.addTrustedPeer(peer, role: oppositeRole)
        }
    }

    func declineConnection(for peer: MCPeerID) {
        // Remove from pending invitations
        pendingInvitations.removeAll { $0.peerID == peer }
    }

    var isBrowsing: Bool {
        return browser != nil
    }

    var isAdvertising: Bool {
        return advertiser != nil
    }

    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
    }

    func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
    }
}
