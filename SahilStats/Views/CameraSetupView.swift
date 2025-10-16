//
//  CameraSetupView.swift
//  SahilStats
//
//  Smart Tripod Mode - Camera framing and setup view
//  Shows live camera preview with alignment guides before recording
//

import SwiftUI
import AVFoundation
import Combine

struct CameraSetupView: View {
    let liveGame: LiveGame?
    let onFramingLocked: () -> Void

    @ObservedObject private var recordingManager = VideoRecordingManager.shared
    @ObservedObject private var multipeer = MultipeerConnectivityManager.shared
    @StateObject private var orientationManager = OrientationManager()

    // Camera state
    @State private var isCameraReady = false
    @State private var hasCameraSetup = false
    @State private var cameraSetupAttempts = 0
    @State private var showingCameraError = false
    @State private var cameraErrorMessage = ""

    // UI state
    @State private var showGrid = true
    @State private var isFramingLocked = false
    @State private var batteryLevel: Float = UIDevice.current.batteryLevel
    @State private var availableStorage: String = "Calculating..."
    @State private var batteryTimer: Timer?

    // Zoom control
    @State private var currentZoomLevel: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Camera Preview
            if isCameraReady {
                cameraPreviewLayer

                // Grid Overlay (optional)
                if showGrid {
                    CameraGridOverlay()
                        .allowsHitTesting(false)
                }

                // Top Status Bar
                topStatusBar

                // Bottom Controls
                bottomControls

            } else {
                // Loading State
                loadingView
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear {
            setupView()
        }
        .onDisappear {
            cleanupView()
        }
        .alert("Camera Error", isPresented: $showingCameraError) {
            Button("Try Again") {
                Task {
                    await retryCameraSetup()
                }
            }
            Button("Cancel", role: .cancel) {
                onFramingLocked() // Return to RecorderReadyView
            }
        } message: {
            Text(cameraErrorMessage)
        }
    }

    // MARK: - View Components

    private var cameraPreviewLayer: some View {
        SimpleCameraPreviewView(isCameraReady: $isCameraReady)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.all)
    }

    private var topStatusBar: some View {
        VStack {
            HStack(spacing: 16) {
                // Game Info
                if let game = liveGame {
                    HStack(spacing: 8) {
                        Image(systemName: "basketball.fill")
                            .foregroundColor(.orange)
                        Text("\(game.teamName) vs \(game.opponent)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                }

                Spacer()

                // Connection Status
                connectionStatusIndicator

                // System Status
                systemStatusIndicator
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Framing Instructions
            framingInstructions

            Spacer()
        }
    }

    private var connectionStatusIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(multipeer.connectionState.isConnected ? Color.green : Color.orange)
                .frame(width: 8, height: 8)

            Text(multipeer.connectionState.isConnected ? "Connected" : "Waiting")
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }

    private var systemStatusIndicator: some View {
        HStack(spacing: 8) {
            // Battery
            Image(systemName: batteryIcon)
                .foregroundColor(batteryColor)
            Text("\(Int(batteryLevel * 100))%")
                .font(.caption)
                .foregroundColor(batteryColor)

            Text("•")
                .foregroundColor(.gray)

            // Storage
            Text(availableStorage)
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }

    private var framingInstructions: some View {
        VStack(spacing: 12) {
            Text("📷 Frame Your Shot")
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: 6) {
                framingCheckItem(
                    icon: "checkmark.circle.fill",
                    text: "Both baskets visible",
                    isComplete: true
                )
                framingCheckItem(
                    icon: "checkmark.circle.fill",
                    text: "Court centered in frame",
                    isComplete: true
                )
                framingCheckItem(
                    icon: "level",
                    text: "Camera level",
                    isComplete: true
                )
            }
        }
        .padding(16)
        .background(.ultraThinMaterial.opacity(0.8))
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private func framingCheckItem(icon: String, text: String, isComplete: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(isComplete ? .green : .gray)
                .font(.caption)

            Text(text)
                .font(.caption)
                .foregroundColor(isComplete ? .white : .gray)

            Spacer()
        }
    }

    private var bottomControls: some View {
        VStack {
            Spacer()

            VStack(spacing: 16) {
                // Zoom Control
                zoomControl

                // Main Action Buttons
                HStack(spacing: 20) {
                    // Grid Toggle
                    Button(action: {
                        showGrid.toggle()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: showGrid ? "grid" : "grid")
                                .font(.title2)
                            Text(showGrid ? "Grid On" : "Grid Off")
                                .font(.caption)
                        }
                        .foregroundColor(showGrid ? .orange : .gray)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }

                    // Lock Framing Button (Primary)
                    Button(action: lockFraming) {
                        VStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.title)
                            Text("Lock Framing")
                                .font(.headline)
                            Text("Ready to Record")
                                .font(.caption)
                                .foregroundColor(.orange.opacity(0.8))
                        }
                        .foregroundColor(.white)
                        .frame(width: 200, height: 100)
                        .background(Color.orange)
                        .cornerRadius(16)
                        .shadow(color: .orange.opacity(0.5), radius: 10)
                    }
                    .disabled(!isCameraReady)

                    // Back Button
                    Button(action: {
                        onFramingLocked()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.title2)
                            Text("Cancel")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 40)
        }
    }

    private var zoomControl: some View {
        HStack(spacing: 12) {
            Text("Zoom")
                .font(.caption)
                .foregroundColor(.white)

            Button(action: { setZoom(0.5) }) {
                Text("0.5x")
                    .font(.caption)
                    .foregroundColor(abs(currentZoomLevel - 0.5) < 0.1 ? .orange : .white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(abs(currentZoomLevel - 0.5) < 0.1 ? Color.orange.opacity(0.3) : Color.clear)
                    .cornerRadius(6)
            }

            Button(action: { setZoom(1.0) }) {
                Text("1.0x")
                    .font(.caption)
                    .foregroundColor(abs(currentZoomLevel - 1.0) < 0.1 ? .orange : .white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(abs(currentZoomLevel - 1.0) < 0.1 ? Color.orange.opacity(0.3) : Color.clear)
                    .cornerRadius(6)
            }

            Button(action: { setZoom(2.0) }) {
                Text("2.0x")
                    .font(.caption)
                    .foregroundColor(abs(currentZoomLevel - 2.0) < 0.1 ? .orange : .white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(abs(currentZoomLevel - 2.0) < 0.1 ? Color.orange.opacity(0.3) : Color.clear)
                    .cornerRadius(6)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.orange)

            Text(loadingMessage)
                .font(.headline)
                .foregroundColor(.white)

            if cameraSetupAttempts > 0 {
                Text("Attempt \(cameraSetupAttempts) of 3")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    // MARK: - Computed Properties

    private var loadingMessage: String {
        if cameraSetupAttempts == 0 {
            return "Starting Camera..."
        } else {
            return "Initializing Camera..."
        }
    }

    private var batteryIcon: String {
        switch batteryLevel {
        case 0.75...1.0: return "battery.100"
        case 0.5..<0.75: return "battery.75"
        case 0.25..<0.5: return "battery.50"
        case 0.1..<0.25: return "battery.25"
        default: return "battery.0"
        }
    }

    private var batteryColor: Color {
        switch batteryLevel {
        case 0.3...1.0: return .green
        case 0.15..<0.3: return .orange
        default: return .red
        }
    }

    // MARK: - Lifecycle Methods

    private func setupView() {
        print("📷 CameraSetupView: Setting up camera framing view")

        // Keep screen awake
        UIApplication.shared.isIdleTimerDisabled = true

        // Lock to landscape for consistent framing
        AppDelegate.orientationLock = .landscape
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
        }

        // Setup battery monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true
        updateBatteryLevel()

        batteryTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            self.updateBatteryLevel()
            self.updateStorageInfo()
        }

        updateStorageInfo()

        // Setup camera with delay to avoid blocking multipeer
        setupCameraWithDelay()
    }

    private func cleanupView() {
        print("📷 CameraSetupView: Cleaning up")

        // DON'T stop camera session - it will be reused by CleanVideoRecordingView!
        // Just clean up our local state

        batteryTimer?.invalidate()
        UIDevice.current.isBatteryMonitoringEnabled = false

        // Reset orientation lock (will be set again by CleanVideoRecordingView)
        // Don't reset here if we're transitioning to recording
    }

    private func setupCameraWithDelay() {
        print("📷 CameraSetupView: Scheduling camera setup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Task(priority: .background) {
                await self.setupCamera()
            }
        }
    }

    private func setupCamera() async {
        guard !hasCameraSetup else {
            print("📷 CameraSetupView: Camera already setup")
            return
        }

        guard cameraSetupAttempts < 3 else {
            print("❌ CameraSetupView: Too many camera setup attempts")
            await MainActor.run {
                cameraErrorMessage = "Camera setup failed. Please check permissions and try again."
                showingCameraError = true
            }
            return
        }

        cameraSetupAttempts += 1
        print("📷 CameraSetupView: Setting up camera (attempt \(cameraSetupAttempts))")

        // Check if camera session is already running (from previous setup)
        if recordingManager.isCameraSessionRunning {
            print("✅ Camera session already running - reusing existing session")
            await MainActor.run {
                hasCameraSetup = true
                isCameraReady = true
            }
            return
        }

        // Setup camera in background to avoid blocking
        Task.detached(priority: .utility) {
            let hasPermission = await self.recordingManager.checkForCameraPermission()

            guard hasPermission else {
                await MainActor.run {
                    self.cameraErrorMessage = "Camera permission is required for framing."
                    self.showingCameraError = true
                }
                return
            }

            await MainActor.run {
                print("📷 CameraSetupView: Camera permission granted, setting up hardware...")

                if self.recordingManager.setupCamera() != nil {
                    print("✅ Camera hardware setup completed")
                    self.hasCameraSetup = true

                    self.recordingManager.startCameraSession()
                    print("📷 Camera session started")

                    // Wait for session to fully start
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        print("✅ Camera ready for framing")
                        self.isCameraReady = true

                        // Set default zoom to ultra-wide for full court view
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            let actualZoom = self.recordingManager.setZoom(factor: 0.5)
                            self.currentZoomLevel = actualZoom
                            print("📷 Set initial zoom to \(actualZoom)x (ultra-wide)")
                        }
                    }
                } else {
                    self.cameraErrorMessage = "Failed to initialize camera hardware."
                    self.showingCameraError = true
                }
            }
        }
    }

    private func retryCameraSetup() async {
        print("🔄 CameraSetupView: Retrying camera setup")
        hasCameraSetup = false
        isCameraReady = false
        await setupCamera()
    }

    // MARK: - Actions

    private func lockFraming() {
        print("🔒 CameraSetupView: Framing locked - ready for recording")
        isFramingLocked = true

        // Keep camera session alive!
        print("📷 Camera session will remain active for recording")

        // Callback to parent view
        onFramingLocked()
    }

    private func setZoom(_ factor: CGFloat) {
        let actualZoom = recordingManager.setZoom(factor: factor)
        currentZoomLevel = actualZoom
        print("📷 Zoom set to \(actualZoom)x")
    }

    // MARK: - Helper Methods

    private func updateBatteryLevel() {
        batteryLevel = UIDevice.current.batteryLevel
    }

    private func updateStorageInfo() {
        if let available = getAvailableStorage() {
            availableStorage = formatBytes(available)
        }
    }

    private func getAvailableStorage() -> Int64? {
        guard let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
            return nil
        }

        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: path)
            return attributes[.systemFreeSize] as? Int64
        } catch {
            return nil
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Preview

#Preview {
    CameraSetupView(
        liveGame: LiveGame(
            teamName: "Warriors",
            opponent: "Lakers",
            gameFormat: .halves,
            quarterLength: 20
        ),
        onFramingLocked: {
            print("Framing locked")
        }
    )
}
