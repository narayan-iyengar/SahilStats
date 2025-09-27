//
//  RoleSpecificViews.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/23/25.
//
// File: SahilStats/Views/RoleSpecificViews.swift
// Different views for Recording vs Control devices

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
                Text("Period \(game.period)")
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
    @StateObject private var recordingManager = VideoRecordingManager.shared
    @StateObject private var roleManager = DeviceRoleManager.shared
    @StateObject private var firebaseService = FirebaseService.shared
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
            LandscapeVideoRecordingView(liveGame: currentGame)
            
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
            updateOverlayData()
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
    
    // MARK: - Setup and Update Methods
    private func setupRecordingDevice() {
        // Any specific setup for recording devices
        print("Setting up recording device for live game")
    }
    
    private func updateOverlayData() {
        // Update recording manager overlay data for live games
        recordingManager.updateOverlay(
            homeScore: currentGame.homeScore,
            awayScore: currentGame.awayScore,
            period: currentGame.period,
            clock: currentGame.currentClockDisplay,
            teamName: currentGame.teamName,
            opponent: currentGame.opponent
        )
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
    @StateObject private var roleManager = DeviceRoleManager.shared
    @Environment(\.dismiss) private var dismiss
    
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
                            ConnectedDeviceRow(device: device, isIPad: true)
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
                .buttonStyle(UnifiedSecondaryButtonStyle(isIPad: true))
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
