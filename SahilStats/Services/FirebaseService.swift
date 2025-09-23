// File: SahilStats/Services/FirebaseService.swift (Fixed)

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class FirebaseService: ObservableObject {
    static let shared = FirebaseService()
    
    @Published var games: [Game] = []
    @Published var teams: [Team] = []
    @Published var liveGames: [LiveGame] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let db = Firestore.firestore()
    private var gamesListener: ListenerRegistration?
    private var teamsListener: ListenerRegistration?
    private var liveGamesListener: ListenerRegistration?
    
    private init() {}
    
    // MARK: - Public Methods
    
    func startListening() {
        setupGamesListener()
        setupTeamsListener()
        setupLiveGamesListener()
    }
    
    func stopListening() {
        gamesListener?.remove()
        teamsListener?.remove()
        liveGamesListener?.remove()
    }
    
    // MARK: - Games
    
    func addGame(_ game: Game) async throws {
        var gameData = game
        gameData.createdAt = Date()
        let _ = try await db.collection("games").addDocument(from: gameData)
    }
    
    func updateGame(_ game: Game) async throws {
        guard let gameId = game.id else {
            throw NSError(domain: "FirebaseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game ID is required for updates"])
        }
        
        // Create updated game with edit metadata
        var updatedGame = game
        updatedGame.editedAt = Date()
        updatedGame.editedBy = Auth.auth().currentUser?.email
        
        // Recalculate outcome based on new scores
        if updatedGame.myTeamScore > updatedGame.opponentScore {
            updatedGame.outcome = .win
        } else if updatedGame.myTeamScore < updatedGame.opponentScore {
            updatedGame.outcome = .loss
        } else {
            updatedGame.outcome = .tie
        }
        
        // Update achievements based on new stats
        updatedGame.achievements = Achievement.getEarnedAchievements(for: updatedGame)
        
        try await db.collection("games").document(gameId).setData(from: updatedGame)
        print("✅ Game updated successfully: \(gameId)")
    }
    
    func deleteGame(_ gameId: String) async throws {
        try await db.collection("games").document(gameId).delete()
    }
    
    // MARK: - Teams
    
    func addTeam(_ team: Team) async throws {
        let _ = try await db.collection("teams").addDocument(from: team)
    }
    
    func deleteTeam(_ teamId: String) async throws {
        try await db.collection("teams").document(teamId).delete()
    }
    
    // MARK: - Live Games
    
    func createLiveGame(_ liveGame: LiveGame) async throws -> String {
        let docRef = try await db.collection("liveGames").addDocument(from: liveGame)
        return docRef.documentID
    }
    
    func updateLiveGame(_ liveGame: LiveGame) async throws {
        guard let id = liveGame.id else { return }
        try await db.collection("liveGames").document(id).setData(from: liveGame)
    }
    
    func deleteLiveGame(_ liveGameId: String) async throws {
        try await db.collection("liveGames").document(liveGameId).delete()
    }
    
    func deleteAllLiveGames() async throws {
        let snapshot = try await db.collection("liveGames").getDocuments()
        for document in snapshot.documents {
            try await document.reference.delete()
        }
    }
    
    // MARK: - Real-time Listeners
    
    private func setupGamesListener() {
        gamesListener = db.collection("games")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    Task { @MainActor in
                        self.error = error.localizedDescription
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let newGames = documents.compactMap { document in
                    do {
                        var game = try document.data(as: Game.self)
                        game.id = document.documentID
                        return game
                    } catch {
                        print("Error decoding game: \(error)")
                        return nil
                    }
                }
                
                Task { @MainActor [weak self] in
                    self?.games = newGames
                }
            }
    }
    
    private func setupTeamsListener() {
        teamsListener = db.collection("teams")
            .order(by: "name")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    Task { @MainActor in
                        self.error = error.localizedDescription
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let newTeams = documents.compactMap { document in
                    do {
                        var team = try document.data(as: Team.self)
                        team.id = document.documentID
                        return team
                    } catch {
                        print("Error decoding team: \(error)")
                        return nil
                    }
                }
                
                Task { @MainActor [weak self] in
                    self?.teams = newTeams
                }
            }
    }
    
    private func setupLiveGamesListener() {
        liveGamesListener = db.collection("liveGames")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    Task { @MainActor in
                        self.error = error.localizedDescription
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let newLiveGames = documents.compactMap { document in
                    do {
                        var liveGame = try document.data(as: LiveGame.self)
                        liveGame.id = document.documentID
                        return liveGame
                    } catch {
                        print("Error decoding live game: \(error)")
                        return nil
                    }
                }
                
                Task { @MainActor [weak self] in
                    self?.liveGames = newLiveGames
                }
            }
    }
    
    // MARK: - Helper Methods
    
    func getTeam(by id: String) -> Team? {
        return teams.first { $0.id == id }
    }
    
    func getCurrentLiveGame() -> LiveGame? {
        return liveGames.first
    }
    
    var hasLiveGame: Bool {
        return !liveGames.isEmpty
    }
    
    // MARK: - Statistics Helpers
    
    func getCareerStats() -> CareerStats {
        let totalGames = games.count
        let totalPoints = games.reduce(0) { $0 + $1.points }
        let wins = games.filter { $0.outcome == .win }.count
        let averagePoints = totalGames > 0 ? Double(totalPoints) / Double(totalGames) : 0.0
        let winPercentage = totalGames > 0 ? Double(wins) / Double(totalGames) : 0.0
        
        let totalRebounds = games.reduce(0) { $0 + $1.rebounds }
        let totalAssists = games.reduce(0) { $0 + $1.assists }
        let totalSteals = games.reduce(0) { $0 + $1.steals }
        let totalBlocks = games.reduce(0) { $0 + $1.blocks }
        let totalFouls = games.reduce(0) { $0 + $1.fouls }
        let totalTurnovers = games.reduce(0) { $0 + $1.turnovers }
        
        let totalFG2M = games.reduce(0) { $0 + $1.fg2m }
        let totalFG2A = games.reduce(0) { $0 + $1.fg2a }
        let totalFG3M = games.reduce(0) { $0 + $1.fg3m }
        let totalFG3A = games.reduce(0) { $0 + $1.fg3a }
        let totalFTM = games.reduce(0) { $0 + $1.ftm }
        let totalFTA = games.reduce(0) { $0 + $1.fta }
        let totalPlayingTime = games.reduce(0) { $0 + $1.totalPlayingTimeMinutes }
        let avgPlayingTime = totalGames > 0 ? totalPlayingTime / Double(totalGames) : 0.0
        let totalGameTime = games.reduce(0) { $0 + $1.totalPlayingTimeMinutes + $1.benchTimeMinutes }
        let playingPercentage = totalGameTime > 0 ? (totalPlayingTime / totalGameTime) * 100 : 0

        
        return CareerStats(
            totalGames: totalGames,
            totalPoints: totalPoints,
            averagePoints: averagePoints,
            wins: wins,
            winPercentage: winPercentage,
            totalRebounds: totalRebounds,
            totalAssists: totalAssists,
            totalSteals: totalSteals,
            totalBlocks: totalBlocks,
            totalFouls: totalFouls,
            totalTurnovers: totalTurnovers,
            fg2m: totalFG2M,
            fg2a: totalFG2A,
            fg3m: totalFG3M,
            fg3a: totalFG3A,
            ftm: totalFTM,
            fta: totalFTA,
            totalPlayingTimeMinutes: totalPlayingTime,
            averagePlayingTimePerGame: avgPlayingTime,
            playingTimePercentage: playingPercentage
        )
    }
}

// MARK: - Career Stats Model

struct CareerStats {
    let totalGames: Int
    let totalPoints: Int
    let averagePoints: Double
    let wins: Int
    let winPercentage: Double
    let totalRebounds: Int
    let totalAssists: Int
    let totalSteals: Int
    let totalBlocks: Int
    let totalFouls: Int
    let totalTurnovers: Int
    let fg2m: Int
    let fg2a: Int
    let fg3m: Int
    let fg3a: Int
    let ftm: Int
    let fta: Int
    let totalPlayingTimeMinutes: Double
    let averagePlayingTimePerGame: Double
    let playingTimePercentage: Double
    
    var fieldGoalPercentage: Double {
        let totalMade = fg2m + fg3m
        let totalAttempted = fg2a + fg3a
        return totalAttempted > 0 ? Double(totalMade) / Double(totalAttempted) : 0.0
    }
    
    var freeThrowPercentage: Double {
        return fta > 0 ? Double(ftm) / Double(fta) : 0.0
    }
    
    var twoPointPercentage: Double {
        return fg2a > 0 ? Double(fg2m) / Double(fg2a) : 0.0
    }
    
    var threePointPercentage: Double {
        return fg3a > 0 ? Double(fg3m) / Double(fg3a) : 0.0
    }
    
    var assistTurnoverRatio: Double {
        return totalTurnovers > 0 ? Double(totalAssists) / Double(totalTurnovers) : Double(totalAssists)
    }
}
