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

// MARK: - Control Device View (Main Controller)

struct ControlDeviceView: View {
    let liveGame: LiveGame
    
    var body: some View {
        LiveGameControllerView(liveGame: liveGame)
    }
}

// MARK: - Recording Stats and Components

struct RecordingStats {
    var totalRecordings: Int = 0
    var totalDuration: TimeInterval = 0
    var currentSessionDuration: TimeInterval = 0
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

// MARK: - Recording Device View

struct RecordingDeviceView: View {
    let liveGame: LiveGame
    @StateObject private var recordingManager = VideoRecordingManager.shared
    @StateObject private var roleManager = DeviceRoleManager.shared
    @StateObject private var firebaseService = FirebaseService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var previewLayer: AVCaptureVideoPreviewLayer?
    @State private var showingControls = true
    @State private var hideControlsTimer: Timer?
    @State private var recordingStats = RecordingStats()
    
    // Real-time game data
    private var currentGame: LiveGame {
        firebaseService.getCurrentLiveGame() ?? liveGame
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Camera preview
            if let previewLayer = previewLayer {
                CameraPreviewView(previewLayer: previewLayer)
                    .ignoresSafeArea()
                    .onTapGesture {
                        toggleControlsVisibility()
                    }
            } else {
                recordingSetupView
            }
            
            // Live score overlay (always visible when recording)
            if recordingManager.isRecording {
                LiveScoreOverlay(
                    game: currentGame,
                    recordingDuration: recordingManager.recordingDuration
                )
            }
            
            // Recording controls (hideable)
            if showingControls {
                recordingControlsOverlay
                    .transition(.opacity)
            }
            
            // Connection status
            connectionStatusOverlay
        }
        .navigationBarHidden(true)
        .onAppear {
            setupRecordingDevice()
        }
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            updateRecordingStats()
        }
        .alert("Recording Error", isPresented: .constant(recordingManager.error != nil)) {
            Button("OK") {
                recordingManager.error = nil
            }
        } message: {
            if let error = recordingManager.error {
                Text(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Recording Setup
    
    @ViewBuilder
    private var recordingSetupView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "video.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.7))
                
                Text("Recording Device")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Setting up camera for live game recording...")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            if recordingManager.shouldRequestAccess {
                Button("Enable Camera Access") {
                    setupRecordingDevice()
                }
                .buttonStyle(RecordingButtonStyle())
            }
        }
        .padding()
    }
    
    // MARK: - Recording Controls Overlay
    
    @ViewBuilder
    private var recordingControlsOverlay: some View {
        VStack {
            // Top controls
            HStack {
                Button(action: {
                    disconnect()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                // Recording status and stats
                if recordingManager.isRecording {
                    recordingStatusView
                }
                
                Spacer()
                
                // Settings menu
                Menu {
                    Button("Switch Camera") {
                        // Switch between front/back camera
                    }
                    Button("Recording Quality") {
                        // Quality settings
                    }
                    Button("Show Grid") {
                        // Camera grid overlay
                    }
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.7))
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 50)
            
            Spacer()
            
            // Bottom recording controls
            recordingButtonsOverlay
        }
    }
    
    @ViewBuilder
    private var recordingStatusView: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(.red)
                    .frame(width: 10, height: 10)
                    .opacity(0.8)
                    .animation(.easeInOut(duration: 1).repeatForever(), value: true)
                
                Text("REC")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            }
            
            Text(formatDuration(recordingManager.recordingDuration))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .monospacedDigit()
            
            // Recording stats
            if recordingStats.totalRecordings > 0 {
                Text("\(recordingStats.totalRecordings) clips")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.7))
                .background(.ultraThinMaterial)
        )
    }
    
    @ViewBuilder
    private var recordingButtonsOverlay: some View {
        HStack(spacing: 40) {
            // Gallery/Previous recordings
            Button(action: {
                // Show recorded clips
            }) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay {
                        if recordingStats.totalRecordings > 0 {
                            VStack(spacing: 2) {
                                Text("\(recordingStats.totalRecordings)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Image(systemName: "photo.on.rectangle")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        } else {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                    }
            }
            .disabled(recordingManager.isRecording)
            
            Spacer()
            
            // Main record button
            Button(action: toggleRecording) {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 80, height: 80)
                    
                    if recordingManager.isRecording {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.red)
                            .frame(width: 32, height: 32)
                    } else {
                        Circle()
                            .fill(.red)
                            .frame(width: 65, height: 65)
                    }
                }
            }
            .scaleEffect(recordingManager.isRecording ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: recordingManager.isRecording)
            
            Spacer()
            
            // Flip camera
            Button(action: {
                // Flip camera
            }) {
                Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .disabled(recordingManager.isRecording)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 30)
    }
    
    @ViewBuilder
    private var connectionStatusOverlay: some View {
        VStack {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    
                    Text("Connected as Recorder")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.black.opacity(0.7))
                        .background(.ultraThinMaterial)
                )
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 50)
            
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private func setupRecordingDevice() {
        Task {
            let layer = await recordingManager.setupCamera()
            await MainActor.run {
                self.previewLayer = layer
            }
        }
    }
    
    private func toggleRecording() {
        Task {
            if recordingManager.isRecording {
                await recordingManager.stopRecording()
            } else {
                await recordingManager.startRecording()
            }
        }
    }
    
    private func toggleControlsVisibility() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showingControls.toggle()
        }
        
        // Auto-hide after 3 seconds if showing
        if showingControls {
            hideControlsTimer?.invalidate()
            hideControlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingControls = false
                }
            }
        } else {
            hideControlsTimer?.invalidate()
        }
    }
    
    private func updateRecordingStats() {
        // Update recording statistics
        if recordingManager.isRecording {
            recordingStats.currentSessionDuration = recordingManager.recordingDuration
        }
    }
    
    private func disconnect() {
        Task {
            await roleManager.disconnectFromGame()
            await MainActor.run {
                dismiss()
            }
        }
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
