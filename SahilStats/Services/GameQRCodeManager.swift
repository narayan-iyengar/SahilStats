//
//  GameQRCodeManager.swift
//  SahilStats
//
//  QR code generation and scanning for easy game joining
//

import Foundation
import SwiftUI
import CoreImage.CIFilterBuiltins

class GameQRCodeManager {
    static let shared = GameQRCodeManager()

    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    // MARK: - QR Code Data Model

    struct GameQRData: Codable {
        let gameId: String
        let teamName: String
        let opponent: String
        let location: String
        let quarterLength: Int
        let gameFormat: String // "quarters" or "halves"
        let timestamp: TimeInterval

        init(liveGame: LiveGame) {
            self.gameId = liveGame.id ?? UUID().uuidString
            self.teamName = liveGame.teamName
            self.opponent = liveGame.opponent
            self.location = liveGame.location ?? "Unknown Location"
            self.quarterLength = liveGame.quarterLength
            self.gameFormat = liveGame.gameFormat.rawValue
            self.timestamp = Date().timeIntervalSince1970
        }

        func toLiveGame() -> LiveGame? {
            guard let format = GameFormat(rawValue: gameFormat) else {
                return nil
            }

            var game = LiveGame(
                teamName: teamName,
                opponent: opponent,
                location: location,
                gameFormat: format,
                quarterLength: quarterLength,
                isMultiDeviceSetup: true
            )
            game.id = gameId  // Set the game ID from QR data
            return game
        }
    }

    private init() {}

    // MARK: - QR Code Generation

    func generateQRCode(for liveGame: LiveGame) -> UIImage? {
        let qrData = GameQRData(liveGame: liveGame)

        guard let jsonData = try? JSONEncoder().encode(qrData) else {
            forcePrint("❌ Failed to encode game data to JSON")
            return nil
        }

        let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
        debugPrint("📱 Generating QR code with data:")
        debugPrint("   Game ID: \(qrData.gameId)")
        debugPrint("   Opponent: \(qrData.opponent)")
        debugPrint("   JSON length: \(jsonString.count) characters")

        filter.message = jsonData

        guard let outputImage = filter.outputImage else {
            forcePrint("❌ Failed to generate QR code image")
            return nil
        }

        // Scale up the QR code for better quality
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            forcePrint("❌ Failed to create CGImage from QR code")
            return nil
        }

        let uiImage = UIImage(cgImage: cgImage)
        debugPrint("✅ QR code generated successfully")
        return uiImage
    }

    // MARK: - QR Code Parsing

    func parseQRCode(from string: String) -> GameQRData? {
        guard let jsonData = string.data(using: .utf8) else {
            forcePrint("❌ Failed to convert QR string to data")
            return nil
        }

        do {
            let qrData = try JSONDecoder().decode(GameQRData.self, from: jsonData)
            debugPrint("✅ Successfully parsed QR code:")
            debugPrint("   Game ID: \(qrData.gameId)")
            debugPrint("   Opponent: \(qrData.opponent)")
            return qrData
        } catch {
            forcePrint("❌ Failed to decode QR data: \(error)")
            return nil
        }
    }

    // MARK: - Validation

    func isValidGameQRCode(_ string: String) -> Bool {
        return parseQRCode(from: string) != nil
    }

    func getGameDetails(from qrString: String) -> (opponent: String, location: String)? {
        guard let qrData = parseQRCode(from: qrString) else {
            return nil
        }
        return (qrData.opponent, qrData.location)
    }
}

// MARK: - SwiftUI QR Code View

struct QRCodeView: View {
    let liveGame: LiveGame
    @State private var qrImage: UIImage?

    var body: some View {
        VStack(spacing: 20) {
            if let image = qrImage {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 250, height: 250)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 5)
            } else {
                ProgressView()
                    .frame(width: 250, height: 250)
            }

            VStack(spacing: 8) {
                Text("Scan to Join Game")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("\(liveGame.teamName) vs \(liveGame.opponent)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .onAppear {
            generateQRCode()
        }
    }

    private func generateQRCode() {
        DispatchQueue.global(qos: .userInitiated).async {
            let image = GameQRCodeManager.shared.generateQRCode(for: liveGame)
            DispatchQueue.main.async {
                self.qrImage = image
            }
        }
    }
}

// MARK: - Full-Screen QR Code Display

struct GameQRCodeDisplayView: View {
    let liveGame: LiveGame
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var navigation = NavigationCoordinator.shared
    @ObservedObject private var roleManager = DeviceRoleManager.shared
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var hasAutoNavigated = false

    private var isIPad: Bool { horizontalSizeClass == .regular }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                HStack {
                    Spacer()
                    Button("Cancel") {
                        // Cancel the game and return to dashboard
                        Task {
                            if let gameId = liveGame.id {
                                try? await FirebaseService.shared.deleteLiveGame(gameId)
                            }
                        }
                        dismiss()
                    }
                    .font(.headline)
                    .padding()
                }

                Spacer()

                VStack(spacing: 24) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("Scan to Connect")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Open SahilStats on the camera phone\nand scan this QR code")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    if let image = generateQRCodeSync() {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: isIPad ? 600 : 400, height: isIPad ? 600 : 400)
                            .padding(20)
                            .background(Color.white)
                            .cornerRadius(24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.orange, lineWidth: 4)
                            )
                            .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)
                    } else {
                        ProgressView()
                            .frame(width: isIPad ? 600 : 400, height: isIPad ? 600 : 400)
                    }

                    VStack(spacing: 8) {
                        Text("\(liveGame.teamName) vs \(liveGame.opponent)")
                            .font(.title3)
                            .fontWeight(.semibold)
                        if let location = liveGame.location {
                            Text(location)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 8)
                }

                Spacer()

                // Status message
                Text("Waiting for camera phone to scan...")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            // Controller has committed to the game flow by showing QR code
            // Set controller role immediately and allow auto-navigation when recorder joins
            navigation.markUserHasInteracted()
            navigation.userExplicitlyJoinedGame = true
            debugPrint("📱 Controller showing QR code - setting role and enabling auto-navigation")

            // Set controller role immediately
            if let gameId = liveGame.id {
                Task {
                    do {
                        try await roleManager.setDeviceRole(.controller, for: gameId)
                        debugPrint("✅ Controller role set for game: \(gameId)")
                    } catch {
                        forcePrint("❌ Failed to set controller role: \(error)")
                    }
                }
            }
        }
        .onChange(of: roleManager.connectedDevices) {
            // Auto-navigate when recorder joins
            guard !hasAutoNavigated else { return }

            // Check if a recorder has joined
            let recorderJoined = roleManager.connectedDevices.contains { device in
                device.role == .recorder
            }

            if recorderJoined {
                debugPrint("📱 QR Code: Recorder joined! Auto-navigating to live game...")
                hasAutoNavigated = true

                // Navigate to live game
                navigation.currentFlow = .liveGame(liveGame)
                dismiss()
            }
        }
    }

    private func generateQRCodeSync() -> UIImage? {
        GameQRCodeManager.shared.generateQRCode(for: liveGame)
    }
}
