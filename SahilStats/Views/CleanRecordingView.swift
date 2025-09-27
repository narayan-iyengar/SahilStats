//
//  CleanRecordingView.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/27/25.
//
// CleanVideoRecordingView.swift - Create this as a new file

import SwiftUI
import AVFoundation

struct CleanVideoRecordingView: View {
    let liveGame: LiveGame
    @StateObject private var recordingManager = VideoRecordingManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // Local state for overlay data
    @State private var overlayData: SimpleScoreOverlayData
    @State private var updateTimer: Timer?
    
    init(liveGame: LiveGame) {
        self.liveGame = liveGame
        self._overlayData = State(initialValue: SimpleScoreOverlayData(from: liveGame))
    }
    
    var body: some View {
        ZStack {
            // Camera preview fills entire screen
            SimpleCameraPreviewView()
                .ignoresSafeArea(.all)
            
            // Score overlay
            SimpleScoreOverlay(overlayData: overlayData)
            
            // Recording controls
            VStack {
                // Top controls
                HStack {
                    // Close button
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    
                    Spacer()
                    
                    // Recording status
                    if recordingManager.isRecording {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .opacity(0.8)
                                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: recordingManager.isRecording)
                            
                            Text("REC")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.red)
                            
                            Text(recordingManager.recordingTimeString)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    
                    Spacer()
                    
                    // Record button
                    Button(action: toggleRecording) {
                        ZStack {
                            Circle()
                                .stroke(.white, lineWidth: 3)
                                .frame(width: 60, height: 60)
                            
                            Circle()
                                .fill(recordingManager.isRecording ? .red : .white)
                                .frame(width: recordingManager.isRecording ? 25 : 50)
                                .scaleEffect(recordingManager.isRecording ? 0.8 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: recordingManager.isRecording)
                            
                            if recordingManager.isRecording {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.white)
                                    .frame(width: 16, height: 16)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden()
        .preferredColorScheme(.dark)
        .onAppear {
            recordingManager.startCameraSession()
            startOverlayUpdateTimer()
        }
        .onDisappear {
            recordingManager.stopCameraSession()
            stopOverlayUpdateTimer()
        }
    }
    
    // MARK: - Private Methods
    
    private func toggleRecording() {
        if recordingManager.isRecording {
            Task {
                await recordingManager.stopRecording()
            }
        } else {
            Task {
                await recordingManager.startRecording()
            }
        }
    }
    
    private func startOverlayUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateOverlayData()
        }
    }
    
    private func stopOverlayUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func updateOverlayData() {
        // Get the latest live game data from Firebase
        if let currentGame = FirebaseService.shared.getCurrentLiveGame() {
            overlayData = SimpleScoreOverlayData(
                from: currentGame,
                isRecording: recordingManager.isRecording,
                recordingDuration: recordingManager.recordingTimeString
            )
        }
    }
}

// MARK: - Preview
#Preview {
    CleanVideoRecordingView(liveGame: LiveGame(
        teamName: "Warriors",
        opponent: "Lakers",
        gameFormat: .halves,
        periodLength: 20
    ))
}
