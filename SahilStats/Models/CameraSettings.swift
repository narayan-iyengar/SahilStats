//
//  CameraSettings.swift
//  SahilStats
//
//  Camera recording settings with user preferences
//

import Foundation
import AVFoundation
import Combine

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
        stabilizationEnabled: true
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

    private let userDefaultsKey = "cameraSettings"

    private init() {
        // Load saved settings or use defaults
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(CameraSettings.self, from: data) {
            self.settings = decoded
            print("📱 Loaded camera settings: \(decoded.resolution.displayName), \(decoded.frameRate.displayName)")
        } else {
            self.settings = .default
            print("📱 Using default camera settings")
        }
    }

    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
            print("💾 Camera settings saved")
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
