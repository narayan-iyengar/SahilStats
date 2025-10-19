//
//  StatsRetriever.swift
//  SahilStats
//
//  Helper to retrieve actual stats for PoC validation
//

import Foundation
import FirebaseFirestore

class StatsRetriever {
    static let shared = StatsRetriever()

    private init() {}

    /// Retrieve actual stats for Elements vs Team Elite game
    func getElementsVsTeamEliteStats() async throws -> Game? {
        let db = Firestore.firestore()

        print("🔍 Searching for Elements vs Team Elite game...")

        // Query for games where team is "Elements" and opponent contains "Team Elite" or "Elite"
        let snapshot = try await db.collection("games")
            .whereField("teamName", isEqualTo: "Elements")
            .getDocuments()

        print("📊 Found \(snapshot.documents.count) Elements games")

        // Find the one matching Team Elite
        for document in snapshot.documents {
            let data = document.data()
            if let opponent = data["opponent"] as? String {
                print("   - Opponent: \(opponent)")

                // Match "Team Elite", "Elite", or variations
                if opponent.lowercased().contains("elite") {
                    print("✅ Found matching game: Elements vs \(opponent)")

                    // Decode the game
                    var game = try document.data(as: Game.self)
                    game.id = document.documentID

                    return game
                }
            }
        }

        print("⚠️ No Elements vs Team Elite game found")
        return nil
    }

    /// Print detailed stats for a game
    func printDetailedStats(for game: Game) {
        print("""

        ═══════════════════════════════════════════
        📊 ACTUAL STATS: \(game.teamName) vs \(game.opponent)
        ═══════════════════════════════════════════

        SHOOTING STATS:
        ───────────────
        2-Point: \(game.fg2m)/\(game.fg2a) (\(String(format: "%.1f", game.twoPointPercentage * 100))%)
        3-Point: \(game.fg3m)/\(game.fg3a) (\(String(format: "%.1f", game.threePointPercentage * 100))%)
        Free Throw: \(game.ftm)/\(game.fta) (\(String(format: "%.1f", game.freeThrowPercentage * 100))%)
        Overall FG: \(game.fg2m + game.fg3m)/\(game.fg2a + game.fg3a) (\(String(format: "%.1f", game.fieldGoalPercentage * 100))%)

        SCORING:
        ────────
        Total Points: \(game.points)
        Points from 2PT: \(game.fg2m * 2)
        Points from 3PT: \(game.fg3m * 3)
        Points from FT: \(game.ftm)

        OTHER STATS:
        ────────────
        Rebounds: \(game.rebounds)
        Assists: \(game.assists)
        Steals: \(game.steals)
        Blocks: \(game.blocks)
        Turnovers: \(game.turnovers)
        Fouls: \(game.fouls)

        GAME RESULT:
        ────────────
        \(game.teamName): \(game.myTeamScore)
        \(game.opponent): \(game.opponentScore)
        Outcome: \(game.outcome.displayName) \(game.outcome.emoji)

        PLAYING TIME:
        ─────────────
        Minutes Played: \(String(format: "%.1f", game.totalPlayingTimeMinutes))
        Total Game Time: \(String(format: "%.1f", game.totalGameTimeMinutes))
        Playing %: \(String(format: "%.1f", game.playingTimePercentage))%

        ═══════════════════════════════════════════

        """)
    }

    /// Generate markdown summary for documentation
    func generateMarkdownSummary(for game: Game) -> String {
        return """
        # Actual Stats from Elements vs Team Elite Game

        ## Video Reference
        - **YouTube URL**: https://youtu.be/z9AZQ1h8XyY?si=0iVGEN8axbBkRZax
        - **Team**: Elements
        - **Opponent**: \(game.opponent)
        - **Sahil's Jersey**: #3
        - **Jersey Color**: WHITE

        ## Actual Stats (From Database)

        ### Shooting Stats
        - **FG2M (2-Point Made)**: \(game.fg2m)
        - **FG2A (2-Point Attempted)**: \(game.fg2a)
        - **FG3M (3-Point Made)**: \(game.fg3m)
        - **FG3A (3-Point Attempted)**: \(game.fg3a)
        - **FTM (Free Throws Made)**: \(game.ftm)
        - **FTA (Free Throws Attempted)**: \(game.fta)
        - **Total Points**: \(game.points)

        ### Calculated Percentages
        - **FG% (Field Goal %)**: \(String(format: "%.1f", game.fieldGoalPercentage * 100))%
        - **2PT%**: \(String(format: "%.1f", game.twoPointPercentage * 100))%
        - **3PT%**: \(String(format: "%.1f", game.threePointPercentage * 100))%
        - **FT%**: \(String(format: "%.1f", game.freeThrowPercentage * 100))%

        ### Total Field Goals
        - **Total FGM**: \(game.fg2m + game.fg3m)
        - **Total FGA**: \(game.fg2a + game.fg3a)

        ### Other Stats
        - **Rebounds**: \(game.rebounds)
        - **Assists**: \(game.assists)
        - **Steals**: \(game.steals)
        - **Blocks**: \(game.blocks)
        - **Fouls**: \(game.fouls)
        - **Turnovers**: \(game.turnovers)

        ### Game Info
        - **Team Score**: \(game.myTeamScore)
        - **Opponent Score**: \(game.opponentScore)
        - **Outcome**: \(game.outcome.displayName) \(game.outcome.emoji)
        - **Playing Time**: \(String(format: "%.1f", game.totalPlayingTimeMinutes)) minutes
        - **Playing %**: \(String(format: "%.1f", game.playingTimePercentage))%

        ## PoC Success Criteria

        **Minimum Viable (70% accuracy target)**:
        - Detect \(Int(Double(game.fg2a + game.fg3a) * 0.7))+ out of \(game.fg2a + game.fg3a) total shots
        - Classify makes/misses with 70%+ accuracy (\(Int(Double(game.fg2m + game.fg3m) * 0.7))+ correct out of \(game.fg2m + game.fg3m) makes)

        **Good Enough to Continue (80% accuracy)**:
        - Detect \(Int(Double(game.fg2a + game.fg3a) * 0.8))+ out of \(game.fg2a + game.fg3a) total shots
        - Classify makes/misses with 80%+ accuracy

        **Production Ready (90% accuracy)**:
        - Detect \(Int(Double(game.fg2a + game.fg3a) * 0.9))+ out of \(game.fg2a + game.fg3a) total shots
        - Classify makes/misses with 90%+ accuracy

        ---

        *Retrieved from Firebase*: \(Date().formatted())
        *Game ID*: \(game.id ?? "unknown")
        """
    }
}
