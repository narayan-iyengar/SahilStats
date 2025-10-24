//
//  EnhancedGameDetailView.swift.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/24/25.
//

// File: SahilStats/Views/EnhancedGameDetailView.swift
// Complete Game Detail View with all stats using existing components

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct CompleteGameDetailView: View {
    @State var game: Game
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebaseService = FirebaseService.shared
    @EnvironmentObject var authService: AuthService

    // State for editing individual stats
    @State private var isEditingStat = false
    @State private var editingStatTitle = ""
    @State private var editingStatValue = ""
    @State private var statUpdateBinding: Binding<Int>?

    // State for editing score
    @State private var isEditingScore = false
    @State private var editingMyTeamScore = ""
    @State private var editingOpponentScore = ""

    // State for editing team names
    @State private var isEditingTeamNames = false
    @State private var editingTeamName = ""
    @State private var editingOpponentName = ""

    // State for media features
    @State private var showingShareSheet = false
    @State private var showingVideoPlayer = false
    @State private var videoURLToPlay: URL?
    @State private var photosAssetIdToPlay: String?

    // State for NAS upload
    @State private var isUploadingToNAS = false
    @State private var nasUploadSuccess = false
    @State private var nasUploadError: String?

    // State for real-time updates
    @State private var gameListener: ListenerRegistration?

    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: isIPad ? 32 : 24) {
                    // Header with game info
                    gameHeaderSection
                        .onAppear {
                            debugPrint("🎮 Game Details Loaded:")
                            debugPrint("   Game ID: \(game.id ?? "nil")")
                            debugPrint("   Title: \(game.teamName) vs \(game.opponent)")
                            debugPrint("   Date: \(game.formattedDate)")
                            debugPrint("   YouTube ID: \(game.youtubeVideoId ?? "nil")")
                            debugPrint("   Video URL: \(game.videoURL ?? "nil")")
                        }
                    
                    // Player Stats Section (comprehensive)
                    playerStatsSection
                    
                    // Playing Time Section (if available)
                    //if game.totalPlayingTimeMinutes > 0 || game.benchTimeMinutes > 0 {
                    playingTimeSection
                    //}
                    
                    // Shooting Percentages Section
                    shootingPercentagesSection
                    
                    // Advanced Analytics Section
                    advancedAnalyticsSection
                    
                    // Achievements Section
                    if !game.achievements.isEmpty {
                        achievementsSection
                    }

                    // Game Video Section (show if we have ANY video - Photos, YouTube, or local)
                    if game.photosAssetId != nil || game.youtubeVideoId != nil || game.videoURL != nil {
                        gameVideoSection
                            .onAppear {
                                debugPrint("📹 Video section appeared:")
                                debugPrint("   Photos Asset ID: \(game.photosAssetId ?? "nil")")
                                debugPrint("   YouTube ID: \(game.youtubeVideoId ?? "nil")")
                                debugPrint("   Video URL: \(game.videoURL ?? "nil")")
                            }
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding(isIPad ? 24 : 16)
            }
            .navigationTitle("Game Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.body)
                                .fontWeight(.semibold)
                            Text("Back")
                        }
                    }
                }
            }
        }
        .alert("Edit \(editingStatTitle)", isPresented: $isEditingStat) {
            TextField("New Value", text: $editingStatValue)
                .keyboardType(.numberPad)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                saveStatChange()
            }
        }
        .alert("Edit Final Score", isPresented: $isEditingScore) {
            TextField("My Team Score", text: $editingMyTeamScore)
                .keyboardType(.numberPad)
            TextField("Opponent Score", text: $editingOpponentScore)
                .keyboardType(.numberPad)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                saveScoreChange()
            }
        }
        .alert("Edit Team Names", isPresented: $isEditingTeamNames) {
            TextField("Your Team", text: $editingTeamName)
            TextField("Opponent Team", text: $editingOpponentName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                saveTeamNameChange()
            }
        }
        .sheet(isPresented: $showingVideoPlayer) {
            if let photosAssetId = photosAssetIdToPlay {
                PhotosVideoPlayerView(photosAssetId: photosAssetId)
            } else if let videoURL = videoURLToPlay {
                PhotosVideoPlayerView(videoURL: videoURL)
            }
        }
        .onAppear {
            setupGameListener()
        }
        .onDisappear {
            gameListener?.remove()
        }
    }
    
    // MARK: - Header Section
    
    @ViewBuilder
    private var gameHeaderSection: some View {
        VStack(alignment: .leading, spacing: isIPad ? 16 : 12) {
            // Game matchup and outcome
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    // Team names with edit capability
                    Button(action: {
                        if authService.canEditGames {
                            editingTeamName = game.teamName
                            editingOpponentName = game.opponent
                            isEditingTeamNames = true
                        }
                    }) {
                        HStack {
                            Text("\(game.teamName) vs \(game.opponent)")
                                .font(isIPad ? .largeTitle : .title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            if authService.canEditGames {
                                Image(systemName: "pencil.circle")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!authService.canEditGames)
                    
                    Text(game.formattedDate)
                        .font(isIPad ? .body : .subheadline)
                        .foregroundColor(.secondary)
                    
                    if let location = game.location, !location.isEmpty {
                        Label(location, systemImage: "location")
                            .font(isIPad ? .body : .subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Outcome indicator
                if game.outcome == .win {
                    VStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .font(isIPad ? .largeTitle : .title)
                            .foregroundColor(.yellow)
                        Text("WIN")
                            .font(isIPad ? .body : .caption)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
            }
            
            // Score display with edit capability
            Button(action: {
                if authService.canEditGames {
                    editingMyTeamScore = "\(game.myTeamScore)"
                    editingOpponentScore = "\(game.opponentScore)"
                    isEditingScore = true
                }
            }) {
                HStack {
                    Text("Final Score: \(game.myTeamScore) - \(game.opponentScore)")
                        .font(isIPad ? .title : .title2)
                        .fontWeight(.bold)
                        .foregroundColor(game.outcome == .win ? .green : (game.outcome == .loss ? .red : .orange))
                    
                    if authService.canEditGames {
                        Image(systemName: "pencil.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!authService.canEditGames)
        }
        .padding(isIPad ? 24 : 20)
        .background(Color(.systemGray6))
        .cornerRadius(isIPad ? 20 : 16)
    }
    
    
    // MARK: - Player Stats Section (Comprehensive)
    
    @ViewBuilder
    private var playerStatsSection: some View {
        PlayerStatsSection(
            game: $game,
            authService: authService,
            firebaseService: firebaseService,
            isIPad: isIPad
        )
    }

    // Add this new helper function that shows stats to everyone but only allows editing for admins:
    private func viewableStatCard(title: String, value: Int, color: Color) -> some View {
        Group {
            if authService.canEditGames {
                // For admins: editable card with long press
                DetailStatCard(title: title, value: "\(value)", color: color)
                    .onLongPressGesture {
                        // Your existing edit logic here
                        editingStatTitle = title
                        editingStatValue = "\(value)"
                        // Note: You'd need to convert this to work with individual stat fields
                        // since editableStatCard used bindings
                        isEditingStat = true
                    }
            } else {
                // For regular users: read-only card
                DetailStatCard(title: title, value: "\(value)", color: color)
            }
        }
    }
    
    // MARK: - Playing Time Section
    
    @ViewBuilder
    private var playingTimeSection: some View {
        VStack(alignment: .leading, spacing: isIPad ? 20 : 16) {
            Text("Playing Time")
                .font(isIPad ? .title2 : .headline)
                .fontWeight(.bold)
                .foregroundColor(.teal)
            
            // Time cards in a 2x2 + 1 layout
            VStack(spacing: isIPad ? 16 : 12) {
                // First row - actual times
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: isIPad ? 16 : 12) {
                    GameDetailTimeCard(
                        title: "Minutes Played",
                        time: game.totalPlayingTimeMinutes,
                        color: .green,
                        isIPad: isIPad
                    )
                    GameDetailTimeCard(
                        title: "Bench Time",
                        time: game.calculatedBenchTime,
                        color: .orange,
                        isIPad: isIPad
                    )
                }
                
                // Second row - calculated stats
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: isIPad ? 16 : 12) {
                    DetailStatCard(
                        title: "Total Game Time",
                        value: "\(Int(game.totalGameTimeMinutes))m",
                        color: .gray
                    )
                    DetailStatCard(
                        title: "Court Time %",
                        value: "\(Int(game.playingTimePercentage))%",
                        color: .teal
                    )
                    DetailStatCard(
                        title: "Points/Min",
                        value: String(format: "%.1f", calculatePointsPerMinute()),
                        color: .red
                    )
                }
            }
        }
    }
    
    // MARK: - Shooting Percentages Section
    
    @ViewBuilder
    private var shootingPercentagesSection: some View {
        VStack(alignment: .leading, spacing: isIPad ? 20 : 16) {
            Text("Shooting Percentages")
                .font(isIPad ? .title2 : .headline)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: isIPad ? 16 : 12) {
                ShootingPercentageCard(
                    title: "Field Goal",
                    percentage: String(format: "%.0f%%", game.fieldGoalPercentage * 100),
                    fraction: "\(game.fg2m + game.fg3m)/\(game.fg2a + game.fg3a)",
                    color: .blue
                )
                ShootingPercentageCard(
                    title: "Two Point",
                    percentage: String(format: "%.0f%%", game.twoPointPercentage * 100),
                    fraction: "\(game.fg2m)/\(game.fg2a)",
                    color: .blue
                )
                ShootingPercentageCard(
                    title: "Three Point",
                    percentage: String(format: "%.0f%%", game.threePointPercentage * 100),
                    fraction: "\(game.fg3m)/\(game.fg3a)",
                    color: .green
                )
                ShootingPercentageCard(
                    title: "Free Throw",
                    percentage: String(format: "%.0f%%", game.freeThrowPercentage * 100),
                    fraction: "\(game.ftm)/\(game.fta)",
                    color: .orange
                )
            }
        }
    }
    
    // MARK: - Advanced Analytics Section
    
    @ViewBuilder
    private var advancedAnalyticsSection: some View {
        VStack(alignment: .leading, spacing: isIPad ? 20 : 16) {
            Text("Advanced Analytics")
                .font(isIPad ? .title2 : .headline)
                .fontWeight(.bold)
                .foregroundColor(.purple)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: isIPad ? 16 : 12) {
                DetailStatCard(
                    title: "Game Score",
                    value: String(format: "%.1f", calculateGameScore()),
                    color: .purple
                )
                DetailStatCard(
                    title: "Usage Rate",
                    value: String(format: "%.1f%%", calculateUsageRate()),
                    color: .indigo
                )
                DetailStatCard(
                    title: "Efficiency",
                    value: String(format: "%.1f", calculateEfficiency()),
                    color: .mint
                )
                DetailStatCard(
                    title: "Impact Score",
                    value: String(format: "%.1f", calculateImpactScore()),
                    color: .cyan
                )
            }
        }
    }
    
    // MARK: - Game Video Section

    @ViewBuilder
    private var gameVideoSection: some View {
        VStack(alignment: .leading, spacing: isIPad ? 20 : 16) {
            Text("Game Video")
                .font(isIPad ? .title2 : .headline)
                .fontWeight(.bold)
                .foregroundColor(.red)

            if let photosAssetId = game.photosAssetId {
                // Photos library video available (primary source)
                Button(action: {
                    playPhotosVideo(assetId: photosAssetId)
                }) {
                    HStack(spacing: isIPad ? 16 : 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: isIPad ? 12 : 10)
                                .fill(Color.purple)
                                .frame(width: isIPad ? 64 : 56, height: isIPad ? 64 : 56)

                            Image(systemName: "play.circle.fill")
                                .font(isIPad ? .title : .title2)
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Watch Game Recording")
                                .font(isIPad ? .title3 : .body)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Text("Tap to play from Photos library")
                                .font(isIPad ? .body : .caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right.circle.fill")
                            .font(isIPad ? .title2 : .title3)
                            .foregroundColor(.purple)
                    }
                    .padding(isIPad ? 20 : 16)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(isIPad ? 16 : 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: isIPad ? 16 : 12)
                            .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)

                // Show YouTube link if also available
                if let videoId = game.youtubeVideoId {
                    Link(destination: URL(string: "https://www.youtube.com/watch?v=\(videoId)")!) {
                        HStack(spacing: isIPad ? 12 : 10) {
                            Image(systemName: "play.rectangle.fill")
                                .foregroundColor(.red)
                            Text("Also available on YouTube")
                                .font(isIPad ? .body : .caption)
                                .foregroundColor(.secondary)
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(isIPad ? 12 : 10)
                        .background(Color.red.opacity(0.05))
                        .cornerRadius(isIPad ? 10 : 8)
                    }
                }
            } else if let videoId = game.youtubeVideoId {
                // YouTube video is available (fallback)
                Link(destination: URL(string: "https://www.youtube.com/watch?v=\(videoId)")!) {
                    HStack(spacing: isIPad ? 16 : 12) {
                        // YouTube play icon
                        ZStack {
                            RoundedRectangle(cornerRadius: isIPad ? 12 : 10)
                                .fill(Color.red)
                                .frame(width: isIPad ? 64 : 56, height: isIPad ? 64 : 56)

                            Image(systemName: "play.fill")
                                .font(isIPad ? .title : .title2)
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Watch on YouTube")
                                .font(isIPad ? .title3 : .body)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Text("Full game uploaded and ready")
                                .font(isIPad ? .body : .caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right.circle.fill")
                            .font(isIPad ? .title2 : .title3)
                            .foregroundColor(.red)
                    }
                    .padding(isIPad ? 20 : 16)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(isIPad ? 16 : 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: isIPad ? 16 : 12)
                            .stroke(Color.red.opacity(0.3), lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            } else if let videoURLPath = game.videoURL {
                // Try to find the local video (handle both full path and filename)
                let actualPath = resolveVideoPath(videoURLPath)
                if let path = actualPath, FileManager.default.fileExists(atPath: path) {
                    // Local video available
                    Button(action: {
                        playLocalVideo(path: path)
                }) {
                    HStack(spacing: isIPad ? 16 : 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: isIPad ? 12 : 10)
                                .fill(Color.blue)
                                .frame(width: isIPad ? 64 : 56, height: isIPad ? 64 : 56)

                            Image(systemName: "play.circle.fill")
                                .font(isIPad ? .title : .title2)
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Watch Local Recording")
                                .font(isIPad ? .title3 : .body)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Text("Tap to play • Uploading to YouTube...")
                                .font(isIPad ? .body : .caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right.circle.fill")
                            .font(isIPad ? .title2 : .title3)
                            .foregroundColor(.blue)
                    }
                    .padding(isIPad ? 20 : 16)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(isIPad ? 16 : 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: isIPad ? 16 : 12)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                } else {
                    // Video URL exists but file not found
                    HStack(spacing: isIPad ? 16 : 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: isIPad ? 12 : 10)
                                .fill(Color.orange)
                                .frame(width: isIPad ? 64 : 56, height: isIPad ? 64 : 56)

                            ProgressView()
                                .tint(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Video Uploading")
                                .font(isIPad ? .title3 : .body)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Text("Check back soon for the full game video")
                                .font(isIPad ? .body : .caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(isIPad ? 20 : 16)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(isIPad ? 16 : 12)
                }
            } else {
                // Upload in progress or queued
                HStack(spacing: isIPad ? 16 : 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: isIPad ? 12 : 10)
                            .fill(Color.orange)
                            .frame(width: isIPad ? 64 : 56, height: isIPad ? 64 : 56)

                        ProgressView()
                            .tint(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Video Uploading")
                            .font(isIPad ? .title3 : .body)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text("Check back soon for the full game video")
                            .font(isIPad ? .body : .caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(isIPad ? 20 : 16)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(isIPad ? 16 : 12)
            }

            // NAS Upload Button (show if video exists locally and NAS is configured)
            if canUploadToNAS {
                nasUploadButton
            }
        }
    }

    private var canUploadToNAS: Bool {
        // Can upload if:
        // 1. NAS URL is configured
        // 2. Video exists locally
        // 3. Timeline exists
        guard !SettingsManager.shared.nasUploadURL.isEmpty else { return false }
        guard let videoPath = findLocalVideo() else { return false }
        guard timelineExists() else { return false }
        return true
    }

    private var nasUploadButton: some View {
        VStack(spacing: isIPad ? 12 : 8) {
            Button(action: uploadToNAS) {
                HStack(spacing: isIPad ? 16 : 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: isIPad ? 12 : 10)
                            .fill(nasUploadSuccess ? Color.green : Color.cyan)
                            .frame(width: isIPad ? 64 : 56, height: isIPad ? 64 : 56)

                        if isUploadingToNAS {
                            ProgressView()
                                .tint(.white)
                        } else if nasUploadSuccess {
                            Image(systemName: "checkmark.circle.fill")
                                .font(isIPad ? .title : .title2)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "arrow.up.doc.fill")
                                .font(isIPad ? .title : .title2)
                                .foregroundColor(.white)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(nasUploadSuccess ? "Uploaded to NAS" : "Upload to NAS")
                            .font(isIPad ? .title3 : .body)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        if isUploadingToNAS {
                            Text("Uploading video and timeline...")
                                .font(isIPad ? .body : .caption)
                                .foregroundColor(.secondary)
                        } else if nasUploadSuccess {
                            Text("Processing on NAS server")
                                .font(isIPad ? .body : .caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Send to NAS for processing")
                                .font(isIPad ? .body : .caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if !nasUploadSuccess {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(isIPad ? .title2 : .title3)
                            .foregroundColor(.cyan)
                    }
                }
                .padding(isIPad ? 20 : 16)
                .background((nasUploadSuccess ? Color.green : Color.cyan).opacity(0.1))
                .cornerRadius(isIPad ? 16 : 12)
                .overlay(
                    RoundedRectangle(cornerRadius: isIPad ? 16 : 12)
                        .stroke((nasUploadSuccess ? Color.green : Color.cyan).opacity(0.3), lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
            .disabled(isUploadingToNAS || nasUploadSuccess)

            if let error = nasUploadError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(isIPad ? 12 : 10)
                .background(Color.red.opacity(0.1))
                .cornerRadius(isIPad ? 10 : 8)
            }
        }
    }

    private func uploadToNAS() {
        guard let videoPath = findLocalVideo() else {
            nasUploadError = "Video file not found"
            return
        }

        isUploadingToNAS = true
        nasUploadError = nil

        Task {
            do {
                let videoURL = URL(fileURLWithPath: videoPath)
                let response = try await NASUploadManager.shared.uploadToNAS(
                    videoURL: videoURL,
                    gameId: game.id
                )

                await MainActor.run {
                    isUploadingToNAS = false
                    nasUploadSuccess = true
                    forcePrint("✅ NAS upload successful: \(response.message)")
                }
            } catch {
                await MainActor.run {
                    isUploadingToNAS = false
                    nasUploadError = error.localizedDescription
                    forcePrint("❌ NAS upload failed: \(error)")
                }
            }
        }
    }

    private func findLocalVideo() -> String? {
        // Check if video exists at videoURL path
        if let videoURLPath = game.videoURL {
            let actualPath = resolveVideoPath(videoURLPath)
            if let path = actualPath, FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }

    private func timelineExists() -> Bool {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timelineURL = documentsPath.appendingPathComponent("timeline_\(game.id).json")
        return FileManager.default.fileExists(atPath: timelineURL.path)
    }

    private func playLocalVideo(path: String) {
        videoURLToPlay = URL(fileURLWithPath: path)
        photosAssetIdToPlay = nil
        showingVideoPlayer = true
    }

    private func playPhotosVideo(assetId: String) {
        photosAssetIdToPlay = assetId
        videoURLToPlay = nil
        showingVideoPlayer = true
    }

    /// Resolves a video path that might be a full path or just a filename
    /// iOS documents directory paths can change between app launches, so we need to handle both cases
    private func resolveVideoPath(_ storedPath: String) -> String? {
        // If the stored path exists as-is, use it
        if FileManager.default.fileExists(atPath: storedPath) {
            return storedPath
        }

        // Otherwise, treat it as a filename and look in documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filename = URL(fileURLWithPath: storedPath).lastPathComponent
        let reconstructedPath = documentsPath.appendingPathComponent(filename).path

        if FileManager.default.fileExists(atPath: reconstructedPath) {
            debugPrint("📹 Resolved video path from filename: \(filename)")
            return reconstructedPath
        }

        forcePrint("❌ Could not resolve video path: \(storedPath)")
        return nil
    }

    // MARK: - Achievements Section

    @ViewBuilder
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: isIPad ? 20 : 16) {
            Text("Achievements Earned")
                .font(isIPad ? .title2 : .headline)
                .fontWeight(.bold)
                .foregroundColor(.orange)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: isIPad ? 12 : 8) {
                ForEach(game.achievements.prefix(6), id: \.id) { achievement in
                    HStack(spacing: isIPad ? 12 : 8) {
                        Text(achievement.emoji)
                            .font(isIPad ? .title2 : .title3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(achievement.name)
                                .font(isIPad ? .body : .caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Text(achievement.description)
                                .font(isIPad ? .caption : .caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(isIPad ? 12 : 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(isIPad ? 12 : 8)
                }
            }
            
            if game.achievements.count > 6 {
                Text("+ \(game.achievements.count - 6) more achievements")
                    .font(isIPad ? .body : .caption)
                    .foregroundColor(.orange)
                    .fontWeight(.medium)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func editableStatCard(for title: String, value: Binding<Int>, color: Color) -> some View {
        DetailStatCard(title: title, value: "\(value.wrappedValue)", color: color)
            .onLongPressGesture {
                if authService.canEditGames {
                    editingStatTitle = title
                    editingStatValue = "\(value.wrappedValue)"
                    statUpdateBinding = value
                    isEditingStat = true
                }
            }
    }
    
    private func calculatePointsPerMinute() -> Double {
        guard game.totalPlayingTimeMinutes > 0 else { return 0.0 }
        return Double(game.points) / game.totalPlayingTimeMinutes
    }
    
    private func calculateGameScore() -> Double {
        // Simplified game score calculation
        let positiveActions = Double(game.points + game.rebounds + game.assists + game.steals + game.blocks)
        let negativeActions = Double(game.turnovers + game.fouls)
        let missedShots = Double((game.fg2a + game.fg3a) - (game.fg2m + game.fg3m))
        let missedFTs = Double(game.fta - game.ftm)
        
        return positiveActions - (negativeActions + missedShots * 0.5 + missedFTs * 0.5)
    }
    
    private func calculateUsageRate() -> Double {
        // Simplified usage rate - in a real app, you'd need team totals
        let fieldGoalAttempts = Double(game.fg2a + game.fg3a)
        let turnovers = Double(game.turnovers)
        let freeThrowFactor = Double(game.fta) * 0.44
        let possessions = fieldGoalAttempts + turnovers + freeThrowFactor
        return possessions > 0 ? (possessions / 100.0) * 100 : 0
    }
    
    private func calculateEfficiency() -> Double {
        let totalShots = game.fg2a + game.fg3a + game.fta
        return totalShots > 0 ? Double(game.points) / Double(totalShots) : 0
    }
    
    private func calculateImpactScore() -> Double {
        // Custom impact score combining various stats
        let offense = Double(game.points + game.assists * 2)
        let defense = Double(game.steals * 2 + game.blocks * 2 + game.rebounds)
        let negatives = Double(game.turnovers * 2 + game.fouls)
        
        return offense + defense - negatives
    }
    
    private func saveStatChange() {
        guard let newValue = Int(editingStatValue), let binding = statUpdateBinding else { return }
        
        binding.wrappedValue = newValue
        
        // Recalculate points if a shooting stat changed
        if ["2PT Made", "3PT Made", "FT Made"].contains(editingStatTitle) {
            game.points = (game.fg2m * 2) + (game.fg3m * 3) + game.ftm
        }
        
        // Update achievements
        game.achievements = Achievement.getEarnedAchievements(for: game)
        
        Task {
            do {
                try await firebaseService.updateGame(game)
            } catch {
                debugPrint("Failed to save game changes: \(error.localizedDescription)")
            }
        }
    }
    
    private func saveScoreChange() {
        guard let myScore = Int(editingMyTeamScore),
              let opponentScore = Int(editingOpponentScore) else { return }
        
        game.myTeamScore = myScore
        game.opponentScore = opponentScore
        
        // Recalculate outcome
        if myScore > opponentScore {
            game.outcome = .win
        } else if myScore < opponentScore {
            game.outcome = .loss
        } else {
            game.outcome = .tie
        }
        
        Task {
            do {
                try await firebaseService.updateGame(game)
            } catch {
                debugPrint("Failed to save score change: \(error.localizedDescription)")
            }
        }
    }
    
    private func saveTeamNameChange() {
        // Trim whitespace and ensure names aren't empty
        let newTeamName = editingTeamName.trimmingCharacters(in: .whitespacesAndNewlines)
        let newOpponentName = editingOpponentName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !newTeamName.isEmpty && !newOpponentName.isEmpty else { return }

        game.teamName = newTeamName
        game.opponent = newOpponentName

        Task {
            do {
                try await firebaseService.updateGame(game)
            } catch {
                debugPrint("Failed to save team name changes: \(error.localizedDescription)")
            }
        }
    }

    private func setupGameListener() {
        guard let gameId = game.id else {
            debugPrint("⚠️ Cannot setup listener: game has no ID")
            return
        }

        debugPrint("👂 Setting up Firestore listener for game: \(gameId)")

        let db = Firestore.firestore()
        gameListener = db.collection("games").document(gameId).addSnapshotListener { documentSnapshot, error in
            guard let document = documentSnapshot else {
                forcePrint("❌ Error fetching game updates: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            guard let data = document.data() else {
                debugPrint("⚠️ Game document has no data")
                return
            }

            // Update photosAssetId if it changed
            if let photosAssetId = data["photosAssetId"] as? String {
                if self.game.photosAssetId != photosAssetId {
                    debugPrint("📸 Photos Asset ID updated: \(photosAssetId)")
                    self.game.photosAssetId = photosAssetId
                }
            }

            // Update videoURL if it changed
            if let videoURL = data["videoURL"] as? String {
                if self.game.videoURL != videoURL {
                    debugPrint("📹 Video URL updated: \(videoURL)")
                    self.game.videoURL = videoURL
                }
            }

            // Update youtubeVideoId if it changed
            if let youtubeVideoId = data["youtubeVideoId"] as? String {
                if self.game.youtubeVideoId != youtubeVideoId {
                    debugPrint("📺 YouTube Video ID updated: \(youtubeVideoId)")
                    self.game.youtubeVideoId = youtubeVideoId
                }
            }
        }
    }
}


