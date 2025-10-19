//
//  DeviceControlManager.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/19/25.
//
// MARK: - Enhanced Device Control Manager with Proper Control Transfer
import Combine
import Foundation
import SwiftUI
import FirebaseFirestore

class DeviceControlManager: ObservableObject {
    // 1. Create a shared static instance
    static let shared = DeviceControlManager()

    @Published var deviceId: String
    @Published var hasControl: Bool = false
    @Published var controllingUser: String?
    @Published var canRequestControl: Bool = true
    @Published var pendingControlRequest: String? = nil // NEW: Track pending requests
    
    private let firebaseService = FirebaseService.shared
    
    // 2. Make the initializer private to prevent creating new instances
    private init() {
        if let existingId = UserDefaults.standard.string(forKey: "deviceId") {
            self.deviceId = existingId
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: "deviceId")
            self.deviceId = newId
        }
    }
  
    
    /*
    // ENHANCED: Request control with timeout tracking
    func requestControl(for liveGame: LiveGame, userEmail: String?) async throws -> Bool {
        guard let gameId = liveGame.id,
              let email = userEmail else {
            throw DeviceControlError.invalidRequest
        }
        
        debugPrint("--- Requesting Control ---")
        debugPrint("Device ID: \(deviceId)")
        debugPrint("User Email: \(email)")
        debugPrint("Current Controlling Device: \(liveGame.controllingDeviceId ?? "None")")
        debugPrint("Current Controlling User: \(liveGame.controllingUserEmail ?? "None")")
        
        // Check if there's an expired control request and clean it up
        if let requestTimestamp = liveGame.controlRequestTimestamp,
           Date().timeIntervalSince(requestTimestamp) > 120 { // 2 minutes = 120 seconds
            debugPrint("Found expired control request, cleaning up...")
            try await clearExpiredControlRequest(for: liveGame)
        }
        
        // If no one has control, grant it immediately
        if liveGame.controllingDeviceId == nil || liveGame.controllingUserEmail == nil {
            debugPrint("No one has control, granting immediately")
            try await grantControlDirectly(for: liveGame, to: email)
            return true
        }
        
        // If this device already has control, no need to request
        if liveGame.controllingDeviceId == deviceId && liveGame.controllingUserEmail == email {
            debugPrint("This device already has control")
            return true
        }
        
        // SPECIAL CASE: If this device created the game but somehow lost control, auto-grant it back
        if liveGame.controllingDeviceId == deviceId && liveGame.createdBy == email {
            debugPrint("This device created the game, auto-granting control back")
            try await grantControlDirectly(for: liveGame, to: email)
            return true
        }
        
        // Otherwise, request control from current controller with timestamp
        debugPrint("Requesting control from current controller")
        var updatedGame = liveGame
        updatedGame.controlRequestedBy = email
        updatedGame.controlRequestingDeviceId = deviceId
        updatedGame.controlRequestTimestamp = Date() // NEW: Track when request was made
        
        try await firebaseService.updateLiveGame(updatedGame)
        return false // Control not granted yet, waiting for approval
    }
    */


    // This function now directly TAKES control instead of just requesting it.
    func requestControl(for liveGame: LiveGame, userEmail: String?) async throws {
        guard let email = userEmail else {
            throw DeviceControlError.invalidRequest
        }

        debugPrint("--- Taking Control ---")
        var updatedGame = liveGame
        updatedGame.controllingDeviceId = self.deviceId
        updatedGame.controllingUserEmail = email
        
        // Clear any old requests to keep the data clean.
        updatedGame.controlRequestedBy = nil
        updatedGame.controlRequestingDeviceId = nil
        updatedGame.controlRequestTimestamp = nil

        // Update the game document in Firebase with the new controller.
        try await firebaseService.updateLiveGame(updatedGame)
        debugPrint("✅ Control successfully taken by \(email) on device \(self.deviceId)")
    }
    
    // NEW: Clear expired control request
    private func clearExpiredControlRequest(for liveGame: LiveGame) async throws {
        var updatedGame = liveGame
        updatedGame.controlRequestedBy = nil
        updatedGame.controlRequestingDeviceId = nil
        updatedGame.controlRequestTimestamp = nil
        
        try await firebaseService.updateLiveGame(updatedGame)
        debugPrint("Expired control request cleared")
    }
    
    // NEW: Grant control directly (when no one has control)
    private func grantControlDirectly(for liveGame: LiveGame, to userEmail: String) async throws {
        var updatedGame = liveGame
        updatedGame.controllingDeviceId = deviceId
        updatedGame.controllingUserEmail = userEmail
        updatedGame.controlRequestedBy = nil
        updatedGame.controlRequestingDeviceId = nil
        
        try await firebaseService.updateLiveGame(updatedGame)
        debugPrint("Control granted directly to \(userEmail) on device \(deviceId)")
    }
    
    // ENHANCED: Grant control to requesting device (clear timestamp)
    func grantControl(for liveGame: LiveGame, to userEmail: String) async throws {
        guard let _ = liveGame.id else {
            throw DeviceControlError.invalidRequest
        }
        
        debugPrint("--- Granting Control ---")
        debugPrint("Granting control to: \(userEmail)")
        debugPrint("Requesting Device ID: \(liveGame.controlRequestingDeviceId ?? "Unknown")")
        
        var updatedGame = liveGame
        // Grant control to the requesting device, not the current device
        updatedGame.controllingDeviceId = liveGame.controlRequestingDeviceId ?? deviceId
        updatedGame.controllingUserEmail = userEmail
        updatedGame.controlRequestedBy = nil
        updatedGame.controlRequestingDeviceId = nil
        updatedGame.controlRequestTimestamp = nil // CLEAR: Remove timestamp when granting
        
        try await firebaseService.updateLiveGame(updatedGame)
        debugPrint("Control granted to \(userEmail) on device \(updatedGame.controllingDeviceId ?? "Unknown")")
    }
    
    // ENHANCED: Release control properly (clear timestamp)
    func releaseControl(for liveGame: LiveGame) async throws {
        guard let _ = liveGame.id else {
            throw DeviceControlError.invalidRequest
        }
        
        debugPrint("--- Releasing Control ---")
        debugPrint("Current Device: \(deviceId)")
        debugPrint("Controlling Device: \(liveGame.controllingDeviceId ?? "None")")
        
        var updatedGame = liveGame
        updatedGame.controllingDeviceId = nil
        updatedGame.controllingUserEmail = nil
        updatedGame.controlRequestedBy = nil
        updatedGame.controlRequestingDeviceId = nil
        updatedGame.controlRequestTimestamp = nil // CLEAR: Remove timestamp when releasing
        
        try await firebaseService.updateLiveGame(updatedGame)
        debugPrint("Control released successfully")
    }
    
    // ENHANCED: Deny control request (clear timestamp)
    func denyControlRequest(for liveGame: LiveGame) async throws {
        guard let _ = liveGame.id else {
            throw DeviceControlError.invalidRequest
        }
        
        var updatedGame = liveGame
        updatedGame.controlRequestedBy = nil
        updatedGame.controlRequestingDeviceId = nil
        updatedGame.controlRequestTimestamp = nil // CLEAR: Remove timestamp when denying
        
        try await firebaseService.updateLiveGame(updatedGame)
        debugPrint("Control request denied")
    }
    
    // ENHANCED: Update control status with timeout handling
    func updateControlStatus(for liveGame: LiveGame, userEmail: String?) {
        let deviceHasControl = (liveGame.controllingDeviceId == deviceId)
        let userHasControl = (liveGame.controllingUserEmail == userEmail)
        let newHasControl = deviceHasControl && userHasControl
        
        debugPrint("--- Updating Control Status (DETAILED) ---")
        debugPrint("Device ID: \(deviceId)")
        debugPrint("Server Controlling Device ID: \(liveGame.controllingDeviceId ?? "None")")
        debugPrint("Device Has Control: \(deviceHasControl)")
        debugPrint("Server Controlling User Email: \(liveGame.controllingUserEmail ?? "None")")
        debugPrint("Current User Email: \(userEmail ?? "None")")
        debugPrint("User Has Control: \(userHasControl)")
        debugPrint("Combined Control Status: \(newHasControl)")
        debugPrint("Previous Has Control: \(hasControl)")
        debugPrint("Control Requested By: \(liveGame.controlRequestedBy ?? "None")")
        debugPrint("Control Requesting Device: \(liveGame.controlRequestingDeviceId ?? "None")")
        
        // CHECK FOR TIMEOUT: If request is older than 2 minutes, treat as expired
        var hasActiveRequest = false
        if let requestTimestamp = liveGame.controlRequestTimestamp {
            let timeElapsed = Date().timeIntervalSince(requestTimestamp)
            hasActiveRequest = timeElapsed <= 120 // 2 minutes = 120 seconds
            
            if !hasActiveRequest {
                debugPrint("⏰ Control request has expired (elapsed: \(Int(timeElapsed))s)")
            } else {
                debugPrint("⏱️ Control request active (elapsed: \(Int(timeElapsed))s, remaining: \(Int(120 - timeElapsed))s)")
            }
        }
        
        // Force update even if the value appears the same (to trigger UI refresh)
        let previousHasControl = hasControl
        hasControl = newHasControl
        controllingUser = liveGame.controllingUserEmail
        
        // IMPROVED: Can request control logic with timeout consideration
        let differentDeviceHasControl = (liveGame.controllingDeviceId != nil && liveGame.controllingDeviceId != deviceId)
        let thisPendingRequest = (liveGame.controlRequestingDeviceId == deviceId && hasActiveRequest)
        
        canRequestControl = (liveGame.controllingDeviceId == nil) ||
                           (differentDeviceHasControl && !thisPendingRequest)
        
        // Track pending control requests for this specific device (only if not expired)
        if liveGame.controlRequestingDeviceId == deviceId && liveGame.controlRequestedBy != nil && hasActiveRequest {
            pendingControlRequest = liveGame.controlRequestedBy
        } else {
            pendingControlRequest = nil
        }
        
        debugPrint("Different Device Has Control: \(differentDeviceHasControl)")
        debugPrint("This Device Pending Request: \(thisPendingRequest)")
        debugPrint("Can Request Control: \(canRequestControl)")
        debugPrint("Pending Control Request: \(pendingControlRequest ?? "None")")
        
        // If control status changed, force a UI update
        if previousHasControl != newHasControl {
            debugPrint("🔄 CONTROL STATUS CHANGED: \(previousHasControl) -> \(newHasControl)")
            DispatchQueue.main.async {
                // Force UI refresh by triggering objectWillChange
                self.objectWillChange.send()
            }
        }
    }
}

enum DeviceControlError: LocalizedError {
    case invalidRequest
    case noPermission
    case deviceNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Invalid control request"
        case .noPermission:
            return "No permission to control game"
        case .deviceNotFound:
            return "Device not found"
        }
    }
}
