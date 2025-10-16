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

    @Environment(\.dismiss) private var dismiss
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

    // Zoom control - use recordingManager's published property instead of local state

    var body: some View {
        ZStack {
            // Camera Preview - FULLSCREEN
            if isCameraReady {
                cameraPreviewLayer

                // Grid Overlay (optional, subtle)
                if showGrid {
                    CameraGridOverlay(opacity: 0.25, lineWidth: 0.5)
                        .allowsHitTesting(false)
                }

                // Minimal top status (just indicators, no cards)
                minimalTopStatus

                // Compact bottom controls
                compactBottomControls

            } else {
                // Loading State
                loadingView
            }
        }
        .edgesIgnoringSafeArea(.all)
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
                handleCancel()
            }
        } message: {
            Text(cameraErrorMessage)
        }
    }

    // MARK: - View Components

    private var cameraPreviewLayer: some View {
        SimpleCameraPreviewView(isCameraReady: $isCameraReady)
            .edgesIgnoringSafeArea(.all)
    }

    // MARK: - Minimal UI Components

    private var minimalTopStatus: some View {
        VStack(spacing: 0) {
            HStack {
                // Just connection indicator
                Circle()
                    .fill(multipeer.connectionState.isConnected ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(multipeer.connectionState.isConnected ? "Connected" : "Waiting")
                    .font(.caption2)
                    .foregroundColor(.white)

                Spacer()

                // Just battery status
                HStack(spacing: 4) {
                    Image(systemName: batteryIcon)
                        .font(.caption2)
                        .foregroundColor(batteryColor)
                    Text("\(Int(batteryLevel * 100))%")
                        .font(.caption2)
                        .foregroundColor(batteryColor)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.3))

            Spacer()
        }
    }

    private var compactBottomControls: some View {
        VStack {
            Spacer()

            VStack(spacing: 12) {
                // Compact zoom control (ultra-wide camera: 1x = widest, 2x = tighter)
                HStack(spacing: 8) {
                    Text("Zoom")
                        .font(.caption2)
                        .foregroundColor(.gray)

                    Button(action: { setZoom(1.0) }) {
                        Text("1x")
                            .font(.caption)
                            .fontWeight(abs(recordingManager.currentZoomLevel - 1.0) < 0.1 ? .semibold : .regular)
                            .foregroundColor(abs(recordingManager.currentZoomLevel - 1.0) < 0.1 ? .orange : .white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(abs(recordingManager.currentZoomLevel - 1.0) < 0.1 ? Color.orange.opacity(0.3) : Color.clear)
                            .cornerRadius(6)
                    }

                    Button(action: { setZoom(2.0) }) {
                        Text("2x")
                            .font(.caption)
                            .fontWeight(abs(recordingManager.currentZoomLevel - 2.0) < 0.1 ? .semibold : .regular)
                            .foregroundColor(abs(recordingManager.currentZoomLevel - 2.0) < 0.1 ? .orange : .white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(abs(recordingManager.currentZoomLevel - 2.0) < 0.1 ? Color.orange.opacity(0.3) : Color.clear)
                            .cornerRadius(6)
                    }

                    Button(action: { setZoom(3.0) }) {
                        Text("3x")
                            .font(.caption)
                            .fontWeight(abs(recordingManager.currentZoomLevel - 3.0) < 0.1 ? .semibold : .regular)
                            .foregroundColor(abs(recordingManager.currentZoomLevel - 3.0) < 0.1 ? .orange : .white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(abs(recordingManager.currentZoomLevel - 3.0) < 0.1 ? Color.orange.opacity(0.3) : Color.clear)
                            .cornerRadius(6)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.5))
                .cornerRadius(20)

                // Main controls - compact row
                HStack(spacing: 16) {
                    // Grid toggle
                    Button(action: { showGrid.toggle() }) {
                        Image(systemName: showGrid ? "grid" : "grid")
                            .font(.title2)
                            .foregroundColor(showGrid ? .orange : .white.opacity(0.7))
                            .frame(width: 54, height: 54)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(27)
                    }

                    // Lock framing - main action (just icon, larger)
                    Button(action: lockFraming) {
                        Image(systemName: "lock.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 70, height: 70)
                            .background(Color.orange)
                            .cornerRadius(35)
                    }
                    .disabled(!isCameraReady)

                    // Cancel
                    Button(action: handleCancel) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 54, height: 54)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(27)
                    }
                }
            }
            .padding(.bottom, 20)
        }
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

        // Reset orientation lock to portrait (unless we're transitioning to recording)
        if !isFramingLocked {
            print("📱 Resetting orientation to portrait")
            AppDelegate.orientationLock = .portrait
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            }
        }
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

                    // Minimal delay for session to stabilize (reduced from 1.5s to 0.3s total)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        print("✅ Camera ready for framing")
                        self.isCameraReady = true

                        // Log device zoom capabilities
                        let minZoom = self.recordingManager.getMinZoom()
                        let maxZoom = self.recordingManager.getMaxZoom()
                        let currentZoom = self.recordingManager.getCurrentZoom()
                        print("📷 Camera zoom capabilities:")
                        print("   Min: \(minZoom)x, Max: \(maxZoom)x, Current: \(currentZoom)x")
                        print("📷 Using ultra-wide camera - 1.0x is the widest view (full court coverage)")
                        // currentZoomLevel is now tracked by recordingManager (@Published property)
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

        // Callback to parent view (optional, for coordination)
        onFramingLocked()

        // Dismiss this view
        dismiss()
    }

    private func handleCancel() {
        print("❌ CameraSetupView: Cancelled - returning to ready view")

        // Keep camera session alive even on cancel!
        print("📷 Camera session will remain active")

        // Callback to parent view
        onFramingLocked()

        // Dismiss this view
        dismiss()
    }

    private func setZoom(_ factor: CGFloat) {
        _ = recordingManager.setZoom(factor: factor)
        // No need to update local state - recordingManager.currentZoomLevel is @Published
        print("📷 Zoom set to \(recordingManager.currentZoomLevel)x")
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
