//
//  OrientationManager.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/27/25.
//
// OrientationManager.swift - Updated for better landscape detection

import SwiftUI
import Combine

@MainActor
class OrientationManager: ObservableObject {
    @Published var orientation = UIDevice.current.orientation
    @Published var isLandscape = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        updateLandscapeState()
        startObserving()
    }
    
    private func startObserving() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateOrientation()
            }
            .store(in: &cancellables)
    }
    
    private func updateOrientation() {
        let newOrientation = UIDevice.current.orientation
        
        // Only update for valid interface orientations
        if newOrientation.isValidInterfaceOrientation {
            orientation = newOrientation
            updateLandscapeState()
            debugPrint("📱 Orientation updated: \(orientation.debugDescription), isLandscape: \(isLandscape)")
        }
    }
    
    private func updateLandscapeState() {
        // Check both device orientation and interface orientation
        let deviceIsLandscape = orientation.isLandscape
        
        // Also check interface orientation as backup using the new API
        let interfaceIsLandscape: Bool
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            interfaceIsLandscape = windowScene.effectiveGeometry.interfaceOrientation.isLandscape
        } else {
            interfaceIsLandscape = false
        }
        
        isLandscape = deviceIsLandscape || interfaceIsLandscape
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        Task { @MainActor in
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
    }
}

extension UIDeviceOrientation {
    var isValidInterfaceOrientation: Bool {
        switch self {
        case .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight:
            return true
        default:
            return false
        }
    }
    
    var debugDescription: String {
        switch self {
        case .portrait: return "Portrait"
        case .portraitUpsideDown: return "Portrait Upside Down"
        case .landscapeLeft: return "Landscape Left"
        case .landscapeRight: return "Landscape Right"
        case .faceUp: return "Face Up"
        case .faceDown: return "Face Down"
        case .unknown: return "Unknown"
        @unknown default: return "Unknown"
        }
    }
}
