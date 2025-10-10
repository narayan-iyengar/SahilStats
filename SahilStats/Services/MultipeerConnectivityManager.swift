// SahilStats/Services/MultipeerConnectivityManager.swift

import Foundation
@preconcurrency import MultipeerConnectivity
import Combine

@MainActor
final class MultipeerConnectivityManager: NSObject, ObservableObject {
    static let shared = MultipeerConnectivityManager()

    // MARK: - State Machine
    enum ConnectionState: Equatable {
        case idle
        case searching
        case connecting(to: String)
        case connected(to: String)
    }

    @Published private(set) var connectionState: ConnectionState = .idle
    @Published private(set) var connectedPeer: MCPeerID?
    @Published private(set) var discoveredPeers: [MCPeerID] = []

    // MARK: - Messaging
    let messagePublisher = PassthroughSubject<Message, Never>()

    enum MessageType: String, Codable {
        case gameStarting, startRecording, stopRecording
        case scoreUpdate, clockUpdate // Example for future use
        case ping, pong // Keep-alive
    }
    
    struct Message: Codable {
        let id = UUID()
        let type: MessageType
        let payload: [String: String]?
    }

    // MARK: - Private Properties
    private let serviceType = "sahilstats"
    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var keepAliveTimer: Timer?

    private override init() {
        super.init()
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
    }

    // MARK: - Public API

    func startSession(role: DeviceRoleManager.DeviceRole) {
        stopSession() // Ensure a clean slate
        print("🚀 Starting Multipeer Session as \(role)")
        connectionState = .searching

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if role == .controller {
                self.browser = MCNearbyServiceBrowser(peer: self.myPeerID, serviceType: self.serviceType)
                self.browser?.delegate = self
                self.browser?.startBrowsingForPeers()
            } else { // Recorder
                self.advertiser = MCNearbyServiceAdvertiser(peer: self.myPeerID, discoveryInfo: ["role": role.rawValue], serviceType: self.serviceType)
                self.advertiser?.delegate = self
                self.advertiser?.startAdvertisingPeer()
            }
        }
    }

    func stopSession() {
        print("🛑 Stopping Multipeer Session")
        browser?.stopBrowsingForPeers(); browser = nil
        advertiser?.stopAdvertisingPeer(); advertiser = nil
        session.disconnect()
        stopKeepAlive()
        connectionState = .idle
        connectedPeer = nil
        discoveredPeers.removeAll()
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
        sendMessage(Message(type: .gameStarting, payload: ["gameId": gameId]))
    }
}

// MARK: - MCSessionDelegate
extension MultipeerConnectivityManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connecting:
                self.connectionState = .connecting(to: peerID.displayName)
            case .connected:
                print("✅ MPC Connected to \(peerID.displayName)")
                self.browser?.stopBrowsingForPeers() // Stop searching once connected
                self.advertiser?.stopAdvertisingPeer()
                self.connectedPeer = peerID
                self.connectionState = .connected(to: peerID.displayName)
                self.startKeepAlive()
            case .notConnected:
                print("❌ MPC Disconnected from \(peerID.displayName)")
                if self.connectedPeer == peerID {
                    self.stopSession()
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
        
        // Invite the first trusted peer we find
        if TrustedDevicesManager.shared.isTrusted(peerID) {
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
        }
    }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MultipeerConnectivityManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Automatically accept invitations from trusted devices
        if TrustedDevicesManager.shared.isTrusted(peerID) {
            invitationHandler(true, self.session)
        } else {
            invitationHandler(false, nil) // Decline others
        }
    }
}

// MARK: - Keep-Alive
private extension MultipeerConnectivityManager {
    func startKeepAlive() {
        stopKeepAlive()
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.sendMessage(Message(type: .pong, payload: nil))
        }
    }

    func stopKeepAlive() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
    }
}
