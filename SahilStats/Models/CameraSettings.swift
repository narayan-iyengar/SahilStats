//
//  CameraSettings.swift
//  SahilStats
//
//  Camera recording settings with user preferences
//

import Foundation
import AVFoundation
import Combine
import FirebaseAuth
import FirebaseFirestore

struct CameraSettings: Codable {

    // MARK: - Video Quality

    enum VideoResolution: String, Codable, CaseIterable {
        case uhd4K = "4K"           // 3840×2160
        case fullHD = "1080p"       // 1920×1080
        case hd = "720p"            // 1280×720

        var displayName: String {
            rawValue
        }

        var sessionPreset: AVCaptureSession.Preset {
            switch self {
            case .uhd4K: return .hd4K3840x2160
            case .fullHD: return .hd1920x1080
            case .hd: return .hd1280x720
            }
        }

        var dimensions: (width: Int, height: Int) {
            switch self {
            case .uhd4K: return (3840, 2160)
            case .fullHD: return (1920, 1080)
            case .hd: return (1280, 720)
            }
        }

        var defaultBitrate: Int {
            switch self {
            case .uhd4K: return 20_000_000   // 20 Mbps
            case .fullHD: return 8_000_000   // 8 Mbps
            case .hd: return 4_000_000       // 4 Mbps
            }
        }
    }

    enum FrameRate: Int, Codable, CaseIterable {
        case fps30 = 30
        case fps60 = 60

        var displayName: String {
            "\(rawValue) fps"
        }
    }

    enum VideoCodec: String, Codable, CaseIterable {
        case h264 = "H.264"
        case hevc = "HEVC"   // H.265 - better compression, smaller files

        var displayName: String {
            switch self {
            case .h264: return "H.264 (Compatible)"
            case .hevc: return "HEVC/H.265 (Efficient)"
            }
        }

        var avCodec: AVVideoCodecType {
            switch self {
            case .h264: return .h264
            case .hevc: return .hevc
            }
        }
    }

    // MARK: - Properties

    var resolution: VideoResolution
    var frameRate: FrameRate
    var codec: VideoCodec
    var customBitrate: Int?  // Nil = use default for resolution
    var stabilizationEnabled: Bool
    var keepRecorderScreenAwake: Bool  // Keep screen awake during recording (for dedicated cameraman)

    // MARK: - Computed Properties

    var bitrate: Int {
        customBitrate ?? resolution.defaultBitrate
    }

    var bitrateInMbps: Double {
        Double(bitrate) / 1_000_000.0
    }

    // MARK: - Defaults

    static let `default` = CameraSettings(
        resolution: .uhd4K,
        frameRate: .fps30,
        codec: .h264,
        customBitrate: nil,
        stabilizationEnabled: true,
        keepRecorderScreenAwake: true  // Default to keeping screen awake during recording
    )
}

// MARK: - Settings Manager

class CameraSettingsManager: ObservableObject {
    static let shared = CameraSettingsManager()

    @Published var settings: CameraSettings {
        didSet {
            saveSettings()
        }
    }

    private let localStorageKey = "cameraSettings"
    private var userId: String?

    private init() {
        // Load settings from local cache first (instant load)
        if let data = UserDefaults.standard.data(forKey: localStorageKey),
           let decoded = try? JSONDecoder().decode(CameraSettings.self, from: data) {
            self.settings = decoded
            print("📱 Loaded camera settings from local cache")
        } else {
            self.settings = .default
            print("📱 Using default camera settings")
        }

        // Load from Firebase in background
        Task {
            await loadFromFirebase()
        }
    }

    func setUserId(_ userId: String) {
        self.userId = userId
        Task {
            await loadFromFirebase()
        }
    }

    private func loadFromFirebase() async {
        guard let userId = userId ?? FirebaseAuth.Auth.auth().currentUser?.uid else {
            print("⚠️ No user ID available - using local settings only")
            return
        }

        do {
            let db = FirebaseFirestore.Firestore.firestore()
            let document = try await db.collection("userSettings").document(userId).getDocument()

            if let data = document.data()?["cameraSettings"] as? [String: Any] {
                // Convert Firebase data to CameraSettings
                if let jsonData = try? JSONSerialization.data(withJSONObject: data),
                   let decoded = try? JSONDecoder().decode(CameraSettings.self, from: jsonData) {
                    await MainActor.run {
                        self.settings = decoded
                        // Also save to local cache
                        if let encoded = try? JSONEncoder().encode(decoded) {
                            UserDefaults.standard.set(encoded, forKey: self.localStorageKey)
                        }
                        print("☁️ Loaded camera settings from Firebase")
                    }
                }
            } else {
                print("📱 No camera settings in Firebase - using current settings")
                // Save current settings to Firebase
                await saveToFirebase()
            }
        } catch {
            print("❌ Failed to load camera settings from Firebase: \(error)")
        }
    }

    private func saveSettings() {
        // Save to local cache immediately (instant)
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: localStorageKey)
            print("💾 Camera settings saved to local cache")
        }

        // Save to Firebase in background
        Task {
            await saveToFirebase()
        }
    }

    private func saveToFirebase() async {
        guard let userId = userId ?? FirebaseAuth.Auth.auth().currentUser?.uid else {
            print("⚠️ No user ID available - skipping Firebase save")
            return
        }

        do {
            let db = FirebaseFirestore.Firestore.firestore()
            let encoded = try JSONEncoder().encode(settings)
            let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] ?? [:]

            try await db.collection("userSettings").document(userId).setData([
                "cameraSettings": json
            ], merge: true)

            print("☁️ Camera settings saved to Firebase")
        } catch {
            print("❌ Failed to save camera settings to Firebase: \(error)")
        }
    }

    func resetToDefaults() {
        settings = .default
    }

    /// Check if device supports the current resolution
    func validateSettings() -> Bool {
        let session = AVCaptureSession()
        return session.canSetSessionPreset(settings.resolution.sessionPreset)
    }

    /// Get best available resolution for current device
    func getBestAvailableResolution() -> CameraSettings.VideoResolution {
        let session = AVCaptureSession()

        if session.canSetSessionPreset(.hd4K3840x2160) {
            return .uhd4K
        } else if session.canSetSessionPreset(.hd1920x1080) {
            return .fullHD
        } else {
            return .hd
        }
    }
}
