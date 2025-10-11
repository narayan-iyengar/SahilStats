//
//  DeviceRole.swift
//  SahilStats
//
//  Shared model for device roles - used by main app and widget
//

import Foundation
import SwiftUI

enum DeviceRole: String, Codable, CaseIterable {
    case none = "none"
    case recorder = "recorder"
    case controller = "controller"
    case viewer = "viewer"

    var displayName: String {
        switch self {
        case .none: return "Select Role"
        case .recorder: return "Recording Device"
        case .controller: return "Control Device"
        case .viewer: return "Viewer"
        }
    }

    var description: String {
        switch self {
        case .none: return "Choose your device's role"
        case .recorder: return "Focus on video recording with live overlay"
        case .controller: return "Control scoring, stats, and game clock"
        case .viewer: return "Watch live game without controls"
        }
    }

    var icon: String {
        switch self {
        case .none: return "questionmark.circle"
        case .recorder: return "video.fill"
        case .controller: return "gamecontroller.fill"
        case .viewer: return "eye.fill"
        }
    }

    var preferredDevice: String {
        switch self {
        case .recorder: return "iPhone (better camera)"
        case .controller: return "iPad (larger screen)"
        case .viewer: return "Any device"
        case .none: return ""
        }
    }

    var color: Color {
        switch self {
        case .controller: return .blue
        case .recorder: return .red
        case .viewer: return .green
        case .none: return .gray
        }
    }

    var joinDescription: String {
        switch self {
        case .controller: return "Control scoring and game clock"
        case .recorder: return "Record video with live overlay"
        case .viewer: return "Watch and view stats in real-time"
        case .none: return ""
        }
    }
}
