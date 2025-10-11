//
//  ScoreTimelineTracker.swift
//  SahilStats
//
//  Tracks score changes with timestamps during video recording
//

import Foundation

class ScoreTimelineTracker {
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
    }

    private var recordingStartTime: Date?
    private(set) var snapshots: [ScoreSnapshot] = []
    private var lastSnapshot: ScoreSnapshot?

    private init() {}

    // MARK: - Recording Control

    func startRecording(initialGame: LiveGame) {
        recordingStartTime = Date()
        snapshots = []

        // Capture initial state at time 0
        let initialSnapshot = ScoreSnapshot(
            timestamp: 0,
            homeScore: initialGame.homeScore,
            awayScore: initialGame.awayScore,
            quarter: initialGame.quarter,
            clockTime: initialGame.currentClockDisplay,
            homeTeam: initialGame.teamName,
            awayTeam: initialGame.opponent,
            gameFormat: initialGame.gameFormat
        )

        snapshots.append(initialSnapshot)
        lastSnapshot = initialSnapshot

        print("📊 ScoreTimelineTracker: Recording started")
        print("   Initial: \(initialGame.teamName) \(initialGame.homeScore) - \(initialGame.awayScore) \(initialGame.opponent)")
    }

    func updateScore(game: LiveGame) {
        guard let startTime = recordingStartTime else {
            print("⚠️ ScoreTimelineTracker: Cannot update - recording not started")
            return
        }

        // Check if anything changed (score, quarter, OR clock)
        let scoreChanged = lastSnapshot?.homeScore != game.homeScore ||
                          lastSnapshot?.awayScore != game.awayScore ||
                          lastSnapshot?.quarter != game.quarter

        let clockChanged = lastSnapshot?.clockTime != game.currentClockDisplay

        // Always capture if score/quarter changed, or if clock changed (for smooth clock updates)
        guard scoreChanged || clockChanged else {
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
            gameFormat: game.gameFormat
        )

        snapshots.append(snapshot)
        lastSnapshot = snapshot

        if scoreChanged {
            print("📊 ScoreTimelineTracker: Score changed at \(String(format: "%.1f", timestamp))s")
            print("   New score: \(game.teamName) \(game.homeScore) - \(game.awayScore) \(game.opponent)")
        }
        // Don't log every clock update to avoid spam
    }

    func stopRecording() -> [ScoreSnapshot] {
        let timeline = snapshots

        print("📊 ScoreTimelineTracker: Recording stopped")
        print("   Total snapshots: \(timeline.count)")

        if timeline.count > 0 {
            let duration = timeline.last!.timestamp - timeline.first!.timestamp
            print("   Duration: \(String(format: "%.1f", duration))s")
            print("   Average: \(String(format: "%.1f", duration / Double(timeline.count)))s per snapshot")
        }

        // Reset state
        recordingStartTime = nil
        snapshots = []
        lastSnapshot = nil

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
            print("✅ Score timeline saved: \(timelineURL.lastPathComponent)")
        } catch {
            print("❌ Failed to save timeline: \(error)")
        }
    }

    func loadTimeline(forGameId gameId: String) -> [ScoreSnapshot]? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timelineURL = documentsPath.appendingPathComponent("timeline_\(gameId).json")

        do {
            let data = try Data(contentsOf: timelineURL)
            let timeline = try JSONDecoder().decode([ScoreSnapshot].self, from: data)
            print("✅ Score timeline loaded: \(timeline.count) snapshots")
            return timeline
        } catch {
            print("❌ Failed to load timeline: \(error)")
            return nil
        }
    }
}
