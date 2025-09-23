//
//  MediaIntegration.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/23/25.
//
// File: SahilStats/Views/MediaIntegration.swift

import SwiftUI
import AVFoundation
import FirebaseAuth

// MARK: - Enhanced Game Detail View with Media

struct MediaIntegrationView: View {
    let game: Game
    @StateObject private var recordingManager = VideoRecordingManager.shared
    @State private var showingVideoRecording = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Game Media")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                
                Spacer()
                
                // Only video recording option
                if FirebaseService.shared.hasLiveGame {
                    Button("Record Video") {
                        showingVideoRecording = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            // Share game summary (text only)
            Button(action: shareGameText) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                    Text("Share Game Summary")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(12)
        .fullScreenCover(isPresented: $showingVideoRecording) {
            VideoRecordingView(liveGame: FirebaseService.shared.getCurrentLiveGame())
        }
    }
    
    private func shareGameText() {
        let text = """
        🏀 \(game.teamName) vs \(game.opponent)
        Final: \(game.myTeamScore) - \(game.opponentScore)
        
        Sahil's Stats:
        📊 \(game.points) PTS • \(game.rebounds) REB • \(game.assists) AST
        
        #SahilStats
        """
        
        let activityViewController = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
    }
}

struct EnhancedGameDetailView: View {
    @State var game: Game
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebaseService = FirebaseService.shared
    
    // State for media features
    @State private var showingCameraCapture = false
    @State private var showingVideoRecording = false
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Existing header
                    headerView
                    
                    // NEW: Media Section
                    mediaSection
                    
                    // Existing player stats
                    playerStatsSection
                    
                    // Existing shooting percentages
                    shootingPercentagesSection
                }
                .padding()
            }
            .navigationTitle("Game Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingCameraCapture) {
            CameraCapture(gameId: game.id ?? "") { image in
                Task {
                    if let gameId = game.id {
                        await saveGameScreenshot(image, gameId: gameId)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingVideoRecording) {
            VideoRecordingView(liveGame: FirebaseService.shared.getCurrentLiveGame())
        }
    }
    
    // MARK: - Media Section
    
    @ViewBuilder
    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Game Media")
                    .font(isIPad ? .title2 : .headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                
                Spacer()
                
                Menu {
                    if FirebaseService.shared.hasLiveGame {
                        Button(action: { showingVideoRecording = true }) {
                            Label("Record Video", systemImage: "video.fill")
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                }
            }
            
            // Quick action buttons
            mediaActionButtons
        }
        .padding(isIPad ? 20 : 16)
        .background(Color.orange.opacity(0.05))
        .cornerRadius(isIPad ? 16 : 12)
    }
    
    @ViewBuilder
    private var mediaActionButtons: some View {
        HStack(spacing: 12) {
            // Screenshot current stats
            Button(action: {
                takeStatsScreenshot()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "camera.viewfinder")
                        .font(.caption)
                    Text("Screenshot Stats")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Share game summary
            Button(action: {
                shareGameSummary()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                    Text("Share")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Existing Views
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(game.teamName) vs \(game.opponent)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                if game.outcome == .win {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow)
                        .font(.title)
                }
            }
            
            HStack {
                Text("Final Score: \(game.myTeamScore) - \(game.opponentScore)")
                    .font(.title2)
                    .foregroundColor(game.outcome.color == "green" ? .green : .red)
            }
            
            HStack {
                Text(game.formattedDate)
                if let location = game.location, !location.isEmpty {
                    Text("• \(location)")
                }
            }
            .foregroundColor(.secondary)
        }
    }
    
    private var playerStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Player Stats")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                DetailStatCard(title: "Points", value: "\(game.points)", color: .purple)
                DetailStatCard(title: "Rebounds", value: "\(game.rebounds)", color: .mint)
                DetailStatCard(title: "Assists", value: "\(game.assists)", color: .cyan)
                DetailStatCard(title: "Steals", value: "\(game.steals)", color: .yellow)
                DetailStatCard(title: "Blocks", value: "\(game.blocks)", color: .red)
                DetailStatCard(title: "Fouls", value: "\(game.fouls)", color: .pink)
            }
        }
    }
    
    private var shootingPercentagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shooting Percentages")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ShootingPercentageCard(
                    title: "Field Goal",
                    percentage: String(format: "%.0f%%", game.fieldGoalPercentage * 100),
                    fraction: "\(game.fg2m + game.fg3m)/\(game.fg2a + game.fg3a)",
                    color: .blue
                )
                ShootingPercentageCard(
                    title: "Three Point",
                    percentage: String(format: "%.0f%%", game.threePointPercentage * 100),
                    fraction: "\(game.fg3m)/\(game.fg3a)",
                    color: .green
                )
            }
        }
    }
    
    // MARK: - Media Actions
    
    private func takeStatsScreenshot() {
        let renderer = ImageRenderer(content: statsScreenshotView)
        renderer.scale = UIScreen.main.scale
        
        if let image = renderer.uiImage {
            Task {
                if let gameId = game.id {
                    await saveGameScreenshot(image, gameId: gameId)
                }
            }
        }
    }
    
    @ViewBuilder
    private var statsScreenshotView: some View {
        VStack(spacing: 20) {
            // Game header
            VStack(spacing: 8) {
                Text("\(game.teamName) vs \(game.opponent)")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Final: \(game.myTeamScore) - \(game.opponentScore)")
                    .font(.title2)
                    .foregroundColor(game.outcome == .win ? .green : .red)
                
                Text(game.formattedDate)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Stats grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                DetailStatCard(title: "PTS", value: "\(game.points)", color: .purple)
                DetailStatCard(title: "REB", value: "\(game.rebounds)", color: .mint)
                DetailStatCard(title: "AST", value: "\(game.assists)", color: .cyan)
                DetailStatCard(title: "STL", value: "\(game.steals)", color: .yellow)
                DetailStatCard(title: "BLK", value: "\(game.blocks)", color: .red)
                DetailStatCard(title: "FG%", value: String(format: "%.0f%%", game.fieldGoalPercentage * 100), color: .blue)
            }
            
            // Watermark
            HStack {
                Spacer()
                Text("SahilStats")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .opacity(0.7)
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
    }
    
    private func shareGameSummary() {
        let text = """
        🏀 \(game.teamName) vs \(game.opponent)
        Final: \(game.myTeamScore) - \(game.opponentScore)
        
        Sahil's Stats:
        📊 \(game.points) PTS • \(game.rebounds) REB • \(game.assists) AST
        🎯 FG: \(String(format: "%.0f%%", game.fieldGoalPercentage * 100))
        
        #SahilStats #Basketball
        """
        
        let activityViewController = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
    }
    
    private func saveGameScreenshot(_ image: UIImage, gameId: String) async {
        // Implementation for saving screenshots
        // You can implement Firebase storage or local storage here
        print("Screenshot saved for game: \(gameId)")
    }
}

// MARK: - Camera Capture View

struct CameraCapture: UIViewControllerRepresentable {
    let gameId: String
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraDevice = .rear
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCapture
        
        init(_ parent: CameraCapture) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Enhanced Live Game View with Recording

struct EnhancedLiveGameView: View {
    let liveGame: LiveGame
    @StateObject private var recordingManager = VideoRecordingManager.shared
    @State private var showingVideoRecording = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Enhanced live game header with recording button
            enhancedLiveGameHeader()
            
            // Existing live game content
            ScrollView {
                VStack(spacing: 20) {
                    existingLiveGameContent()
                }
                .padding()
            }
        }
        .fullScreenCover(isPresented: $showingVideoRecording) {
            VideoRecordingView(liveGame: liveGame)
        }
    }
    
    @ViewBuilder
    private func enhancedLiveGameHeader() -> some View {
        VStack(spacing: 16) {
            // Existing header content
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .opacity(0.8)
                        .animation(.easeInOut(duration: 1).repeatForever(), value: true)
                    
                    Text("LIVE GAME")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                // Recording controls
                HStack(spacing: 12) {
                    // Screenshot button
                    Button(action: takeScreenshot) {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.caption)
                            Text("Screenshot")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    
                    // Video recording button
                    VideoRecordingButton(liveGame: liveGame)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
        )
    }
    
    @ViewBuilder
    private func existingLiveGameContent() -> some View {
        VStack(spacing: 20) {
            Text("Live Game Content")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Score: \(liveGame.homeScore) - \(liveGame.awayScore)")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Period \(liveGame.period)")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    private func takeScreenshot() {
        let renderer = ImageRenderer(content: liveGameScreenshotView)
        renderer.scale = UIScreen.main.scale
        
        if let image = renderer.uiImage {
            // Handle the screenshot image
            shareScreenshot(image)
        }
    }
    
    private func shareScreenshot(_ image: UIImage) {
        let activityViewController = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
    }
    
    @ViewBuilder
    private var liveGameScreenshotView: some View {
        VStack(spacing: 20) {
            // Live game header for screenshot
            VStack(spacing: 12) {
                HStack {
                    Text("🔴 LIVE")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    Spacer()
                    Text(Date().formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("\(liveGame.teamName) vs \(liveGame.opponent)")
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            // Score display
            HStack(spacing: 40) {
                VStack {
                    Text(liveGame.teamName)
                        .font(.headline)
                        .foregroundColor(.blue)
                    Text("\(liveGame.homeScore)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.blue)
                }
                
                Text("-")
                    .font(.title)
                    .foregroundColor(.secondary)
                
                VStack {
                    Text(liveGame.opponent)
                        .font(.headline)
                        .foregroundColor(.red)
                    Text("\(liveGame.awayScore)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.red)
                }
            }
            
            // Game info
            VStack(spacing: 8) {
                Text("Period \(liveGame.period)")
                    .font(.headline)
                Text(liveGame.currentClockDisplay)
                    .font(.title2)
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
            
            // Player stats if available
            if liveGame.playerStats.points > 0 || liveGame.playerStats.rebounds > 0 {
                VStack(spacing: 12) {
                    Text("Sahil's Stats")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    HStack(spacing: 20) {
                        StatItem(title: "PTS", value: liveGame.playerStats.points, color: .purple)
                        StatItem(title: "REB", value: liveGame.playerStats.rebounds, color: .mint)
                        StatItem(title: "AST", value: liveGame.playerStats.assists, color: .cyan)
                    }
                }
            }
            
            // Watermark
            HStack {
                Spacer()
                Text("SahilStats • Live Game")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .opacity(0.7)
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
    }
}

// MARK: - Stat Item for Screenshots

struct StatItem: View {
    let title: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Enhanced Game Setup with Media Options

struct EnhancedGameSetupView: View {
    // Your existing GameSetupView properties
    @State private var showingMediaOptions = false
    @State private var enableVideoRecording = false
    @State private var enableAutoScreenshots = false
    @StateObject private var authService = AuthService.shared
    
    var body: some View {
        VStack {
            // Existing setup content would go here
            Text("Game Setup Content")
                .font(.title2)
            
            // Media Options Section
            if authService.showAdminFeatures {
                mediaOptionsSection
            }
        }
    }
    
    @ViewBuilder
    private var mediaOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Media Features")
                .font(.headline)
                .fontWeight(.bold)
            
            Text("Capture and share your game moments")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Video recording toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Video Recording")
                        .font(.headline)
                    Text("Record live game with score overlay")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: $enableVideoRecording)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Auto screenshots toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Auto Screenshots")
                        .font(.headline)
                    Text("Automatically capture key moments")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: $enableAutoScreenshots)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Media access status
            MediaAccessStatus()
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Media Access Status

struct MediaAccessStatus: View {
    @StateObject private var recordingManager = VideoRecordingManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permissions")
                .font(.headline)
                        
            // Camera access status
            HStack {
                Image(systemName: recordingManager.canRecordVideo ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(recordingManager.canRecordVideo ? .green : .orange)
                
                Text("Camera & Microphone")
                    .font(.subheadline)
                
                Spacer()
                
                if !recordingManager.canRecordVideo {
                    Button("Enable") {
                        if recordingManager.shouldShowSettingsAlert {
                            recordingManager.openCameraSettings()
                        } else {
                            Task {
                                await recordingManager.requestCameraAccess()
                            }
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .onAppear {
            recordingManager.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }
}
