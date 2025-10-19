//
//  VideoPOCView.swift
//  SahilStats
//
//  Proof of Concept: AI Stats Extraction
//

import SwiftUI

struct VideoPOCView: View {
    @State private var retrievedGame: Game?
    @State private var isRetrieving = false
    @State private var errorMessage: String?
    @State private var showingStats = false
    @State private var selectedVideo: TestVideo = .justHoop
    @State private var showingVideoSelection = false

    // Video processing state
    @State private var isProcessingVideo = false
    @State private var downloadProgress: Double = 0
    @State private var extractionProgress: Double = 0
    @State private var extractedFrames: [VideoFrame] = []
    @State private var videoMetadata: VideoMetadata?
    @State private var processingError: String?
    @State private var processingComplete = false

    enum TestVideo: String, CaseIterable {
        case justHoop = "Just Hoop"
        case teamElite = "Team Elite"

        var displayName: String { rawValue }
        var youtubeURL: String {
            switch self {
            case .justHoop: return "https://www.youtube.com/watch?v=f5M14MI-DJo"
            case .teamElite: return "https://youtu.be/z9AZQ1h8XyY?si=0iVGEN8axbBkRZax"
            }
        }
        var jerseyColor: String {
            switch self {
            case .justHoop: return "BLACK"
            case .teamElite: return "WHITE"
            }
        }
        var recommended: Bool {
            self == .justHoop // Basket clearly visible
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        Text("AI Stats PoC")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Proof of Concept: Video Stats Extraction")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 32)

                    Divider()

                    // Step 1: Retrieve Actual Stats
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "1.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                            Text("Select Test Video & Retrieve Stats")
                                .font(.headline)
                        }

                        // Video Selection
                        HStack {
                            Text("Test Video:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: {
                                showingVideoSelection = true
                            }) {
                                HStack {
                                    Text("Elements vs \(selectedVideo.displayName)")
                                        .fontWeight(.medium)
                                    if selectedVideo.recommended {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                    }
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Jersey: #3 \(selectedVideo.jerseyColor)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if selectedVideo.recommended {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    Text("Recommended: Basket clearly visible")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .padding(.leading, 8)

                        Text("Get the actual stats from the database. This will be our baseline for comparison.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if let game = retrievedGame {
                            // Show retrieved game summary
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Stats Retrieved!")
                                        .fontWeight(.semibold)
                                }

                                Divider()

                                HStack {
                                    Text(game.teamName)
                                    Spacer()
                                    Text("\(game.myTeamScore)")
                                        .fontWeight(.bold)
                                }

                                HStack {
                                    Text(game.opponent)
                                    Spacer()
                                    Text("\(game.opponentScore)")
                                        .fontWeight(.bold)
                                }

                                Divider()

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Sahil's Stats:")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)

                                    HStack {
                                        Text("Points:")
                                        Spacer()
                                        Text("\(game.points)")
                                    }
                                    .font(.caption)

                                    HStack {
                                        Text("FG:")
                                        Spacer()
                                        Text("\(game.fg2m + game.fg3m)/\(game.fg2a + game.fg3a) (\(String(format: "%.1f", game.fieldGoalPercentage * 100))%)")
                                    }
                                    .font(.caption)
                                }

                                Button(action: {
                                    showingStats = true
                                }) {
                                    HStack {
                                        Image(systemName: "doc.text")
                                        Text("View Full Stats")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                        } else {
                            Button(action: retrieveStats) {
                                HStack {
                                    if isRetrieving {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                    } else {
                                        Image(systemName: "arrow.down.circle.fill")
                                        Text("Retrieve Stats from Database")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(isRetrieving)
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(radius: 2)

                    // Step 2: Process Video with AI
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "2.circle.fill")
                                .font(.title2)
                                .foregroundColor(retrievedGame == nil ? .gray : .blue)
                            Text("Download & Extract Frames")
                                .font(.headline)
                                .foregroundColor(retrievedGame == nil ? .gray : .primary)
                        }

                        Text("Download the YouTube video and extract frames for AI processing (1 frame per second).")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if processingComplete {
                            // Success state
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Processing Complete!")
                                        .fontWeight(.semibold)
                                }

                                if let metadata = videoMetadata {
                                    Divider()

                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Video Metadata:")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)

                                        HStack {
                                            Text("Duration:")
                                            Spacer()
                                            Text(metadata.durationFormatted)
                                        }
                                        .font(.caption)

                                        HStack {
                                            Text("Resolution:")
                                            Spacer()
                                            Text("\(Int(metadata.resolution.width))x\(Int(metadata.resolution.height))")
                                        }
                                        .font(.caption)

                                        HStack {
                                            Text("Frames Extracted:")
                                            Spacer()
                                            Text("\(extractedFrames.count)")
                                        }
                                        .font(.caption)
                                    }

                                    // Show sample frames
                                    if !extractedFrames.isEmpty {
                                        Divider()

                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Sample Frames:")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)

                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: 12) {
                                                    ForEach(Array(extractedFrames.prefix(5).enumerated()), id: \.offset) { index, frame in
                                                        VStack(spacing: 4) {
                                                            Image(uiImage: frame.image)
                                                                .resizable()
                                                                .aspectRatio(contentMode: .fill)
                                                                .frame(width: 120, height: 80)
                                                                .cornerRadius(8)

                                                            Text(frame.timestampFormatted)
                                                                .font(.caption2)
                                                                .foregroundColor(.secondary)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)

                        } else if isProcessingVideo {
                            // Processing in progress
                            VStack(alignment: .leading, spacing: 16) {
                                // Download progress
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Downloading video...")
                                        Spacer()
                                        Text("\(Int(downloadProgress * 100))%")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .font(.subheadline)

                                    ProgressView(value: downloadProgress)
                                }

                                // Extraction progress
                                if downloadProgress >= 1.0 {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("Extracting frames...")
                                            Spacer()
                                            Text("\(Int(extractionProgress * 100))%")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .font(.subheadline)

                                        ProgressView(value: extractionProgress)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)

                        } else {
                            // Not started yet
                            Button(action: processVideo) {
                                HStack {
                                    Image(systemName: "video.fill")
                                    Text("Download & Extract Frames")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(retrievedGame == nil ? Color.gray : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(retrievedGame == nil)
                        }

                        if let error = processingError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(radius: 2)
                    .opacity(retrievedGame == nil ? 0.5 : 1.0)

                    // Step 3: Compare Results (Coming Soon)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "3.circle.fill")
                                .font(.title2)
                                .foregroundColor(.gray)
                            Text("Compare & Calculate Accuracy")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }

                        Text("Final step: Compare AI-detected stats with actual stats and calculate accuracy percentage.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("Coming soon...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(radius: 2)
                    .opacity(retrievedGame == nil ? 0.5 : 1.0)

                    Spacer(minLength: 32)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("PoC: AI Stats")
            .sheet(isPresented: $showingStats) {
                if let game = retrievedGame {
                    DetailedStatsView(game: game)
                }
            }
            .confirmationDialog("Select Test Video", isPresented: $showingVideoSelection) {
                ForEach(TestVideo.allCases, id: \.self) { video in
                    Button(action: {
                        selectedVideo = video
                        // Clear retrieved game when switching videos
                        retrievedGame = nil
                        errorMessage = nil
                    }) {
                        HStack {
                            Text("Elements vs \(video.displayName)")
                            if video.recommended {
                                Image(systemName: "star.fill")
                            }
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Choose which game to use for the PoC test")
            }
        }
    }

    // MARK: - Actions

    private func retrieveStats() {
        isRetrieving = true
        errorMessage = nil

        Task {
            do {
                // Retrieve stats based on selected video
                let game: Game?
                switch selectedVideo {
                case .justHoop:
                    game = try await StatsRetriever.shared.getElementsVsJustHoopStats()
                case .teamElite:
                    game = try await StatsRetriever.shared.getElementsVsTeamEliteStats()
                }

                await MainActor.run {
                    if let game = game {
                        self.retrievedGame = game
                        StatsRetriever.shared.printDetailedStats(for: game)

                        // Also update the POC_ACTUAL_STATS.md file
                        let markdown = StatsRetriever.shared.generateMarkdownSummary(for: game, videoURL: selectedVideo.youtubeURL, jerseyColor: selectedVideo.jerseyColor)
                        saveMarkdownToFile(markdown)
                    } else {
                        self.errorMessage = "No Elements vs \(selectedVideo.displayName) game found in database"
                    }
                    self.isRetrieving = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Error retrieving stats: \(error.localizedDescription)"
                    self.isRetrieving = false
                }
            }
        }
    }

    private func saveMarkdownToFile(_ markdown: String) {
        let fileURL = URL(fileURLWithPath: "/Users/narayan/SahilStats/SahilStats/POC_ACTUAL_STATS.md")

        do {
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
            print("✅ Updated POC_ACTUAL_STATS.md with retrieved stats")
        } catch {
            print("❌ Failed to write markdown file: \(error)")
        }
    }

    private func processVideo() {
        isProcessingVideo = true
        processingError = nil
        downloadProgress = 0
        extractionProgress = 0
        extractedFrames = []
        videoMetadata = nil
        processingComplete = false

        Task {
            do {
                print("\n" + String(repeating: "=", count: 50))
                print("🎬 STEP 2: VIDEO PROCESSING")
                print(String(repeating: "=", count: 50))

                // Step 2.1: Download video
                print("\n📥 Step 2.1: Downloading video...")
                let videoURL = try await YouTubeDownloader.shared.downloadVideo(
                    youtubeURL: selectedVideo.youtubeURL
                ) { progress in
                    Task { @MainActor in
                        self.downloadProgress = progress
                    }
                }

                // Step 2.2: Get video metadata
                print("\n📊 Step 2.2: Analyzing video metadata...")
                let metadata = try await VideoFrameExtractor.shared.getVideoMetadata(from: videoURL)

                await MainActor.run {
                    self.videoMetadata = metadata
                }

                // Step 2.3: Extract frames
                print("\n🎬 Step 2.3: Extracting frames...")
                let frames = try await VideoFrameExtractor.shared.extractFrames(
                    from: videoURL,
                    fps: 1.0
                ) { progress, current, total in
                    Task { @MainActor in
                        self.extractionProgress = progress
                    }
                }

                // Step 2.4: Save frames to disk (optional, for debugging)
                print("\n💾 Step 2.4: Saving frames to disk...")
                let framesDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("POC_Frames", isDirectory: true)
                try VideoFrameExtractor.shared.saveFramesToDisk(frames: frames, directory: framesDir)

                await MainActor.run {
                    self.extractedFrames = frames
                    self.processingComplete = true
                    self.isProcessingVideo = false
                }

                print("\n" + String(repeating: "=", count: 50))
                print("✅ STEP 2 COMPLETE!")
                print("   Frames extracted: \(frames.count)")
                print("   Frames saved to: \(framesDir.path)")
                print(String(repeating: "=", count: 50) + "\n")

            } catch {
                await MainActor.run {
                    self.processingError = "Processing failed: \(error.localizedDescription)"
                    self.isProcessingVideo = false
                }
                print("\n❌ Step 2 failed: \(error)")
            }
        }
    }
}

// MARK: - Detailed Stats Sheet

struct DetailedStatsView: View {
    let game: Game
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Game Header
                    VStack(spacing: 8) {
                        Text("\(game.teamName) vs \(game.opponent)")
                            .font(.title2)
                            .fontWeight(.bold)

                        HStack(spacing: 32) {
                            VStack {
                                Text(game.teamName)
                                    .font(.caption)
                                Text("\(game.myTeamScore)")
                                    .font(.title)
                                    .fontWeight(.bold)
                            }

                            Text("-")
                                .font(.title)
                                .foregroundColor(.secondary)

                            VStack {
                                Text(game.opponent)
                                    .font(.caption)
                                Text("\(game.opponentScore)")
                                    .font(.title)
                                    .fontWeight(.bold)
                            }
                        }

                        Text(game.outcome.displayName)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(game.outcome == .win ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                    // Shooting Stats
                    StatsSection(title: "Shooting Stats") {
                        StatRow(label: "2-Point", value: "\(game.fg2m)/\(game.fg2a)", percentage: game.twoPointPercentage)
                        StatRow(label: "3-Point", value: "\(game.fg3m)/\(game.fg3a)", percentage: game.threePointPercentage)
                        StatRow(label: "Free Throw", value: "\(game.ftm)/\(game.fta)", percentage: game.freeThrowPercentage)

                        Divider()

                        StatRow(label: "Total FG", value: "\(game.fg2m + game.fg3m)/\(game.fg2a + game.fg3a)", percentage: game.fieldGoalPercentage, highlighted: true)
                        StatRow(label: "Total Points", value: "\(game.points)", percentage: nil, highlighted: true)
                    }

                    // Other Stats
                    StatsSection(title: "Other Stats") {
                        SimpleStatRow(label: "Rebounds", value: game.rebounds)
                        SimpleStatRow(label: "Assists", value: game.assists)
                        SimpleStatRow(label: "Steals", value: game.steals)
                        SimpleStatRow(label: "Blocks", value: game.blocks)
                        SimpleStatRow(label: "Turnovers", value: game.turnovers)
                        SimpleStatRow(label: "Fouls", value: game.fouls)
                    }

                    // Playing Time
                    StatsSection(title: "Playing Time") {
                        StatRow(label: "Minutes Played", value: String(format: "%.1f min", game.totalPlayingTimeMinutes), percentage: nil)
                        StatRow(label: "Playing Time %", value: String(format: "%.1f%%", game.playingTimePercentage), percentage: nil)
                    }

                    // PoC Targets
                    StatsSection(title: "PoC Success Targets") {
                        let totalShots = game.fg2a + game.fg3a
                        let totalMakes = game.fg2m + game.fg3m

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Minimum (70% accuracy):")
                                .fontWeight(.semibold)
                            Text("• Detect \(Int(Double(totalShots) * 0.7))+ of \(totalShots) shots")
                                .font(.caption)
                            Text("• Classify \(Int(Double(totalMakes) * 0.7))+ of \(totalMakes) makes correctly")
                                .font(.caption)

                            Text("Good (80% accuracy):")
                                .fontWeight(.semibold)
                                .padding(.top, 8)
                            Text("• Detect \(Int(Double(totalShots) * 0.8))+ of \(totalShots) shots")
                                .font(.caption)
                            Text("• Classify \(Int(Double(totalMakes) * 0.8))+ of \(totalMakes) makes correctly")
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("Actual Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Helper Views

struct StatsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)

            content
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct StatRow: View {
    let label: String
    let value: String
    let percentage: Double?
    var highlighted: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .fontWeight(highlighted ? .semibold : .regular)
            Spacer()
            HStack(spacing: 8) {
                Text(value)
                    .fontWeight(highlighted ? .bold : .regular)
                if let pct = percentage {
                    Text("(\(String(format: "%.1f", pct * 100))%)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .font(highlighted ? .body : .subheadline)
    }
}

struct SimpleStatRow: View {
    let label: String
    let value: Int

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(value)")
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }
}

#Preview {
    VideoPOCView()
}
