//
//  MessageBusService.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 10/6/25.
//
import Foundation
import FirebaseFirestore
import Combine

class MessageBusService: ObservableObject {
    static let shared = MessageBusService()
    
    @Published var unreadMessages: [GameMessage] = []
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var processedMessageIds = Set<String>()
    
    private init() {}
    
    // MARK: - Message Model
    
    struct GameMessage: Codable, Identifiable {
        var id: String?
        let type: MessageType
        let gameId: String
        let fromDevice: String
        let toDevice: String?  // nil = broadcast to all
        let payload: [String: String]?
        let timestamp: Date
        var isRead: Bool
        
        enum MessageType: String, Codable {
            case gameStarting
            case gameEnded
            case startRecording
            case stopRecording
            case recordingStateUpdate
            case gameStateUpdate
        }
    }
    
    // MARK: - Send Message
    
    func sendMessage(
        type: GameMessage.MessageType,
        gameId: String,
        toDevice: String? = nil,
        payload: [String: String]? = nil
    ) async throws {
        let message = GameMessage(
            type: type,
            gameId: gameId,
            fromDevice: UIDevice.current.name,
            toDevice: toDevice,
            payload: payload,
            timestamp: Date(),
            isRead: false
        )
        
        try await db.collection("gameMessages").addDocument(from: message)
        print("📨 Sent message: \(type.rawValue) for game: \(gameId)")
    }
    
    // MARK: - Listen for Messages
    
    func startListening(forDevice deviceName: String, gameId: String) {
        stopListening()
        
        print("👂 Starting message listener for device: \(deviceName), game: \(gameId)")
        
        listener = db.collection("gameMessages")
            .whereField("gameId", isEqualTo: gameId)
            .whereField("isRead", isEqualTo: false)
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Message listener error: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                for document in documents {
                    guard let message = try? document.data(as: GameMessage.self) else {
                        continue
                    }
                    
                    // Skip already processed messages
                    guard !self.processedMessageIds.contains(document.documentID) else {
                        continue
                    }
                    
                    // Check if message is for this device
                    let isForThisDevice = message.toDevice == nil || message.toDevice == deviceName
                    let isNotFromThisDevice = message.fromDevice != deviceName
                    
                    if isForThisDevice && isNotFromThisDevice {
                        print("📬 Received message: \(message.type.rawValue)")
                        
                        // Mark as processed
                        self.processedMessageIds.insert(document.documentID)
                        
                        // Mark as read in Firestore
                        Task {
                            try? await self.markAsRead(messageId: document.documentID)
                        }
                        
                        // Add to unread messages
                        DispatchQueue.main.async {
                            self.unreadMessages.append(message)
                        }
                    }
                }
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
        processedMessageIds.removeAll()
        print("👋 Stopped message listener")
    }
    
    private func markAsRead(messageId: String) async throws {
        try await db.collection("gameMessages").document(messageId).updateData([
            "isRead": true
        ])
    }
    
    // MARK: - Cleanup Old Messages
    
    func cleanupMessages(olderThan hours: Int = 24) async throws {
        let cutoffDate = Date().addingTimeInterval(-Double(hours) * 3600)
        
        let snapshot = try await db.collection("gameMessages")
            .whereField("timestamp", isLessThan: Timestamp(date: cutoffDate))
            .getDocuments()
        
        for document in snapshot.documents {
            try await document.reference.delete()
        }
        
        print("🧹 Cleaned up \(snapshot.documents.count) old messages")
    }
}
