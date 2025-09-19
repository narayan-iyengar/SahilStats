//
//  DeviceControlManager.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/19/25.
//
// MARK: - Device Control Manager
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
    
    func requestControl(for liveGame: LiveGame, userEmail: String?) async throws -> Bool {
        guard let gameId = liveGame.id,
              let email = userEmail else {
            throw DeviceControlError.invalidRequest
        }
        
        var updatedGame = liveGame
        updatedGame.controlRequestedBy = email
        
        try await firebaseService.updateLiveGame(updatedGame)
        return true
    }
    
    func grantControl(for liveGame: LiveGame, to userEmail: String) async throws {
        guard let gameId = liveGame.id else {
            throw DeviceControlError.invalidRequest
        }
        
        var updatedGame = liveGame
        updatedGame.controllingDeviceId = deviceId
        updatedGame.controllingUserEmail = userEmail
        updatedGame.controlRequestedBy = nil
        
        try await firebaseService.updateLiveGame(updatedGame)
    }
    
    func releaseControl(for liveGame: LiveGame) async throws {
        guard let gameId = liveGame.id else {
            throw DeviceControlError.invalidRequest
        }
        
        var updatedGame = liveGame
        updatedGame.controllingDeviceId = nil
        updatedGame.controllingUserEmail = nil
        updatedGame.controlRequestedBy = nil
        
        try await firebaseService.updateLiveGame(updatedGame)
    }
    
    func updateControlStatus(for liveGame: LiveGame, userEmail: String?) {
        let newHasControl = (liveGame.controllingDeviceId == deviceId &&
                     liveGame.controllingUserEmail == userEmail)
        print("--- Updating Control Status ---")
        print("Device ID: \(deviceId)")
        print("Server Controlling Device ID: \(liveGame.controllingDeviceId ?? "None")")
        print("Control Granted: \(newHasControl)")
        
        hasControl = newHasControl
        controllingUser = liveGame.controllingUserEmail
        canRequestControl = liveGame.controllingDeviceId == nil
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
