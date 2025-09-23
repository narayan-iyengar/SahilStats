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
    @Published var connectionState: ConnectionState = .disconnected
    
    private let firebaseService = FirebaseService.shared
    private var deviceListener: ListenerRegistration?
    
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)

        var description: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .connecting: return "Connecting..."
            case .connected: return "Connected"
            case .error(let message): return "Error: \(message)"
            }
        }
    }
    
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
        
        await MainActor.run {
            connectionState = .connecting
        }
        
        // Save role to UserDefaults
        UserDefaults.standard.set(role.rawValue, forKey: "deviceRole")
        UserDefaults.standard.set(gameId, forKey: "connectedGameId")
        
        // Update device info in Firebase
        try await updateDeviceInFirebase(role: role, gameId: gameId)
        
        // Start listening for other connected devices
        startListeningForDevices(gameId: gameId)
        
        await MainActor.run {
            isConnectedToGame = true
            connectionState = .connected
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
            connectionState = .disconnected
        }
        
        // Clear saved state
        UserDefaults.standard.removeObject(forKey: "deviceRole")
        UserDefaults.standard.removeObject(forKey: "connectedGameId")
    }
    
    private func loadSavedRole() {
        if let savedRoleString = UserDefaults.standard.string(forKey: "deviceRole"),
           let savedRole = DeviceRole(rawValue: savedRoleString),
           let gameId = UserDefaults.standard.string(forKey: "connectedGameId") {
            
            deviceRole = savedRole
            liveGameId = gameId
            isConnectedToGame = true
            
            // Reconnect to game
            Task {
                try? await updateDeviceInFirebase(role: savedRole, gameId: gameId)
                startListeningForDevices(gameId: gameId)
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
    @StateObject private var roleManager = DeviceRoleManager.shared
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    let liveGame: LiveGame
    @State private var selectedRole: DeviceRoleManager.DeviceRole = .none
    @State private var isConnecting = false
    @State private var error: String = ""
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Game info
                        gameInfoCard
                        
                        // Role selection
                        roleSelectionSection
                        
                        // Connected devices
                        if !roleManager.connectedDevices.isEmpty {
                            connectedDevicesSection
                        }
                        
                        // Connection button
                        connectionButton
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
        }
        .alert("Connection Error", isPresented: .constant(!error.isEmpty)) {
            Button("OK") { error = "" }
        } message: {
            Text(error)
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var headerSection: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .foregroundColor(.orange)
            
            Spacer()
            
            Text("Choose Device Role")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            // Placeholder for balance
            Text("Cancel")
                .foregroundColor(.clear)
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
        )
    }
    
    @ViewBuilder
    private var gameInfoCard: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .opacity(0.8)
                    .animation(.easeInOut(duration: 1).repeatForever(), value: true)
                
                Text("LIVE GAME")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(liveGame.teamName) vs \(liveGame.opponent)")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let location = liveGame.location {
                        Text(location)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(liveGame.homeScore) - \(liveGame.awayScore)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Text("Period \(liveGame.period)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private var roleSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Your Device Role")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Choose how this device will participate in the live game recording and control.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                ForEach([DeviceRoleManager.DeviceRole.recorder, .controller, .viewer], id: \.self) { role in
                    DeviceRoleCard(
                        role: role,
                        isSelected: selectedRole == role,
                        isIPad: isIPad
                    ) {
                        selectedRole = role
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var connectedDevicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected Devices")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(roleManager.connectedDevices) { device in
                ConnectedDeviceRow(device: device, isIPad: isIPad)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var connectionButton: some View {
        Button(action: connectToGame) {
            HStack {
                if isConnecting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: selectedRole.icon)
                        .font(.headline)
                }
                
                Text(isConnecting ? "Connecting..." : "Join as \(selectedRole.displayName)")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: isIPad ? 56 : 50)
            .background(
                selectedRole == .none ? Color.gray : Color.orange
            )
            .cornerRadius(isIPad ? 16 : 12)
        }
        .disabled(selectedRole == .none || isConnecting)
        .opacity(selectedRole == .none ? 0.6 : 1.0)
    }
    
    private func connectToGame() {
        guard let gameId = liveGame.id else { return }
        
        isConnecting = true
        
        Task {
            do {
                try await roleManager.setDeviceRole(selectedRole, for: gameId)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isConnecting = false
                }
            }
        }
    }
}

// MARK: - Device Role Card

struct DeviceRoleCard: View {
    let role: DeviceRoleManager.DeviceRole
    let isSelected: Bool
    let isIPad: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Role icon
                Image(systemName: role.icon)
                    .font(isIPad ? .title2 : .title3)
                    .foregroundColor(isSelected ? .orange : .secondary)
                    .frame(width: isIPad ? 40 : 32, height: isIPad ? 40 : 32)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.orange.opacity(0.1) : Color(.systemGray5))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(role.displayName)
                            .font(isIPad ? .headline : .body)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if !role.preferredDevice.isEmpty {
                            Text(role.preferredDevice)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray5))
                                .cornerRadius(8)
                        }
                    }
                    
                    Text(role.description)
                        .font(isIPad ? .subheadline : .caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(isIPad ? 20 : 16)
            .background(
                RoundedRectangle(cornerRadius: isIPad ? 16 : 12)
                    .fill(isSelected ? Color.orange.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: isIPad ? 16 : 12)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

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

// MARK: - Enhanced Game Setup Integration

struct MultiDeviceGameSetup: View {
    @StateObject private var roleManager = DeviceRoleManager.shared
    @EnvironmentObject var authService: AuthService
    @State private var showingRoleSelection = false
    @State private var gameConfig = GameConfig()
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
            
            // Device role recommendations
            VStack(spacing: 12) {
                RecommendationCard(
                    icon: "iphone",
                    title: "iPhone as Recorder",
                    description: "Better camera quality for video recording",
                    color: .red
                )
                
                RecommendationCard(
                    icon: "ipad",
                    title: "iPad as Controller",
                    description: "Larger screen for easier scoring and stats",
                    color: .blue
                )
            }
            
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
