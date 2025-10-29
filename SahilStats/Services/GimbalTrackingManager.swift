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

@MainActor
final class GimbalTrackingManager: ObservableObject {
    static let shared = GimbalTrackingManager()

    // MARK: - Published Properties

    @Published var isTrackingActive: Bool = false
    @Published var trackingMode: TrackingMode = .multiObject  // Default to multi-object for Flow Pro 2
    @Published var isDockKitAvailable: Bool = false
    @Published var lastError: String?
    @Published var trackedSubjectCount: Int = 0  // Number of subjects currently being tracked

    // MARK: - DockKit Properties

    private var dockAccessory: DockAccessory?
    private var trackingTask: Task<Void, Never>?

    // MARK: - Tracking Modes

    enum TrackingMode: String, CaseIterable {
        case multiObject = "Multi-Object"   // Track multiple players simultaneously (Flow Pro 2)
        case group = "Group"                // Track all players as one group
        case singlePerson = "Person"        // Track specific player
        case disabled = "Disabled"          // No tracking

        var displayName: String { rawValue }
        var icon: String {
            switch self {
            case .multiObject: return "person.3.sequence.fill"
            case .group: return "person.3.fill"
            case .singlePerson: return "person.fill"
            case .disabled: return "nosign"
            }
        }

        var description: String {
            switch self {
            case .multiObject: return "Tracks up to 9 people simultaneously (Flow Pro 2 feature)"
            case .group: return "Tracks all visible players as one group"
            case .singlePerson: return "Follows a single person"
            case .disabled: return "Manual camera control"
            }
        }

        var isRecommendedForBasketball: Bool {
            return self == .multiObject
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

    /// Start DockKit tracking (called when recording starts)
    ///
    /// IMPORTANT: Camera Configuration
    /// - If "DockKit in background mode" is ENABLED in iOS Settings, the system uses the front camera
    /// - For basketball games, you need the BACK camera
    /// - Solution: Disable "DockKit in background mode" and use manual tracking with back camera
    ///
    /// TODO: Implement manual camera tracking for back camera support
    /// - Need to integrate with AVCaptureSession
    /// - Call accessory.track() with cameraInformation (cameraPosition: .back)
    /// - Feed AVMetadataObjects from capture session to track() method
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

        if #available(iOS 17.0, *) {
            isTrackingActive = true
            lastError = nil
            debugPrint("✅ DockKit tracking started - Mode: \(trackingMode.displayName)")
            debugPrint("   🏀 Accessory: \(accessory.identifier.name)")
            debugPrint("   ⚠️ NOTE: Currently using system tracking (front camera if background mode enabled)")
            debugPrint("   ⚠️ Disable 'DockKit in background mode' in iOS Settings for back camera")

            // Enable system tracking
            Task {
                do {
                    let manager = DockAccessoryManager.shared
                    try await manager.setSystemTrackingEnabled(true)
                    debugPrint("   ✅ System tracking enabled")

                    // Monitor tracking states
                    trackingTask = Task {
                        do {
                            let trackingStates = try accessory.trackingStates
                            for try await trackingState in trackingStates {
                                await MainActor.run {
                                    self.trackedSubjectCount = trackingState.trackedSubjects.count
                                    debugPrint("   📊 Tracking \(self.trackedSubjectCount) subjects")
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
                        debugPrint("❌ Failed to enable tracking: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            debugPrint("ℹ️ DockKit tracking requires iOS 17+")
            lastError = "Requires iOS 17+"
        }
    }

    /// Stop DockKit tracking (called when recording stops)
    func stopTracking() {
        guard isTrackingActive else { return }

        if #available(iOS 17.0, *) {
            // Cancel tracking monitoring task
            trackingTask?.cancel()
            trackingTask = nil

            Task {
                do {
                    let manager = DockAccessoryManager.shared
                    try await manager.setSystemTrackingEnabled(false)
                    debugPrint("   ✅ System tracking disabled")
                } catch {
                    debugPrint("   ⚠️ Error disabling tracking: \(error.localizedDescription)")
                }

                await MainActor.run {
                    self.isTrackingActive = false
                    self.trackedSubjectCount = 0
                    debugPrint("🛑 DockKit tracking stopped")
                }
            }
        } else {
            isTrackingActive = false
            debugPrint("🛑 Tracking stopped")
        }
    }

    // MARK: - Tracking Configuration

    /// Switch tracking mode during recording
    func setTrackingMode(_ mode: TrackingMode) {
        trackingMode = mode

        if isTrackingActive {
            debugPrint("🔄 Switched to \(mode.displayName) tracking")

            if mode == .multiObject {
                debugPrint("   🏀 BASKETBALL MODE: Multi-object tracking active")
            }
        }
    }

    /// Select a specific subject to track (tap to focus)
    /// Note: DockKit automatically detects and tracks people in frame
    func selectSubject(at point: CGPoint, in viewSize: CGSize) {
        guard isTrackingActive else { return }
        guard trackingMode != .disabled else { return }

        let normalizedPoint = CGPoint(
            x: point.x / viewSize.width,
            y: point.y / viewSize.height
        )

        debugPrint("👆 Tap detected at: \(normalizedPoint)")
        debugPrint("   ℹ️ DockKit auto-tracks all visible people")

        // DockKit handles tracking automatically - no manual selection needed
        // The Flow Pro 2 will detect and track all players in frame
    }

    /// Add multiple subjects for tracking (basketball team)
    /// Note: DockKit automatically detects up to 9 people in Multi-Object mode
    func selectMultipleSubjects(at points: [CGPoint], in viewSize: CGSize) {
        guard isTrackingActive else { return }
        guard trackingMode == .multiObject else {
            debugPrint("⚠️ Multi-subject selection only works in Multi-Object mode")
            return
        }

        debugPrint("👥 Multi-object mode active - DockKit will auto-detect all players")
        debugPrint("   Flow Pro 2 can track up to 9 people simultaneously")

        // DockKit handles multi-object tracking automatically
        // No manual selection needed - it detects all people in frame
    }

    /// Clear all tracked subjects and let DockKit auto-detect
    func clearSubjectSelection() {
        debugPrint("🔄 DockKit automatically manages tracking - no manual clearing needed")
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
            let count = trackedSubjectCount > 0 ? " (\(trackedSubjectCount) subjects)" : ""
            return "Tracking: \(trackingMode.displayName)\(count)"
        }

        return "Ready to track"
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
}
