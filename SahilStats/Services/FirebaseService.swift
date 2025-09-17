// File: SahilStats/Services/FirebaseService.swift

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
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
        try await db.collection("games").addDocument(from: gameData)
    }
    
    func updateGame(_ game: Game) async throws {
        guard let id = game.id else { return }
        try await db.collection("games").document(id).setData(from: game)
    }
    
    func deleteGame(_ gameId: String) async throws {
        try await db.collection("games").document(gameId).delete()
    }
    
    // MARK: - Teams
    
    func addTeam(_ team: Team) async throws {
        try await db.collection("teams").addDocument(from: team)
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
                    self.error = error.localizedDescription
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self.games = documents.compactMap { document in
                    do {
                        var game = try document.data(as: Game.self)
                        game.id = document.documentID
                        return game
                    } catch {
                        print("Error decoding game: \(error)")
                        return nil
                    }
                }
            }
    }
    
    private func setupTeamsListener() {
        teamsListener = db.collection("teams")
            .order(by: "name")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.error = error.localizedDescription
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self.teams = documents.compactMap { document in
                    do {
                        var team = try document.data(as: Team.self)
                        team.id = document.documentID
                        return team
                    } catch {
                        print("Error decoding team: \(error)")
                        return nil
                    }
                }
            }
    }
    
    private func setupLiveGamesListener() {
        liveGamesListener = db.collection("liveGames")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.error = error.localizedDescription
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self.liveGames = documents.compactMap { document in
                    do {
                        var liveGame = try document.data(as: LiveGame.self)
                        liveGame.id = document.documentID
                        return liveGame
                    } catch {
                        print("Error decoding live game: \(error)")
                        return nil
                    }
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
            fta: totalFTA
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
