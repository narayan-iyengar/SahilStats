// CleanVideoRecordingView.swift - Fixed version

import SwiftUI
import AVFoundation

struct CleanVideoRecordingView: View {
    let liveGame: LiveGame
    @StateObject private var recordingManager = VideoRecordingManager.shared
    @StateObject private var roleManager = DeviceRoleManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // Local state for overlay data
    @State private var overlayData: SimpleScoreOverlayData
    @State private var updateTimer: Timer?
    @State private var isCameraReady = false
    @State private var orientation = UIDeviceOrientation.portrait
    
    @StateObject private var multipeer = MultipeerConnectivityManager.shared
    
    init(liveGame: LiveGame) {
        self.liveGame = liveGame
        // Initialize overlayData with data from liveGame
        self._overlayData = State(initialValue: SimpleScoreOverlayData(from: liveGame))
    }
    
    var body: some View {
        let _ = print("🟠 CleanVideoRecordingView: body called, orientation = \(orientation)")
        ZStack {
            // Camera preview fills entire screen
            SimpleCameraPreviewView(isCameraReady: $isCameraReady)
                .ignoresSafeArea(.all)
            
            // Only show overlay and controls when camera is ready
            if isCameraReady {
                // Score overlay - now orientation-aware
                SimpleScoreOverlay(overlayData: overlayData, orientation: orientation, recordingDuration: recordingManager.recordingTimeString)
                
                // Recording controls - orientation aware
                if orientation == .landscapeLeft || orientation == .landscapeRight {
                    // Landscape layout - vertical controls on the left
                    HStack {
                        VStack(spacing: 20) {
                            // Close button
                            Button(action: handleDismiss) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            
                            Spacer()
                            
                            Spacer()
                            
                            Spacer()
                            
                            // Record button
                            Button(action: toggleRecording) {
                                ZStack {
                                    Circle()
                                        .stroke(.white, lineWidth: 3)
                                        .frame(width: 60, height: 60)
                                    
                                    if recordingManager.isRecording {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(.red)
                                            .frame(width: 20, height: 20)
                                    } else {
                                        Circle()
                                            .fill(.red)
                                            .frame(width: 50)
                                    }
                                }
                            }
                        }
                        .padding(.leading, 16)
                        .padding(.vertical, 50) // More space from top/bottom
                        
                        Spacer()
                    }
                } else {
                    // Portrait layout - horizontal controls at top
                    VStack {
                        HStack {
                            // Close button
                            Button(action: handleDismiss) {
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
                                    
                                    if recordingManager.isRecording {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(.red)
                                            .frame(width: 20, height: 20)
                                    } else {
                                        Circle()
                                            .fill(.red)
                                            .frame(width: 50)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        
                        Spacer()
                    }
                }
            } else {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    
                    Text("Starting Camera...")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden()
        .preferredColorScheme(.dark)
        .onAppear {
            setupOrientationNotifications()
            recordingManager.startCameraSession()
            startOverlayUpdateTimer()
            setupBluetoothCallbacks()
        }
        .onDisappear {
            removeOrientationNotifications()
            recordingManager.stopCameraSession()
            stopOverlayUpdateTimer()
        }
    }
    
    // MARK: - Private Methods
    private func setupBluetoothCallbacks() {
            multipeer.onRecordingStartRequested = {
                Task {
                    await recordingManager.startRecording()
                }
            }
            
            multipeer.onRecordingStopRequested = {
                Task {
                    await recordingManager.stopRecording()
                }
            }
        }
    
    private func toggleRecording() {
        if recordingManager.isRecording {
            Task {
                await recordingManager.stopRecording()
                multipeer.sendRecordingStateUpdate(isRecording: false)
            }
        } else {
            Task {
                await recordingManager.startRecording()
                multipeer.sendRecordingStateUpdate(isRecording: true)
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
        // Fetch current game state from Firebase
        guard let currentGame = FirebaseService.shared.getCurrentLiveGame() else {
            return
        }
        
        overlayData = SimpleScoreOverlayData(
            from: currentGame,
            isRecording: recordingManager.isRecording,
            recordingDuration: recordingManager.recordingTimeString
        )
    }
    
    private func setupOrientationNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            updateOrientation()
        }
        updateOrientation() // Set initial orientation
    }
    
    private func removeOrientationNotifications() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }
    
    private func updateOrientation() {
        orientation = UIDevice.current.orientation
    }
    
    private func handleDismiss() {
        // Clear the device role when recorder exits so they can select role again next time
        Task {
            await roleManager.clearDeviceRole()
        }
        dismiss()
    }
}

// MARK: - Preview
#Preview {
    let sampleLiveGame = LiveGame(
        teamName: "Warriors",
        opponent: "Lakers",
        gameFormat: .halves,
        quarterLength: 20,
        createdBy: "preview"
    )
    
    CleanVideoRecordingView(liveGame: sampleLiveGame)
}
