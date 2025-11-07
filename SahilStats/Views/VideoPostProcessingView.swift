//
//  VideoPostProcessingView.swift
//  SahilStats
//
//  Post-processing workflow for adding score overlays to externally recorded videos
//  Works with videos from Native Camera, Insta360, or any other source
//

import SwiftUI
import PhotosUI
import AVFoundation

struct VideoPostProcessingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State private var processingStep: ProcessingStep = .selectVideo
    @State private var selectedVideoURL: URL?
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var selectedGameId: String?
    @State private var availableGames: [(id: String, name: String)] = []
    @State private var syncOffset: TimeInterval = 0
    @State private var isProcessing = false
    @State private var processingProgress: Double = 0
    @State private var errorMessage: String?

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    enum ProcessingStep {
        case selectVideo
        case selectTimeline
        case syncVideo
        case processing
        case complete
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Main content
                ScrollView {
                    VStack(spacing: isIPad ? 32 : 24) {
                        // Progress indicator
                        stepProgressIndicator

                        // Current step content
                        switch processingStep {
                        case .selectVideo:
                            videoSelectionView
                        case .selectTimeline:
                            timelineSelectionView
                        case .syncVideo:
                            videoSyncView
                        case .processing:
                            processingView
                        case .complete:
                            completionView
                        }
                    }
                    .padding(isIPad ? 24 : 16)
                }

                // Error overlay
                if let error = errorMessage {
                    VStack {
                        Spacer()
                        errorBanner(message: error)
                            .padding()
                    }
                }
            }
            .navigationTitle("Add Score Overlay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadAvailableTimelines()
        }
    }

    // MARK: - Step Progress Indicator

    private var stepProgressIndicator: some View {
        HStack(spacing: isIPad ? 16 : 12) {
            stepIndicator(number: 1, title: "Video", isActive: processingStep == .selectVideo, isCompleted: processingStep.rawValue > 0)
            progressLine(isCompleted: processingStep.rawValue > 0)
            stepIndicator(number: 2, title: "Timeline", isActive: processingStep == .selectTimeline, isCompleted: processingStep.rawValue > 1)
            progressLine(isCompleted: processingStep.rawValue > 1)
            stepIndicator(number: 3, title: "Sync", isActive: processingStep == .syncVideo, isCompleted: processingStep.rawValue > 2)
            progressLine(isCompleted: processingStep.rawValue > 2)
            stepIndicator(number: 4, title: "Process", isActive: processingStep == .processing || processingStep == .complete, isCompleted: processingStep == .complete)
        }
        .padding(.vertical, isIPad ? 20 : 16)
    }

    private func stepIndicator(number: Int, title: String, isActive: Bool, isCompleted: Bool) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.green : (isActive ? Color.blue : Color.gray.opacity(0.3)))
                    .frame(width: isIPad ? 40 : 32, height: isIPad ? 40 : 32)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: isIPad ? 16 : 14, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(number)")
                        .font(.system(size: isIPad ? 16 : 14, weight: .semibold))
                        .foregroundColor(isActive ? .white : .gray)
                }
            }

            Text(title)
                .font(.system(size: isIPad ? 12 : 10, weight: .medium))
                .foregroundColor(isActive ? .primary : .secondary)
        }
    }

    private func progressLine(isCompleted: Bool) -> some View {
        Rectangle()
            .fill(isCompleted ? Color.green : Color.gray.opacity(0.3))
            .frame(height: 2)
            .frame(maxWidth: isIPad ? 40 : 30)
    }

    // MARK: - Video Selection View

    private var videoSelectionView: some View {
        VStack(spacing: isIPad ? 24 : 20) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: isIPad ? 60 : 48))
                .foregroundColor(.blue)

            Text("Select Video")
                .font(isIPad ? .title : .title2)
                .fontWeight(.bold)

            Text("Choose a video recorded with Native Camera, Insta360, or any other app")
                .font(isIPad ? .body : .subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            PhotosPicker(selection: $selectedVideoItem, matching: .videos) {
                Label("Choose from Photos", systemImage: "photo.on.rectangle")
                    .font(.system(size: isIPad ? 18 : 16, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(isIPad ? 18 : 14)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(isIPad ? 14 : 12)
            }
            .onChange(of: selectedVideoItem) { _, newItem in
                loadVideo(from: newItem)
            }

            // Video info if selected
            if let videoURL = selectedVideoURL {
                videoInfoCard(url: videoURL)
            }
        }
        .padding(isIPad ? 24 : 16)
    }

    private func videoInfoCard(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Video Selected")
                    .font(.headline)
                Spacer()
            }

            if let videoInfo = getVideoInfo(url: url) {
                VStack(alignment: .leading, spacing: 6) {
                    infoRow(label: "Duration", value: formatDuration(videoInfo.duration))
                    infoRow(label: "Resolution", value: "\(Int(videoInfo.resolution.width))×\(Int(videoInfo.resolution.height))")
                    infoRow(label: "Size", value: formatFileSize(videoInfo.fileSize))
                }
                .font(.subheadline)
            }

            Button(action: {
                processingStep = .selectTimeline
            }) {
                Text("Continue")
                    .font(.system(size: isIPad ? 18 : 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(isIPad ? 16 : 12)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(isIPad ? 12 : 10)
            }
        }
        .padding(isIPad ? 20 : 16)
        .background(Color(.systemGray6))
        .cornerRadius(isIPad ? 16 : 12)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
            Text(value)
                .fontWeight(.medium)
            Spacer()
        }
    }

    // MARK: - Timeline Selection View

    private var timelineSelectionView: some View {
        VStack(spacing: isIPad ? 24 : 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: isIPad ? 60 : 48))
                .foregroundColor(.orange)

            Text("Select Game Timeline")
                .font(isIPad ? .title : .title2)
                .fontWeight(.bold)

            Text("Choose which game's score overlay to apply to this video")
                .font(isIPad ? .body : .subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if availableGames.isEmpty {
                noTimelinesView
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(availableGames, id: \.id) { game in
                            timelineGameCard(gameId: game.id, gameName: game.name)
                        }
                    }
                }
            }

            // Back button
            Button(action: {
                processingStep = .selectVideo
            }) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.system(size: isIPad ? 16 : 14, weight: .medium))
                .foregroundColor(.blue)
            }
        }
        .padding(isIPad ? 24 : 16)
    }

    private func timelineGameCard(gameId: String, gameName: String) -> some View {
        Button(action: {
            selectedGameId = gameId
            processingStep = .syncVideo
        }) {
            HStack {
                Image(systemName: "basketball")
                    .font(.title2)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text(gameName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Timeline available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(isIPad ? 20 : 16)
            .background(Color(.systemBackground))
            .cornerRadius(isIPad ? 14 : 12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }

    private var noTimelinesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("No Timelines Found")
                .font(.headline)

            Text("Record a game with timeline tracking first, then come back here to add overlays to your video")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(isIPad ? 32 : 24)
    }

    // MARK: - Video Sync View

    private var videoSyncView: some View {
        VStack(spacing: isIPad ? 24 : 20) {
            Text("Sync Video & Timeline")
                .font(isIPad ? .title : .title2)
                .fontWeight(.bold)

            Text("Adjust the timing so the overlays match the video")
                .font(isIPad ? .body : .subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Video preview placeholder
            Rectangle()
                .fill(Color.black)
                .aspectRatio(16/9, contentMode: .fit)
                .cornerRadius(isIPad ? 16 : 12)
                .overlay(
                    Text("Video Preview")
                        .foregroundColor(.white)
                )

            // Sync offset slider
            VStack(spacing: 12) {
                Text("Sync Adjustment")
                    .font(.headline)

                HStack {
                    Text("-10s")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Slider(value: $syncOffset, in: -10...10, step: 0.1)

                    Text("+10s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(String(format: "Offset: %.1fs", syncOffset))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(isIPad ? 20 : 16)
            .background(Color(.systemGray6))
            .cornerRadius(isIPad ? 14 : 12)

            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    processingStep = .selectTimeline
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(isIPad ? 16 : 12)
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(isIPad ? 12 : 10)
                }

                Button(action: startProcessing) {
                    Text("Process Video")
                        .frame(maxWidth: .infinity)
                        .padding(isIPad ? 16 : 12)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(isIPad ? 12 : 10)
                }
            }
        }
        .padding(isIPad ? 24 : 16)
    }

    // MARK: - Processing View

    private var processingView: some View {
        VStack(spacing: isIPad ? 32 : 24) {
            ProgressView(value: processingProgress)
                .progressViewStyle(LinearProgressViewStyle())
                .scaleEffect(y: 2)

            Text("Processing Video...")
                .font(isIPad ? .title2 : .title3)
                .fontWeight(.semibold)

            Text("\(Int(processingProgress * 100))%")
                .font(isIPad ? .largeTitle : .title)
                .fontWeight(.bold)
                .foregroundColor(.blue)

            Text("Adding score overlays to your video\nThis may take a few minutes...")
                .font(isIPad ? .body : .subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(isIPad ? 32 : 24)
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: isIPad ? 24 : 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: isIPad ? 80 : 64))
                .foregroundColor(.green)

            Text("Processing Complete!")
                .font(isIPad ? .title : .title2)
                .fontWeight(.bold)

            Text("Your video has been saved to Photos with score overlays")
                .font(isIPad ? .body : .subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                dismiss()
            }) {
                Text("Done")
                    .font(.system(size: isIPad ? 18 : 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(isIPad ? 18 : 14)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(isIPad ? 14 : 12)
            }
        }
        .padding(isIPad ? 32 : 24)
    }

    // MARK: - Error Banner

    private func errorBanner(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
            Text(message)
                .foregroundColor(.white)
                .font(.subheadline)
            Spacer()
            Button(action: { errorMessage = nil }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding()
        .background(Color.red)
        .cornerRadius(12)
    }

    // MARK: - Helper Functions

    private func loadAvailableTimelines() {
        // Get all timeline files from Documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            let timelineFiles = fileURLs.filter { $0.lastPathComponent.hasPrefix("timeline_") && $0.pathExtension == "json" }

            // Load game info for each timeline
            var games: [(id: String, name: String)] = []

            for timelineURL in timelineFiles {
                // Extract game ID from filename: timeline_{gameId}.json
                let filename = timelineURL.deletingPathExtension().lastPathComponent
                let gameId = filename.replacingOccurrences(of: "timeline_", with: "")

                // Try to load timeline to get game name
                if let timeline = ScoreTimelineTracker.shared.loadTimeline(forGameId: gameId),
                   let firstSnapshot = timeline.first {
                    let gameName = "\(firstSnapshot.homeTeam) vs \(firstSnapshot.awayTeam)"
                    games.append((id: gameId, name: gameName))
                } else {
                    games.append((id: gameId, name: "Game \(gameId.prefix(8))"))
                }
            }

            availableGames = games.sorted { $0.name < $1.name }
            debugPrint("📊 Found \(games.count) available timelines")

        } catch {
            debugPrint("❌ Error loading timelines: \(error)")
            errorMessage = "Failed to load timelines"
        }
    }

    private func loadVideo(from item: PhotosPickerItem?) {
        guard let item = item else { return }

        Task {
            do {
                guard let movie = try await item.loadTransferable(type: VideoFile.self) else {
                    await MainActor.run {
                        errorMessage = "Failed to load video"
                    }
                    return
                }

                await MainActor.run {
                    self.selectedVideoURL = movie.url
                    debugPrint("✅ Video loaded: \(movie.url.lastPathComponent)")
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Error loading video: \(error.localizedDescription)"
                }
            }
        }
    }

    private func getVideoInfo(url: URL) -> (duration: TimeInterval, resolution: CGSize, fileSize: Int64)? {
        let asset = AVAsset(url: url)

        guard let track = asset.tracks(withMediaType: .video).first else {
            return nil
        }

        let duration = asset.duration.seconds
        let naturalSize = track.naturalSize

        if let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 {
            return (duration, naturalSize, fileSize)
        }

        return (duration, naturalSize, 0)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func startProcessing() {
        guard let videoURL = selectedVideoURL,
              let gameId = selectedGameId else {
            errorMessage = "Missing video or timeline"
            return
        }

        processingStep = .processing

        // TODO: Implement actual processing
        // For now, simulate processing
        Task {
            for i in 0...100 {
                try? await Task.sleep(nanoseconds: 30_000_000) // 0.03 seconds
                await MainActor.run {
                    processingProgress = Double(i) / 100.0
                }
            }

            await MainActor.run {
                processingStep = .complete
            }
        }
    }
}

// MARK: - Video File Transfer Type

struct VideoFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let originalFile = received.file
            let uniqueFilename = "\(UUID().uuidString).\(originalFile.pathExtension)"
            let copiedFile = URL.documentsDirectory.appendingPathComponent(uniqueFilename)

            if FileManager.default.fileExists(atPath: copiedFile.path) {
                try FileManager.default.removeItem(at: copiedFile)
            }

            try FileManager.default.copyItem(at: originalFile, to: copiedFile)
            return Self.init(url: copiedFile)
        }
    }
}

// MARK: - Processing Step Raw Value

extension VideoPostProcessingView.ProcessingStep: Comparable {
    var rawValue: Int {
        switch self {
        case .selectVideo: return 0
        case .selectTimeline: return 1
        case .syncVideo: return 2
        case .processing: return 3
        case .complete: return 4
        }
    }

    static func < (lhs: VideoPostProcessingView.ProcessingStep, rhs: VideoPostProcessingView.ProcessingStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
