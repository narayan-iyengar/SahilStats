//
//  MultiDeviceRecordingSystem.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/23/25.
//
// File: SahilStats/Services/MultiDeviceRecordingSystem.swift
// Multi-device system for separate recording and scoring devices

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore
import AVFoundation

// MARK: - Device Role Manager


class DeviceRoleManager: ObservableObject {
    static let shared = DeviceRoleManager()
    
    @Published var deviceRole: DeviceRole = .none
    @Published var connectedDevices: [ConnectedDevice] = []
    @Published var isConnectedToGame = false
    @Published var liveGameId: String?
    
    private let firebaseService = FirebaseService.shared
    private var deviceListener: ListenerRegistration?
    
    enum DeviceRole: String, CaseIterable {
        case none = "none"
        case recorder = "recorder"        // iPhone - focuses on recording
        case controller = "controller"    // iPad - focuses on scoring/control
        case viewer = "viewer"           // Any device - just watching
        
        var displayName: String {
            switch self {
            case .none: return "Select Role"
            case .recorder: return "Recording Device"
            case .controller: return "Control Device"
            case .viewer: return "Viewer"
            }
        }
        
        var description: String {
            switch self {
            case .none: return "Choose your device's role"
            case .recorder: return "Focus on video recording with live overlay"
            case .controller: return "Control scoring, stats, and game clock"
            case .viewer: return "Watch live game without controls"
            }
        }
        
        var icon: String {
            switch self {
            case .none: return "questionmark.circle"
            case .recorder: return "video.fill"
            case .controller: return "gamecontroller.fill"
            case .viewer: return "eye.fill"
            }
        }
        
        var preferredDevice: String {
            switch self {
            case .recorder: return "iPhone (better camera)"
            case .controller: return "iPad (larger screen)"
            case .viewer: return "Any device"
            case .none: return ""
            }
        }
    }
    
    private init() {
        loadSavedRole()
    }
    
    // MARK: - Role Management
    
    func setDeviceRole(_ role: DeviceRole, for gameId: String) async throws {
        deviceRole = role
        liveGameId = gameId
        
        // Save role to UserDefaults
        UserDefaults.standard.set(role.rawValue, forKey: "deviceRole")
        UserDefaults.standard.set(gameId, forKey: "connectedGameId")
        
        // Update device info in Firebase
        try await updateDeviceInFirebase(role: role, gameId: gameId)
        
        // Start listening for other connected devices
        startListeningForDevices(gameId: gameId)
        
        await MainActor.run {
            isConnectedToGame = true
        }
    }
    
    func clearDeviceRole() async {
        // Set flag to indicate this was an explicit exit
        UserDefaults.standard.set(true, forKey: "roleWasExplicitlyCleared")
        
        deviceRole = .none
        liveGameId = nil
        
        // Clear saved role from UserDefaults
        UserDefaults.standard.removeObject(forKey: "deviceRole")
        UserDefaults.standard.removeObject(forKey: "connectedGameId")
        
        // Stop listening for devices
        stopListeningForDevices()
        
        await MainActor.run {
            isConnectedToGame = false
            connectedDevices.removeAll()
        }
    }
    
    func disconnectFromGame() async {
        if let gameId = liveGameId {
            try? await removeDeviceFromFirebase(gameId: gameId)
        }
        
        stopListeningForDevices()
        
        await MainActor.run {
            deviceRole = .none
            liveGameId = nil
            isConnectedToGame = false
            connectedDevices.removeAll()
        }
        
        // Clear saved state
        UserDefaults.standard.removeObject(forKey: "deviceRole")
        UserDefaults.standard.removeObject(forKey: "connectedGameId")
    }
    
    private func loadSavedRole() {
        if let savedRoleString = UserDefaults.standard.string(forKey: "deviceRole"),
           let savedRole = DeviceRole(rawValue: savedRoleString),
           let gameId = UserDefaults.standard.string(forKey: "connectedGameId") {
            
            // Check if there's a flag indicating explicit exit (role was cleared intentionally)
            let wasExplicitlyCleared = UserDefaults.standard.bool(forKey: "roleWasExplicitlyCleared")
            
            if !wasExplicitlyCleared {
                // Only auto-reconnect if the role wasn't explicitly cleared
                deviceRole = savedRole
                liveGameId = gameId
                isConnectedToGame = true
                
                // Reconnect to game
                Task {
                    try? await updateDeviceInFirebase(role: savedRole, gameId: gameId)
                    startListeningForDevices(gameId: gameId)
                }
            } else {
                // Role was explicitly cleared, clean up and start fresh
                UserDefaults.standard.removeObject(forKey: "roleWasExplicitlyCleared")
                UserDefaults.standard.removeObject(forKey: "deviceRole")
                UserDefaults.standard.removeObject(forKey: "connectedGameId")
                deviceRole = .none
                liveGameId = nil
                isConnectedToGame = false
            }
        }
    }
    
    // MARK: - Firebase Integration
    
    private func updateDeviceInFirebase(role: DeviceRole, gameId: String) async throws {
        let deviceInfo = ConnectedDevice(
            id: DeviceControlManager.shared.deviceId,
            role: role,
            name: await getDeviceName(),
            lastSeen: Date(),
            isActive: true
        )
        
        let db = Firestore.firestore()
        try await db.collection("liveGames").document(gameId)
            .collection("connectedDevices").document(deviceInfo.id)
            .setData(from: deviceInfo)
    }
    
    private func removeDeviceFromFirebase(gameId: String) async throws {
        let db = Firestore.firestore()
        try await db.collection("liveGames").document(gameId)
            .collection("connectedDevices").document(DeviceControlManager.shared.deviceId)
            .delete()
    }
    
    private func startListeningForDevices(gameId: String) {
        let db = Firestore.firestore()
        deviceListener = db.collection("liveGames").document(gameId)
            .collection("connectedDevices")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                let devices = documents.compactMap { document in
                    try? document.data(as: ConnectedDevice.self)
                }.filter { $0.id != DeviceControlManager.shared.deviceId } // Exclude current device
                
                DispatchQueue.main.async {
                    self?.connectedDevices = devices
                }
            }
    }
    
    private func stopListeningForDevices() {
        deviceListener?.remove()
        deviceListener = nil
    }
    
    private func getDeviceName() async -> String {
        let deviceName = await UIDevice.current.name
        let modelName = await UIDevice.current.model
        return "\(deviceName) (\(modelName))"
    }
}


extension DeviceRoleManager.DeviceRole {
    var color: Color {
        switch self {
        case .controller: return .blue
        case .recorder: return .red
        case .viewer: return .green
        case .none: return .gray
        }
    }
    
    
    var joinDescription: String {
        switch self {
        case .controller: return "Control scoring and game clock"
        case .recorder: return "Record video with live overlay"
        case .viewer: return "Watch and view stats in real-time"
        case .none: return ""
        }
    }
}

enum LiveGameError: Error {
    case gameNotFound
    case roleNotAvailable
    case connectionFailed
    
    var localizedDescription: String {
        switch self {
        case .gameNotFound: return "Live game not found"
        case .roleNotAvailable: return "This role is not available"
        case .connectionFailed: return "Failed to connect to game"
        }
    }
}



// MARK: - Connected Device Model

struct ConnectedDevice: Codable, Identifiable {
    let id: String
    let role: DeviceRoleManager.DeviceRole
    let name: String
    let lastSeen: Date
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, role, name, lastSeen, isActive
    }
    
    init(id: String, role: DeviceRoleManager.DeviceRole, name: String, lastSeen: Date, isActive: Bool) {
        self.id = id
        self.role = role
        self.name = name
        self.lastSeen = lastSeen
        self.isActive = isActive
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        role = DeviceRoleManager.DeviceRole(rawValue: try container.decode(String.self, forKey: .role)) ?? .viewer
        name = try container.decode(String.self, forKey: .name)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        
        // Handle different date formats
        if let timestamp = try? container.decode(Timestamp.self, forKey: .lastSeen) {
            lastSeen = timestamp.dateValue()
        } else if let dateString = try? container.decode(String.self, forKey: .lastSeen) {
            let formatter = ISO8601DateFormatter()
            lastSeen = formatter.date(from: dateString) ?? Date()
        } else {
            lastSeen = Date()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(role.rawValue, forKey: .role)
        try container.encode(name, forKey: .name)
        try container.encode(Timestamp(date: lastSeen), forKey: .lastSeen)
        try container.encode(isActive, forKey: .isActive)
    }
}

// MARK: - Device Role Selection View

struct DeviceRoleSelectionView: View {
    let liveGame: LiveGame
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Select Device Role")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Choose how this device will participate in the game")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 16) {
                    DeviceRoleSelectionCard(
                        title: "Controller",
                        description: "Control game scoring and timing",
                        icon: "gamecontroller.fill",
                        color: .blue,
                        action: {
                            selectRole(.controller)
                        }
                    )
                    
                    DeviceRoleSelectionCard(
                        title: "Recorder",
                        description: "Record video with score overlay",
                        icon: "video.fill",
                        color: .red,
                        action: {
                            selectRole(.recorder)
                        }
                    )
                    
                    DeviceRoleSelectionCard(
                        title: "Viewer",
                        description: "Watch game progress",
                        icon: "eye.fill",
                        color: .green,
                        action: {
                            selectRole(.viewer)
                        }
                    )
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Device Role")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func selectRole(_ role: DeviceRoleManager.DeviceRole) {
        Task {
            do {
                if let gameId = liveGame.id {
                    try await DeviceRoleManager.shared.setDeviceRole(role, for: gameId)
                }
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Failed to set device role: \(error)")
            }
        }
    }
}

// MARK: - Device Role Card





// MARK: - Connected Device Row

struct ConnectedDeviceRow: View {
    let device: ConnectedDevice
    let isIPad: Bool
    
    private var statusColor: Color {
        let timeSinceLastSeen = Date().timeIntervalSince(device.lastSeen)
        if timeSinceLastSeen < 30 { // Active within 30 seconds
            return .green
        } else if timeSinceLastSeen < 120 { // Within 2 minutes
            return .orange
        } else {
            return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: device.role.icon)
                .font(isIPad ? .body : .caption)
                .foregroundColor(device.role == .recorder ? .red : (device.role == .controller ? .blue : .gray))
                .frame(width: isIPad ? 24 : 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(isIPad ? .body : .caption)
                    .fontWeight(.medium)
                
                Text(device.role.displayName)
                    .font(isIPad ? .caption : .caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 8)
    }
}

struct DeviceRoleSelectionCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(isIPad ? .largeTitle : .title)
                    .foregroundColor(.white)
                    .frame(width: isIPad ? 60 : 50, height: isIPad ? 60 : 50)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: isIPad ? 16 : 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(isIPad ? .title2 : .headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(isIPad ? .body : .caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(isIPad ? 20 : 16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: isIPad ? 16 : 12))
        }
        .buttonStyle(.plain)
    }
}
// MARK: - Enhanced Game Setup Integration

struct MultiDeviceGameSetup: View {
    @StateObject private var roleManager = DeviceRoleManager.shared
    @EnvironmentObject var authService: AuthService
    @State private var showingRoleSelection = false
    //@State private var gameConfig = GameConfig()
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Existing game setup...
            
            // Multi-device section
            if authService.showAdminFeatures {
                multiDeviceSection
            }
        }
        .sheet(isPresented: $showingRoleSelection) {
            if let liveGame = FirebaseService.shared.getCurrentLiveGame() {
                DeviceRoleSelectionView(liveGame: liveGame)
            }
        }
    }
    
    @ViewBuilder
    private var multiDeviceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Multi-Device Setup")
                .font(.headline)
                .fontWeight(.bold)
            
            Text("Use multiple devices for optimal recording and control experience")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if FirebaseService.shared.hasLiveGame {
                Button("Join Live Game") {
                    showingRoleSelection = true
                }
                .buttonStyle(UnifiedPrimaryButtonStyle(isIPad: isIPad))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct RecommendationCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}
