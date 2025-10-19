// SahilStats/Services/MultipeerConnectivityManager.swift

import Foundation
@preconcurrency import MultipeerConnectivity
import Combine
import SwiftUI

@MainActor
final class MultipeerConnectivityManager: NSObject, ObservableObject {
    static let shared = MultipeerConnectivityManager()

    // MARK: - Debug Configuration
    /// Controlled by Settings toggle - defaults to OFF for production/gym use
    private static var enableVerboseLogging = false

    /// Update verbose logging setting (called from Settings)
    func setVerboseLogging(_ enabled: Bool) {
        Self.enableVerboseLogging = enabled
        log("Verbose logging \(enabled ? "enabled" : "disabled")")
    }

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
            _ = MCPeerID(displayName: peerDisplayName)
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

        enum CodingKeys: String, CodingKey {
            case type
            case payload
        }
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
            debugPrint("📱 Using saved persistent UUID: \(persistentUUID)")
        } else {
            // First launch - create and save a new UUID
            persistentUUID = UUID().uuidString
            UserDefaults.standard.set(persistentUUID, forKey: persistentUUIDKey)
            debugPrint("📱 Created new persistent UUID: \(persistentUUID)")
        }

        // Get short ID from persistent UUID (last 4 chars)
        let shortID = String(persistentUUID.suffix(4))

        // Format: "Name's iPhone (A1B2)" or "Name's iPad (C3D4)"
        let displayName = "\(deviceName) (\(shortID))"

        debugPrint("📱 Device ID: \(displayName)")
        return MCPeerID(displayName: displayName)
    }()

    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var keepAliveTimer: Timer?
    private var reconnectTimer: Timer?
    private var lastUsedRole: DeviceRole?
    private var shouldAutoReconnect = false

    // MARK: - Adaptive Keep-Alive
    private var isRecordingActive: Bool = false {
        didSet {
            if isRecordingActive != oldValue {
                debugPrint("📹 Recording state changed: \(isRecordingActive ? "STARTED" : "STOPPED")")
                // Restart keep-alive with new interval if connected
                if connectionState.isConnected {
                    debugPrint("🔄 Restarting keep-alive with adaptive interval...")
                    startKeepAlive()
                }
            }
        }
    }

    // MARK: - Diagnostic Logging
    private var connectionDiagnostics = ConnectionDiagnostics()

    struct ConnectionDiagnostics {
        var connectionAttempts: Int = 0
        var successfulConnections: Int = 0
        var disconnections: Int = 0
        var lastConnectionTime: Date?
        var lastDisconnectionTime: Date?
        var lastDisconnectionReason: String = "None"
        var keepAliveSent: Int = 0
        var keepAliveReceived: Int = 0
        var messagesReceived: Int = 0
        var messagesSent: Int = 0
        var currentSessionStartTime: Date?
        var longestSessionDuration: TimeInterval = 0
        var averageSessionDuration: TimeInterval = 0
        private var sessionDurations: [TimeInterval] = []

        mutating func recordConnection() {
            connectionAttempts += 1
            successfulConnections += 1
            lastConnectionTime = Date()
            currentSessionStartTime = Date()
        }

        mutating func recordDisconnection(reason: String = "Unknown") {
            disconnections += 1
            lastDisconnectionTime = Date()
            lastDisconnectionReason = reason

            // Calculate session duration
            if let startTime = currentSessionStartTime {
                let duration = Date().timeIntervalSince(startTime)
                sessionDurations.append(duration)
                longestSessionDuration = max(longestSessionDuration, duration)
                averageSessionDuration = sessionDurations.reduce(0, +) / Double(sessionDurations.count)
            }
            currentSessionStartTime = nil
        }

        mutating func recordKeepAliveSent() {
            keepAliveSent += 1
        }

        mutating func recordKeepAliveReceived() {
            keepAliveReceived += 1
        }

        mutating func recordMessageSent() {
            messagesSent += 1
        }

        mutating func recordMessageReceived() {
            messagesReceived += 1
        }

        func currentSessionDuration() -> TimeInterval? {
            guard let startTime = currentSessionStartTime else { return nil }
            return Date().timeIntervalSince(startTime)
        }

        func printDiagnostics() {
            debugPrint("""

            ═══════════════════════════════════════════════════════════════
            📊 MULTIPEER CONNECTION DIAGNOSTICS
            ═══════════════════════════════════════════════════════════════

            CONNECTION STATISTICS:
              • Total Connection Attempts: \(connectionAttempts)
              • Successful Connections:    \(successfulConnections)
              • Total Disconnections:      \(disconnections)
              • Connection Success Rate:   \(connectionAttempts > 0 ? String(format: "%.1f%%", Double(successfulConnections) / Double(connectionAttempts) * 100) : "N/A")

            SESSION METRICS:
              • Longest Session:           \(formatDuration(longestSessionDuration))
              • Average Session:           \(formatDuration(averageSessionDuration))
              • Current Session:           \(currentSessionDuration().map { formatDuration($0) } ?? "Not connected")

            LAST CONNECTION:
              • Connected:                 \(lastConnectionTime.map { formatDate($0) } ?? "Never")
              • Disconnected:              \(lastDisconnectionTime.map { formatDate($0) } ?? "Never")
              • Last Disconnect Reason:    \(lastDisconnectionReason)

            KEEP-ALIVE STATISTICS:
              • Keep-alive Sent:           \(keepAliveSent)
              • Keep-alive Received:       \(keepAliveReceived)
              • Keep-alive Health:         \(keepAliveReceived > 0 ? String(format: "%.1f%%", Double(keepAliveReceived) / Double(max(keepAliveSent, 1)) * 100) : "N/A")

            MESSAGE STATISTICS:
              • Messages Sent:             \(messagesSent)
              • Messages Received:         \(messagesReceived)

            ═══════════════════════════════════════════════════════════════

            """)
        }

        private func formatDuration(_ duration: TimeInterval) -> String {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return String(format: "%dm %ds", minutes, seconds)
        }

        private func formatDate(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return formatter.string(from: date)
        }
    }

    private override init() {
        super.init()
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
    }

    // MARK: - Conditional Logging Helper

    /// Only prints if verbose logging is enabled - eliminates performance overhead in production
    private func log(_ message: String) {
        guard Self.enableVerboseLogging else { return }
        debugPrint(message)
    }

    // MARK: - Auto-Connection

    /// Start automatic background scanning if user has trusted devices
    func startAutoConnectionIfNeeded() {
        let trustedDevices = TrustedDevicesManager.shared
        let roleManager = DeviceRoleManager.shared

        // Only auto-connect if we have trusted devices
        guard trustedDevices.hasTrustedDevices else {
            debugPrint("⚠️ No trusted devices, skipping auto-connection")
            return
        }

        // Don't restart if already connected
        if connectionState.isConnected {
            debugPrint("✅ Already connected, skipping auto-connection")
            shouldAutoReconnect = true // Enable reconnection if disconnect happens
            return
        }

        // Get the first trusted peer to determine what role to use
        guard let firstTrustedPeer = trustedDevices.allTrustedPeers.first else {
            debugPrint("⚠️ No trusted peers available")
            return
        }

        // Create MCPeerID from the trusted peer to look up our saved role
        let peerID = MCPeerID(displayName: firstTrustedPeer.id)

        // Use the SAVED role for this specific peer (from pairing)
        // This ensures each device uses the correct role they were assigned during pairing
        let savedRole = trustedDevices.getMyRole(for: peerID)
        let fallbackRole = roleManager.roleForAutoConnection
        let role = savedRole ?? fallbackRole

        if savedRole != nil {
            debugPrint("🔄 Starting auto-connection as \(role.displayName) (saved role for \(firstTrustedPeer.deviceName))")
        } else {
            debugPrint("⚠️ No saved role for \(firstTrustedPeer.deviceName), using fallback: \(role.displayName)")
        }
        debugPrint("   📝 Debug: savedRole=\(savedRole?.displayName ?? "nil"), fallbackRole=\(fallbackRole.displayName)")

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

        debugPrint("🔄 Will attempt reconnection in 5 seconds...")

        // Capture main-actor-isolated values before entering Sendable closure
        let fallbackRole = self.lastUsedRole ?? .controller

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor [weak self] in
                guard let self = self else { return }

                // Get the saved role for our trusted peer (same logic as startAutoConnectionIfNeeded)
                let trustedDevices = TrustedDevicesManager.shared
                guard let firstTrustedPeer = trustedDevices.allTrustedPeers.first else {
                    debugPrint("⚠️ No trusted peers available for reconnection")
                    return
                }

                let peerID = MCPeerID(displayName: firstTrustedPeer.id)
                let role = trustedDevices.getMyRole(for: peerID) ?? fallbackRole

                debugPrint("🔄 Attempting automatic reconnection as \(role.displayName) (saved role for \(firstTrustedPeer.deviceName))")
                self.startSession(role: role)
            }
        }
    }

    // HOTSPOT FIX: Immediate reconnection for transient hotspot disconnects
    private func startReconnectTimerImmediate() {
        stopReconnectTimer()

        guard shouldAutoReconnect else { return }

        debugPrint("🔄 IMMEDIATE RECONNECT: Attempting reconnection in 1 second...")

        // Capture main-actor-isolated values before entering Sendable closure
        let fallbackRole = self.lastUsedRole ?? .controller

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor [weak self] in
                guard let self = self else { return }

                // Get the saved role for our trusted peer
                let trustedDevices = TrustedDevicesManager.shared
                guard let firstTrustedPeer = trustedDevices.allTrustedPeers.first else {
                    debugPrint("⚠️ No trusted peers available for immediate reconnection")
                    return
                }

                let peerID = MCPeerID(displayName: firstTrustedPeer.id)
                let role = trustedDevices.getMyRole(for: peerID) ?? fallbackRole

                debugPrint("🔄 IMMEDIATE RECONNECT: Reconnecting as \(role.displayName)")
                self.startSession(role: role)
            }
        }
    }

    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }

    // MARK: - Public API

    func startSession(role: DeviceRole) {
        stopSession() // Ensure a clean slate
        debugPrint("🚀 Starting Multipeer Session as \(role.displayName)")
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

            debugPrint("📡 Both browsing and advertising as \(role.displayName)")
        }
    }

    func stopSession() {
        debugPrint("🛑 Stopping Multipeer Session")
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
        debugPrint("🔍 Starting Generic Discovery for Pairing")
        connectionState = .searching

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Start BOTH browsing and advertising for discovery
            self.browser = MCNearbyServiceBrowser(peer: self.myPeerID, serviceType: self.serviceType)
            self.browser?.delegate = self
            self.browser?.startBrowsingForPeers()

            self.advertiser = MCNearbyServiceAdvertiser(peer: self.myPeerID, discoveryInfo: ["pairing": "true"], serviceType: self.serviceType)
            self.advertiser?.delegate = self
            self.advertiser?.startAdvertisingPeer()

            debugPrint("📡 Both browsing and advertising active for pairing")
        }
    }

    func sendMessage(_ message: Message) {
        guard let peer = connectedPeer, !session.connectedPeers.isEmpty else {
            debugPrint("⚠️ Cannot send message, no connected peer.")
            return
        }
        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: [peer], with: .reliable)

            // DIAGNOSTICS: Track messages sent
            connectionDiagnostics.recordMessageSent()
            if message.type == .pong {
                connectionDiagnostics.recordKeepAliveSent()
            }

            if message.type != .ping && message.type != .pong {
                debugPrint("📤 Sent message: \(message.type)")
            }
        } catch {
            forcePrint("❌ Failed to send message: \(error.localizedDescription)")
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
        debugPrint("📤 Sent gameEnded message with gameId: \(gameId)")
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

    // MARK: - Recording State Management

    /// Notify connection manager that recording has started
    /// This reduces keep-alive frequency to avoid interfering with video encoding
    func notifyRecordingStarted() {
        isRecordingActive = true
    }

    /// Notify connection manager that recording has stopped
    /// This increases keep-alive frequency for better connection stability
    func notifyRecordingStopped() {
        isRecordingActive = false
    }

    // MARK: - Diagnostics

    /// Print detailed connection diagnostics (only when verbose logging enabled)
    func printDiagnostics() {
        guard Self.enableVerboseLogging else { return }
        connectionDiagnostics.printDiagnostics()
    }

    /// Get current session health as a string
    func getSessionHealth() -> String {
        guard let duration = connectionDiagnostics.currentSessionDuration() else {
            return "Not connected"
        }

        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let keepAliveHealth = connectionDiagnostics.keepAliveReceived > 0 ?
            Double(connectionDiagnostics.keepAliveReceived) / Double(max(connectionDiagnostics.keepAliveSent, 1)) * 100 : 0

        return String(format: "Connected: %dm %ds | Keep-alive: %.0f%%", minutes, seconds, keepAliveHealth)
    }

    /// Get connection statistics for displaying in UI (without Xcode)
    func getConnectionStats() -> ConnectionStats {
        return ConnectionStats(
            isConnected: connectionState.isConnected,
            sessionDuration: connectionDiagnostics.currentSessionDuration() ?? 0,
            totalConnections: connectionDiagnostics.successfulConnections,
            totalDisconnections: connectionDiagnostics.disconnections,
            keepAliveHealth: connectionDiagnostics.keepAliveReceived > 0 ?
                Double(connectionDiagnostics.keepAliveReceived) / Double(max(connectionDiagnostics.keepAliveSent, 1)) : 0,
            messagesSent: connectionDiagnostics.messagesSent,
            messagesReceived: connectionDiagnostics.messagesReceived
        )
    }

    struct ConnectionStats {
        let isConnected: Bool
        let sessionDuration: TimeInterval
        let totalConnections: Int
        let totalDisconnections: Int
        let keepAliveHealth: Double  // 0.0 to 1.0
        let messagesSent: Int
        let messagesReceived: Int

        var sessionDurationFormatted: String {
            let minutes = Int(sessionDuration) / 60
            let seconds = Int(sessionDuration) % 60
            return String(format: "%dm %ds", minutes, seconds)
        }

        var keepAliveHealthPercent: String {
            return String(format: "%.0f%%", keepAliveHealth * 100)
        }

        var healthEmoji: String {
            if !isConnected { return "❌" }
            if keepAliveHealth >= 0.95 { return "✅" }
            if keepAliveHealth >= 0.80 { return "⚠️" }
            return "🔴"
        }
    }

    // MARK: - Event-Driven Real-Time Updates

    /// Send immediate score update (triggered by user action)
    func sendScoreUpdate(homeScore: Int, awayScore: Int) {
        let payload = [
            "homeScore": String(homeScore),
            "awayScore": String(awayScore)
        ]
        sendMessage(Message(type: .scoreUpdate, payload: payload))
        debugPrint("⚡ [Instant] Sent score update: \(homeScore)-\(awayScore)")
    }

    /// Send immediate clock control (start/stop/pause)
    func sendClockControl(isRunning: Bool, clockValue: TimeInterval, timestamp: Date) {
        let payload = [
            "isRunning": isRunning ? "true" : "false",
            "clockValue": String(format: "%.1f", clockValue),
            "timestamp": String(timestamp.timeIntervalSince1970)
        ]
        sendMessage(Message(type: .clockControl, payload: payload))
        debugPrint("⚡ [Instant] Sent clock control: \(isRunning ? "START" : "PAUSE") at \(String(format: "%.0f", clockValue))s")
    }

    /// Send immediate period/quarter change
    func sendPeriodChange(quarter: Int, clockValue: TimeInterval, gameFormat: GameFormat) {
        let payload = [
            "quarter": String(quarter),
            "clockValue": String(format: "%.1f", clockValue),
            "gameFormat": gameFormat.rawValue
        ]
        sendMessage(Message(type: .periodChange, payload: payload))
        debugPrint("⚡ [Instant] Sent period change: Q\(quarter) | Clock: \(String(format: "%.0f", clockValue))s")
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
                // ALWAYS log connections (critical info)
                debugPrint("✅ MPC Connected to \(peerID.displayName)")

                // DIAGNOSTICS: Record successful connection
                self.connectionDiagnostics.recordConnection()

                self.browser?.stopBrowsingForPeers() // Stop searching once connected
                self.advertiser?.stopAdvertisingPeer()
                self.connectedPeer = peerID
                self.connectionState = .connected(to: peerID.displayName)
                self.stopReconnectTimer() // Stop reconnect attempts once connected

                // Wait for MCSession to fully establish before starting keep-alive
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.startKeepAlive()
                }

                // Verbose diagnostics only when debugging
                self.log("📊 Connection established - current stats:")
                self.log("   Connections: \(self.connectionDiagnostics.successfulConnections)")
                self.log("   Disconnections: \(self.connectionDiagnostics.disconnections)")
                if self.connectionDiagnostics.disconnections > 0 {
                    self.log("   ⚠️ Last disconnect: \(self.connectionDiagnostics.lastDisconnectionReason)")
                }

                // Start Live Activity if not already active (for auto-connection path)
                if !LiveActivityManager.shared.isActivityActive {
                    let deviceRole = DeviceRoleManager.shared.deviceRole
                    debugPrint("🏝️ Auto-connection succeeded - starting Live Activity for \(deviceRole.displayName)")
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
                    debugPrint("📱 Sent connection notification (Live Activity not active)")
                } else {
                    debugPrint("🏝️ Skipping notification (Live Activity is active)")
                }
            case .notConnected:
                // ALWAYS log disconnections (critical info)
                forcePrint("❌ MPC Disconnected from \(peerID.displayName)")
                if self.connectedPeer == peerID {
                    // DIAGNOSTICS: Record disconnection with reason
                    let duration = self.connectionDiagnostics.currentSessionDuration()
                    let reason = duration != nil ? String(format: "Session lasted %.0fs", duration!) : "Never connected"
                    self.connectionDiagnostics.recordDisconnection(reason: reason)

                    // Verbose diagnostics only when debugging
                    self.log("📊 Disconnection recorded:")
                    self.log("   Total disconnections: \(self.connectionDiagnostics.disconnections)")
                    self.log("   Session duration: \(reason)")
                    if let avgDuration = self.connectionDiagnostics.averageSessionDuration > 0 ? self.connectionDiagnostics.averageSessionDuration : nil {
                        self.log("   Average session: \(String(format: "%.0fs", avgDuration))")
                    }

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
                        debugPrint("📱 Sent disconnection notification (Live Activity not active)")
                    } else {
                        debugPrint("🏝️ Skipping notification (Live Activity is active)")
                    }

                    // HOTSPOT FIX: Attempt IMMEDIATE reconnection (don't wait 5 seconds)
                    // Hotspot disconnects are usually temporary - reconnect ASAP
                    if self.shouldAutoReconnect {
                        debugPrint("🔄 HOTSPOT RECONNECT: Attempting immediate reconnection...")
                        self.startReconnectTimerImmediate()
                    }
                }
            @unknown default:
                debugPrint("❓ Unknown MPC state: \(state.rawValue)")
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let message = try? JSONDecoder().decode(Message.self, from: data) {
            DispatchQueue.main.async {
                // DIAGNOSTICS: Track messages received
                self.connectionDiagnostics.recordMessageReceived()
                if message.type == .pong {
                    self.connectionDiagnostics.recordKeepAliveReceived()
                }

                if message.type == .ping { self.sendMessage(Message(type: .pong, payload: nil)) }

                // Update recording state based on messages from recorder
                switch message.type {
                case .startRecording:
                    debugPrint("🎬 Controller received startRecording message - updating isRemoteRecording to true")
                    self.isRemoteRecording = true
                case .stopRecording:
                    debugPrint("🎬 Controller received stopRecording message - updating isRemoteRecording to false")
                    self.isRemoteRecording = false
                default:
                    break
                }

                self.messagePublisher.send(message)
                if message.type != .ping && message.type != .pong {
                    debugPrint("📥 Received message: \(message.type)")
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
                debugPrint("📡 Discovered peer: \(peerID.displayName)")
            }
        }

        // Auto-invite trusted peers
        if TrustedDevicesManager.shared.isTrusted(peerID) {
            debugPrint("✅ Found trusted peer, auto-inviting: \(peerID.displayName)")
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.discoveredPeers.removeAll { $0.displayName == peerID.displayName }
            debugPrint("📡 Lost peer: \(peerID.displayName)")
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MultipeerConnectivityManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Automatically accept invitations from trusted devices
        if TrustedDevicesManager.shared.isTrusted(peerID) {
            debugPrint("✅ Auto-accepting invitation from trusted peer: \(peerID.displayName)")
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
                debugPrint("📩 Received invitation from untrusted peer: \(peerID.displayName) - awaiting approval")
            }
        }
    }
}

// MARK: - Keep-Alive (HOTSPOT OPTIMIZED)
private extension MultipeerConnectivityManager {
    func startKeepAlive() {
        stopKeepAlive()

        // ADAPTIVE KEEP-ALIVE FOR HOTSPOT STABILITY
        // iOS Personal Hotspot sleeps after ~30s of no data
        // We need to prevent sleep WITHOUT overwhelming the device during recording

        // When NOT recording: 10s interval (frequent enough to prevent sleep, light CPU load)
        // When recording: 20s interval (still prevents sleep, minimal interference with video encoding)
        let keepAliveInterval: TimeInterval = isRecordingActive ? 20.0 : 10.0

        log("💓 Starting keep-alive with \(keepAliveInterval)s interval (recording: \(isRecordingActive))")

        // Timer MUST be on main thread for reliability (background threads can be suspended)
        var keepAliveCount = 0
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: keepAliveInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor [weak self] in
                guard let self = self else { return }

                keepAliveCount += 1

                // CRITICAL: Send with actual payload data to prevent hotspot sleep
                // Zero-byte messages may be ignored by iOS power management
                let timestamp = String(Date().timeIntervalSince1970)
                let keepAliveMessage = Message(
                    type: .pong,
                    payload: ["timestamp": timestamp, "keepalive": "active"]
                )

                // Send on MAIN thread to prevent suspension
                self.sendMessage(keepAliveMessage)

                // DIAGNOSTICS: Only log if verbose logging enabled
                if Self.enableVerboseLogging {
                    // Print session health every 6 keep-alives (~1 minute)
                    if keepAliveCount % 6 == 0 {
                        let health = self.getSessionHealth()
                        debugPrint("📊 [~1 min] Session health: \(health)")
                    }

                    // Print detailed stats every 30 keep-alives (~5 minutes)
                    if keepAliveCount % 30 == 0 {
                        debugPrint("📊 [~5 min] Printing detailed diagnostics:")
                        self.printDiagnostics()
                    }
                }
            }
        }

        // CRITICAL: Use .common mode so timer fires during ALL run loop modes
        // This prevents suspension during camera operations, scrolling, etc.
        RunLoop.main.add(keepAliveTimer!, forMode: .common)

        log("💓 HOTSPOT-OPTIMIZED Keep-alive started (\(keepAliveInterval)s interval, main thread, with payload)")
    }

    func stopKeepAlive() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
        log("💓 Keep-alive stopped")
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
        case .connecting:
            return .connecting
        case .connected:
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

            debugPrint("🔍 Starting background scan with saved role: \(effectiveRole.displayName) for \(firstTrustedPeer.deviceName)")
            startSession(role: effectiveRole)
        } else {
            // No trusted devices - use preferred role
            let role = roleManager.preferredRole
            let effectiveRole = role != .none ? role : .controller

            debugPrint("🔍 Starting background scan with preferred role: \(effectiveRole.displayName)")
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
