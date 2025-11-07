//
//  ScoreTimelineTracker.swift
//  SahilStats
//
//  Tracks score changes with timestamps for post-processing overlays
//  Supports both video recording and standalone timeline recording
//

import Foundation
import Combine

class ScoreTimelineTracker: ObservableObject {
    static let shared = ScoreTimelineTracker()

    struct ScoreSnapshot: Codable {
        let timestamp: TimeInterval  // Seconds from start of recording
        let homeScore: Int
        let awayScore: Int
        let quarter: Int
        let clockTime: String
        let homeTeam: String
        let awayTeam: String
        let gameFormat: GameFormat
        let numQuarter: Int  // Total regular periods (for OT detection)
        let zoomLevel: CGFloat?  // Camera zoom level (nil = 1.0x)
        let homeLogoURL: String?  // Home team logo
        let awayLogoURL: String?  // Away team logo
    }

    private var recordingStartTime: Date?
    private(set) var snapshots: [ScoreSnapshot] = []
    private var lastSnapshot: ScoreSnapshot?
    private var captureTimer: Timer?
    private var currentGame: LiveGame?
    private var homeLogoURL: String?
    private var awayLogoURL: String?

    @Published private(set) var isRecording: Bool = false

    private init() {}

    // MARK: - Recording Control

    /// Start timeline recording with second-by-second capture
    /// - Parameters:
    ///   - initialGame: The game to track
    ///   - homeLogoURL: Optional home team logo URL
    ///   - awayLogoURL: Optional away team logo URL
    ///   - captureInterval: Seconds between automatic captures (default: 1.0 for second-by-second)
    func startRecording(initialGame: LiveGame, homeLogoURL: String? = nil, awayLogoURL: String? = nil, captureInterval: TimeInterval = 1.0) {
        // Stop any existing recording
        stopRecording()

        recordingStartTime = Date()
        snapshots = []
        currentGame = initialGame
        self.homeLogoURL = homeLogoURL
        self.awayLogoURL = awayLogoURL
        isRecording = true

        // Capture initial state at time 0
        let initialSnapshot = ScoreSnapshot(
            timestamp: 0,
            homeScore: initialGame.homeScore,
            awayScore: initialGame.awayScore,
            quarter: initialGame.quarter,
            clockTime: initialGame.currentClockDisplay,
            homeTeam: initialGame.teamName,
            awayTeam: initialGame.opponent,
            gameFormat: initialGame.gameFormat,
            numQuarter: initialGame.numQuarter,
            zoomLevel: nil,  // Simplified - no zoom tracking
            homeLogoURL: homeLogoURL,
            awayLogoURL: awayLogoURL
        )

        snapshots.append(initialSnapshot)
        lastSnapshot = initialSnapshot

        // Start timer for periodic capture
        captureTimer = Timer.scheduledTimer(withTimeInterval: captureInterval, repeats: true) { [weak self] _ in
            self?.captureCurrentState()
        }

        debugPrint("📊 ScoreTimelineTracker: Recording started (interval: \(captureInterval)s)")
        debugPrint("   Initial: \(initialGame.teamName) \(initialGame.homeScore) - \(initialGame.awayScore) \(initialGame.opponent)")
    }

    /// Capture the current game state (called by timer and on manual updates)
    private func captureCurrentState() {
        guard let startTime = recordingStartTime,
              let game = currentGame else {
            return
        }

        let timestamp = Date().timeIntervalSince(startTime)

        let snapshot = ScoreSnapshot(
            timestamp: timestamp,
            homeScore: game.homeScore,
            awayScore: game.awayScore,
            quarter: game.quarter,
            clockTime: game.currentClockDisplay,
            homeTeam: game.teamName,
            awayTeam: game.opponent,
            gameFormat: game.gameFormat,
            numQuarter: game.numQuarter,
            zoomLevel: nil,
            homeLogoURL: homeLogoURL,
            awayLogoURL: awayLogoURL
        )

        snapshots.append(snapshot)
        lastSnapshot = snapshot
    }

    /// Update the game state (called when score/clock changes)
    /// This immediately captures important events (score changes) in addition to timer-based captures
    func updateScore(game: LiveGame) {
        guard recordingStartTime != nil else {
            debugPrint("⚠️ ScoreTimelineTracker: Cannot update - recording not started")
            return
        }

        // Update current game state
        currentGame = game

        // Check if score or quarter changed (important events)
        let scoreChanged = lastSnapshot?.homeScore != game.homeScore ||
                          lastSnapshot?.awayScore != game.awayScore ||
                          lastSnapshot?.quarter != game.quarter

        // Immediately capture important events (don't wait for timer)
        if scoreChanged {
            captureCurrentState()
            let timestamp = lastSnapshot?.timestamp ?? 0
            debugPrint("📊 ScoreTimelineTracker: Score changed at \(String(format: "%.1f", timestamp))s")
            debugPrint("   New score: \(game.teamName) \(game.homeScore) - \(game.awayScore) \(game.opponent)")
        }
        // Timer will handle regular periodic captures
    }

    @discardableResult
    func stopRecording() -> [ScoreSnapshot] {
        // Stop timer
        captureTimer?.invalidate()
        captureTimer = nil

        let timeline = snapshots

        debugPrint("📊 ScoreTimelineTracker: Recording stopped")
        debugPrint("   Total snapshots: \(timeline.count)")

        if timeline.count > 0 {
            let duration = timeline.last!.timestamp - timeline.first!.timestamp
            debugPrint("   Duration: \(String(format: "%.1f", duration))s")
            debugPrint("   Average: \(String(format: "%.1f", duration / Double(timeline.count)))s per snapshot")
        }

        // Reset state
        recordingStartTime = nil
        snapshots = []
        lastSnapshot = nil
        currentGame = nil
        homeLogoURL = nil
        awayLogoURL = nil
        isRecording = false

        return timeline
    }

    // MARK: - Timeline Access

    func getSnapshotAt(time: TimeInterval) -> ScoreSnapshot? {
        guard !snapshots.isEmpty else { return nil }

        // Find the most recent snapshot before or at this time
        var result = snapshots[0]

        for snapshot in snapshots {
            if snapshot.timestamp <= time {
                result = snapshot
            } else {
                break
            }
        }

        return result
    }

    // MARK: - Persistence

    func saveTimeline(_ timeline: [ScoreSnapshot], forGameId gameId: String) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timelineURL = documentsPath.appendingPathComponent("timeline_\(gameId).json")

        do {
            let data = try JSONEncoder().encode(timeline)
            try data.write(to: timelineURL)
            forcePrint("✅ Score timeline saved: \(timelineURL.lastPathComponent)")
        } catch {
            forcePrint("❌ Failed to save timeline: \(error)")
        }
    }

    func loadTimeline(forGameId gameId: String) -> [ScoreSnapshot]? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timelineURL = documentsPath.appendingPathComponent("timeline_\(gameId).json")

        do {
            let data = try Data(contentsOf: timelineURL)
            let timeline = try JSONDecoder().decode([ScoreSnapshot].self, from: data)
            debugPrint("✅ Score timeline loaded: \(timeline.count) snapshots")
            return timeline
        } catch {
            forcePrint("❌ Failed to load timeline: \(error)")
            return nil
        }
    }

    // MARK: - Export

    /// Get the URL for the timeline file (for sharing)
    func getTimelineURL(forGameId gameId: String) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timelineURL = documentsPath.appendingPathComponent("timeline_\(gameId).json")

        // Check if file exists
        guard FileManager.default.fileExists(atPath: timelineURL.path) else {
            return nil
        }

        return timelineURL
    }

    /// Export timeline as formatted JSON string (for debugging/viewing)
    func exportTimelineAsJSON(_ timeline: [ScoreSnapshot]) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(timeline)
            return String(data: data, encoding: .utf8)
        } catch {
            forcePrint("❌ Failed to export timeline as JSON: \(error)")
            return nil
        }
    }

    /// Check if a timeline exists for a game
    func timelineExists(forGameId gameId: String) -> Bool {
        return getTimelineURL(forGameId: gameId) != nil
    }
}
