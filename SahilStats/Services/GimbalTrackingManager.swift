//
//  GimbalTrackingManager.swift
//  SahilStats
//
//  DockKit integration for Insta360 Flow 2 Pro smart tracking
//  Automatically tracks players and frames action during recording
//
//  Requires: iOS 18+ with DockKit framework
//

import Foundation
import AVFoundation
import Combine
import SwiftUI
import DockKit
import Vision

@MainActor
final class GimbalTrackingManager: ObservableObject {
    static let shared = GimbalTrackingManager()

    // MARK: - Published Properties

    @Published var isTrackingActive: Bool = false
    @Published var trackingMode: TrackingMode = .intelligentCourt  // Default to intelligent court tracking
    @Published var isDockKitAvailable: Bool = false
    @Published var lastError: String?
    @Published var trackedSubjectCount: Int = 0  // Number of subjects currently being tracked
    @Published var isUsingIntelligentTracking: Bool = false  // iOS 18+ ML-based tracking

    // MARK: - DockKit Properties

    private var dockAccessory: DockAccessory?
    private var trackingTask: Task<Void, Never>?
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?

    // Court region for tracking (normalized coordinates 0.0-1.0)
    private var courtRegion: CGRect {
        getSavedCourtRegion() ?? CGRect(x: 0.05, y: 0.15, width: 0.9, height: 0.75)
    }

    // Dynamic zoom based on player spread
    @Published var isAutoZoomEnabled: Bool = true
    private var lastSubjectPositions: [CGPoint] = []

    // MARK: - Tracking Modes

    enum TrackingMode: String, CaseIterable {
        case intelligentCourt = "Smart Court"  // iOS 18+ ML-based action tracking (RECOMMENDED)
        case courtZone = "Court Zone"          // Track specific court region
        case disabled = "Disabled"             // No tracking

        var displayName: String { rawValue }
        var icon: String {
            switch self {
            case .intelligentCourt: return "brain.fill"
            case .courtZone: return "rectangle.on.rectangle"
            case .disabled: return "nosign"
            }
        }

        var description: String {
            switch self {
            case .intelligentCourt: return "AI automatically follows game action using ML (iOS 18+)"
            case .courtZone: return "Keeps basketball court area in frame"
            case .disabled: return "Gimbal stays stationary"
            }
        }

        var isRecommendedForBasketball: Bool {
            return self == .intelligentCourt
        }
    }

    // MARK: - Private Properties

    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "dockkit_tracking_enabled")
    }

    private init() {
        checkDockKitAvailability()
    }

    // MARK: - DockKit Availability

    private func checkDockKitAvailability() {
        if #available(iOS 17.0, *) {
            debugPrint("🔍 Checking DockKit availability...")

            // Monitor DockAccessory state changes
            Task {
                do {
                    let manager = DockAccessoryManager.shared
                    debugPrint("   📡 Getting accessory state changes...")
                    let stateChanges = try manager.accessoryStateChanges
                    debugPrint("   ✅ Monitoring DockKit accessories")

                    // The first iteration will give us the current state
                    for await stateChange in stateChanges {
                        debugPrint("   🔄 DockKit state change received")
                        debugPrint("      State: \(stateChange.state)")
                        debugPrint("      Tracking button: \(stateChange.trackingButtonEnabled)")

                        await MainActor.run {
                            if let accessory = stateChange.accessory {
                                // Accessory connected
                                self.dockAccessory = accessory
                                self.isDockKitAvailable = true
                                debugPrint("✅ DockKit gimbal detected: \(accessory.identifier.name)")
                                debugPrint("   Category: \(accessory.identifier.category)")
                                debugPrint("   UUID: \(accessory.identifier.uuid)")
                                if let firmware = accessory.firmwareVersion {
                                    debugPrint("   Firmware: \(firmware)")
                                }
                                if let model = accessory.hardwareModel {
                                    debugPrint("   Model: \(model)")
                                }
                            } else {
                                // Accessory disconnected or no accessory
                                self.dockAccessory = nil
                                self.isDockKitAvailable = false
                                debugPrint("ℹ️ No DockKit accessory connected")
                                debugPrint("   Make sure your gimbal is:")
                                debugPrint("   • Powered on")
                                debugPrint("   • Connected via Bluetooth")
                                debugPrint("   • Your iPhone is mounted on it")
                            }
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.isDockKitAvailable = false
                        self.lastError = error.localizedDescription
                        debugPrint("❌ DockKit error: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            isDockKitAvailable = false
            debugPrint("ℹ️ DockKit requires iOS 17.0+")
            debugPrint("   Update iOS to enable gimbal tracking")
        }
    }

    // MARK: - Tracking Control

    /// Start DockKit intelligent tracking for basketball games
    ///
    /// Features:
    /// - Uses back camera explicitly (no "DockKit in background mode" workaround needed)
    /// - Sets region of interest to basketball court area
    /// - Enables iOS 18+ ML-based intelligent subject selection
    /// - Automatically follows game action without manual intervention
    ///
    func startTracking(with captureSession: AVCaptureSession? = nil) {
        guard isEnabled else {
            debugPrint("⏭️ DockKit tracking disabled in settings")
            return
        }

        guard let accessory = dockAccessory else {
            debugPrint("❌ No DockKit accessory available")
            lastError = "No gimbal connected"
            return
        }

        guard trackingMode != .disabled else {
            debugPrint("ℹ️ Tracking mode is disabled")
            return
        }

        if #available(iOS 18.0, *) {
            isTrackingActive = true
            lastError = nil
            debugPrint("✅ DockKit intelligent tracking started")
            debugPrint("   🏀 Mode: \(trackingMode.displayName)")
            debugPrint("   🎯 Accessory: \(accessory.identifier.name)")

            Task {
                do {
                    // Set region of interest to basketball court area
                    // Normalized coordinates: x, y, width, height (0.0 - 1.0)
                    // This keeps the court in frame and tracks action within it
                    let courtRegion = CGRect(
                        x: 0.05,    // 5% from left edge
                        y: 0.15,    // 15% from top (account for scoreboard)
                        width: 0.9,  // 90% width (full court coverage)
                        height: 0.75 // 75% height (court area, not benches)
                    )

                    try await accessory.setRegionOfInterest(courtRegion)
                    debugPrint("   ✅ Court region of interest set")
                    debugPrint("      Area: \(Int(courtRegion.width * 100))% width × \(Int(courtRegion.height * 100))% height")

                    // Enable intelligent tracking (iOS 18+ ML-based)
                    if trackingMode == .intelligentCourt {
                        // Use system tracking with intelligent subject selection
                        // The ML model will analyze body pose, face pose, attention, speaking
                        // to automatically select the most relevant player to track
                        let manager = DockAccessoryManager.shared
                        try await manager.setSystemTrackingEnabled(true)

                        await MainActor.run {
                            self.isUsingIntelligentTracking = true
                        }

                        debugPrint("   🧠 Intelligent ML tracking enabled")
                        debugPrint("      AI will automatically select most relevant player")
                        debugPrint("      Analyzes: body pose, face pose, attention, speaking")
                    } else if trackingMode == .courtZone {
                        // Zone tracking only - keep region in frame without intelligent selection
                        let manager = DockAccessoryManager.shared
                        try await manager.setSystemTrackingEnabled(true)

                        debugPrint("   📍 Court zone tracking enabled")
                        debugPrint("      Keeping court area in frame")
                    }

                    // Monitor tracking states and apply dynamic zoom
                    trackingTask = Task {
                        do {
                            let trackingStates = try accessory.trackingStates
                            var lastFraming: String = "center"

                            for try await trackingState in trackingStates {
                                await MainActor.run {
                                    self.trackedSubjectCount = trackingState.trackedSubjects.count

                                    if trackingState.trackedSubjects.count > 0 {
                                        debugPrint("   📊 Tracking \(trackingState.trackedSubjects.count) subjects")

                                        // Apply dynamic zoom if enabled
                                        if self.isAutoZoomEnabled {
                                            // Extract subject positions (normalized coordinates)
                                            let subjectPositions = trackingState.trackedSubjects.map { subject in
                                                // Convert subject rectangle to center point
                                                CGPoint(
                                                    x: subject.rect.midX,
                                                    y: subject.rect.midY
                                                )
                                            }

                                            // Calculate optimal framing
                                            let optimalFraming = self.calculateOptimalFraming(subjects: subjectPositions)

                                            // Only update framing if it changed (avoid constant adjustments)
                                            if optimalFraming != lastFraming {
                                                lastFraming = optimalFraming

                                                // Apply framing to gimbal
                                                Task {
                                                    do {
                                                        switch optimalFraming {
                                                        case "wide":
                                                            // Subjects spread out - zoom out for full court view
                                                            try await accessory.setFraming(.wide)
                                                            debugPrint("   📹 Auto-zoom: WIDE (transition/fast break)")
                                                        case "tight":
                                                            // Subjects clustered - zoom in on action
                                                            try await accessory.setFraming(.tight)
                                                            debugPrint("   📹 Auto-zoom: TIGHT (clustered play)")
                                                        default:
                                                            // Medium framing
                                                            try await accessory.setFraming(.center)
                                                            debugPrint("   📹 Auto-zoom: CENTER (normal play)")
                                                        }
                                                    } catch {
                                                        debugPrint("   ⚠️ Framing error: \(error.localizedDescription)")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        } catch {
                            debugPrint("   ⚠️ Tracking states error: \(error.localizedDescription)")
                        }
                    }

                } catch {
                    await MainActor.run {
                        self.lastError = error.localizedDescription
                        self.isTrackingActive = false
                        self.isUsingIntelligentTracking = false
                        debugPrint("❌ Failed to enable tracking: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            debugPrint("⚠️ Intelligent tracking requires iOS 18+")
            debugPrint("   Your device: iOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
            lastError = "Requires iOS 18+ for intelligent tracking"
        }
    }

    /// Stop DockKit tracking (called when recording stops)
    func stopTracking() {
        guard isTrackingActive else { return }

        if #available(iOS 18.0, *) {
            // Cancel tracking monitoring task
            trackingTask?.cancel()
            trackingTask = nil

            Task {
                do {
                    let manager = DockAccessoryManager.shared
                    try await manager.setSystemTrackingEnabled(false)
                    debugPrint("   ✅ Intelligent tracking disabled")
                } catch {
                    debugPrint("   ⚠️ Error disabling tracking: \(error.localizedDescription)")
                }

                await MainActor.run {
                    self.isTrackingActive = false
                    self.isUsingIntelligentTracking = false
                    self.trackedSubjectCount = 0
                    debugPrint("🛑 DockKit tracking stopped")
                }
            }
        } else {
            isTrackingActive = false
            isUsingIntelligentTracking = false
            debugPrint("🛑 Tracking stopped")
        }
    }

    // MARK: - Tracking Configuration

    /// Switch tracking mode
    func setTrackingMode(_ mode: TrackingMode) {
        trackingMode = mode

        if isTrackingActive {
            debugPrint("🔄 Switched to \(mode.displayName) tracking")

            if mode == .intelligentCourt {
                debugPrint("   🧠 INTELLIGENT MODE: AI-based action tracking active")
                debugPrint("      ML analyzes players to follow game action")
            } else if mode == .courtZone {
                debugPrint("   📍 ZONE MODE: Court area framing active")
                debugPrint("      Gimbal keeps court in frame")
            }

            // Note: Changing mode during recording requires restarting tracking
            // For now, mode should be set before recording starts
        }
    }

    // MARK: - Settings

    /// Enable or disable DockKit tracking
    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "dockkit_tracking_enabled")
        debugPrint("⚙️ DockKit tracking \(enabled ? "enabled" : "disabled")")

        // If disabled while tracking, stop immediately
        if !enabled && isTrackingActive {
            stopTracking()
        }
    }

    /// Get current enabled state
    func isTrackingEnabled() -> Bool {
        return isEnabled
    }

    // MARK: - Diagnostics

    /// Get tracking status for UI display
    func getTrackingStatus() -> String {
        if !isDockKitAvailable {
            return "No gimbal connected"
        }

        if !isEnabled {
            return "Tracking disabled"
        }

        if isTrackingActive {
            var status = ""
            if isUsingIntelligentTracking {
                status = "🧠 AI Tracking"
            } else {
                status = trackingMode.displayName
            }

            if trackedSubjectCount > 0 {
                status += " (\(trackedSubjectCount) subjects)"
            }

            return status
        }

        return "Ready - \(trackingMode.displayName)"
    }

    /// Get detailed tracking info for diagnostics view
    func getTrackingInfo() -> TrackingInfo {
        return TrackingInfo(
            isAvailable: isDockKitAvailable,
            isEnabled: isEnabled,
            isActive: isTrackingActive,
            mode: trackingMode,
            error: lastError
        )
    }

    struct TrackingInfo {
        let isAvailable: Bool
        let isEnabled: Bool
        let isActive: Bool
        let mode: TrackingMode
        let error: String?

        var statusColor: Color {
            if let _ = error { return .red }
            if isActive { return .green }
            if isEnabled { return .orange }
            return .gray
        }

        var statusIcon: String {
            if let _ = error { return "exclamationmark.triangle.fill" }
            if isActive { return "checkmark.circle.fill" }
            if isEnabled { return "circle.fill" }
            return "circle"
        }
    }

    // MARK: - Court Region Management

    /// Save court region coordinates
    func saveCourtRegion(_ region: CGRect) {
        let regionData: [String: Double] = [
            "x": region.minX,
            "y": region.minY,
            "width": region.width,
            "height": region.height
        ]
        UserDefaults.standard.set(regionData, forKey: "dockkit_court_region")
        debugPrint("✅ Court region saved: \(Int(region.width * 100))% × \(Int(region.height * 100))%")
    }

    /// Load saved court region
    func getSavedCourtRegion() -> CGRect? {
        guard let regionData = UserDefaults.standard.dictionary(forKey: "dockkit_court_region") as? [String: Double],
              let x = regionData["x"],
              let y = regionData["y"],
              let width = regionData["width"],
              let height = regionData["height"] else {
            return nil
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Reset court region to default
    func resetCourtRegion() {
        UserDefaults.standard.removeObject(forKey: "dockkit_court_region")
        debugPrint("🔄 Court region reset to default")
    }

    // MARK: - Dynamic Zoom Control

    /// Calculate optimal zoom level based on subject spread
    /// Returns framing suggestion: .wide (subjects spread out) or .tight (subjects clustered)
    private func calculateOptimalFraming(subjects: [CGPoint]) -> String {
        guard subjects.count >= 2 else {
            return "center" // Default framing for single subject
        }

        // Calculate bounding box of all subjects
        let minX = subjects.map { $0.x }.min() ?? 0
        let maxX = subjects.map { $0.x }.max() ?? 1
        let minY = subjects.map { $0.y }.min() ?? 0
        let maxY = subjects.map { $0.y }.max() ?? 1

        let spread = CGSize(
            width: maxX - minX,
            height: maxY - minY
        )

        // Determine framing based on spread
        // Wide spread (>50% of court) = zoom out
        // Tight spread (<30% of court) = zoom in
        // Medium = center framing

        let spreadPercent = max(spread.width, spread.height)

        if spreadPercent > 0.5 {
            return "wide" // Transition/fast break - zoom out
        } else if spreadPercent < 0.3 {
            return "tight" // Clustered play - zoom in
        } else {
            return "center" // Normal play
        }
    }

    /// Enable or disable automatic zoom
    func setAutoZoom(_ enabled: Bool) {
        isAutoZoomEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "dockkit_auto_zoom_enabled")
        debugPrint("⚙️ Auto-zoom \(enabled ? "enabled" : "disabled")")
    }

    /// Get auto-zoom enabled state
    func isAutoZoomOn() -> Bool {
        return UserDefaults.standard.bool(forKey: "dockkit_auto_zoom_enabled")
    }
}
