// File: SahilStats/Views/RoleSpecificViews.swift
// Different views for Recording vs Control devices - Fixed

import SwiftUI
import AVFoundation
import Combine

// MARK: - Global Helper Functions

func formatDuration(_ duration: TimeInterval) -> String {
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    return String(format: "%02d:%02d", minutes, seconds)
}

struct LiveScoreOverlay: View {
    let game: LiveGame
    let recordingDuration: TimeInterval
    
    var body: some View {
        VStack {
            HStack {
                VStack {
                    Text(game.teamName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("\(game.homeScore)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                Text("-")
                    .font(.title)
                    .foregroundColor(.white)
                
                VStack {
                    Text(game.opponent)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("\(game.awayScore)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
            }
            
            HStack {
                Text("Quarter \(game.quarter)")
                Text("•")
                Text(game.currentClockDisplay)
                Text("•")
                Text("REC \(formatDuration(recordingDuration))")
                    .foregroundColor(.red)
            }
            .font(.subheadline)
            .foregroundColor(.white)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Updated Recording Device View

struct RecordingDeviceView: View {
    let liveGame: LiveGame
    @ObservedObject private var recordingManager = VideoRecordingManager.shared
    @ObservedObject private var roleManager = DeviceRoleManager.shared
    @ObservedObject private var firebaseService = FirebaseService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingDeviceManager = false
    @State private var totalRecordings: Int = 0
    
    // Real-time game data
    private var currentGame: LiveGame {
        firebaseService.getCurrentLiveGame() ?? liveGame
    }
    
    var body: some View {
        ZStack {
            // Use the new clean VideoRecordingView
            CleanVideoRecordingView(liveGame: currentGame)
            
            // Add recording device specific overlay
            VStack {
                // Top connection status
                HStack {
                    connectionStatusIndicator
                    
                    Spacer()
                    
                    // Device manager button
                    Button(action: {
                        showingDeviceManager = true
                    }) {
                        Image(systemName: "gear")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
            }
        }
        .onAppear {
            setupRecordingDevice()
        }
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            // Remove the problematic updateOverlayData() call
            // The CleanVideoRecordingView handles its own overlay updates
        }
        .sheet(isPresented: $showingDeviceManager) {
            DeviceManagerView(liveGame: currentGame)
        }
    }
    
    // MARK: - Connection Status Indicator
    @ViewBuilder
    private var connectionStatusIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
            
            Text("Recording Device")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
            
            if totalRecordings > 0 {
                Text("• \(totalRecordings) clips")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.7))
                .background(.ultraThinMaterial)
        )
    }
    
    // MARK: - Setup Methods
    private func setupRecordingDevice() {
        // Any specific setup for recording devices
        debugPrint("Setting up recording device for live game")
    }
}

// MARK: - Updated Control Device View (for consistency)

struct ControlDeviceView: View {
    let liveGame: LiveGame
    
    var body: some View {
        LiveGameControllerView(liveGame: liveGame)
    }
}

// MARK: - Device Manager View

struct DeviceManagerView: View {
    let liveGame: LiveGame
    @ObservedObject private var roleManager = DeviceRoleManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Current device info
                VStack(alignment: .leading, spacing: 12) {
                    Text("This Device")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Image(systemName: roleManager.deviceRole.icon)
                            .foregroundColor(roleManager.deviceRole == .controller ? .blue : .red)
                        
                        VStack(alignment: .leading) {
                            Text(roleManager.deviceRole.displayName)
                                .fontWeight(.medium)
                            Text(roleManager.deviceRole.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // Connected devices
                if !roleManager.connectedDevices.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Connected Devices")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ForEach(roleManager.connectedDevices) { device in
                            ConnectedDeviceRow(device: device, isIPad: isIPad)
                        }
                    }
                }
                
                Spacer()
                
                // Disconnect button
                Button("Disconnect from Game") {
                    Task {
                        await roleManager.disconnectFromGame()
                        dismiss()
                    }
                }
                .buttonStyle(UnifiedSecondaryButtonStyle(isIPad: isIPad))
            }
            .padding()
            .navigationTitle("Device Manager")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
