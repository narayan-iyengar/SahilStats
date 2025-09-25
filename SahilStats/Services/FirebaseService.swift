// File: SahilStats/Services/FirebaseService.swift (Fixed)

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine
import Network

class FirebaseService: ObservableObject {
    static let shared = FirebaseService()
    
    @Published var games: [Game] = []
    @Published var teams: [Team] = []
    @Published var liveGames: [LiveGame] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var connectionState: ConnectionState = .unknown
    
    private let db = Firestore.firestore()
    private var gamesListener: ListenerRegistration?
    private var teamsListener: ListenerRegistration?
    private var liveGamesListener: ListenerRegistration?
    
    // Network monitoring
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
    // Retry mechanism
    private var retryTimer: Timer?
    private var retryCount = 0
    private let maxRetries = 3
    
    enum ConnectionState {
        case unknown
        case connecting
        case connected
        case disconnected
        case error
    }
    
    private init() {
        configureFirestore()
        setupNetworkMonitoring()
    }
    
    // MARK: - Enhanced Configuration
    
    private func configureFirestore() {
        // Enhanced Firestore settings
        let settings = FirestoreSettings()
        
        // Enable offline persistence
        settings.isPersistenceEnabled = true
        
        // Set cache size (100MB)
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        
        // Set host (useful for debugging)
        // settings.host = "firestore.googleapis.com"
        
        db.settings = settings
        
        // Enable network logging in debug mode
        #if DEBUG
        print("🔍 Firebase debug mode enabled")
        #endif
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    print("✅ Network connection restored")
                    self?.connectionState = .connected
                    self?.handleNetworkReconnection()
                } else {
                    print("❌ Network connection lost")
                    self?.connectionState = .disconnected
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    private func handleNetworkReconnection() {
        // Restart listeners after network reconnection
        if gamesListener == nil && teamsListener == nil && liveGamesListener == nil {
            // Only restart if we were previously listening
            startListening()
        }
    }
    
    // MARK: - Enhanced Listener Setup with Error Handling
    
    func startListening() {
        connectionState = .connecting
        retryCount = 0
        
        setupGamesListenerWithRetry()
        setupTeamsListenerWithRetry()
        setupLiveGamesListenerWithRetry()
    }
    
    func stopListening() {
        print("🔄 Stopping all Firestore listeners...")
        
        gamesListener?.remove()
        gamesListener = nil
        
        teamsListener?.remove()
        teamsListener = nil
        
        liveGamesListener?.remove()
        liveGamesListener = nil
        
        retryTimer?.invalidate()
        retryTimer = nil
        
        connectionState = .disconnected
    }
    
    // MARK: - Games Listener with Enhanced Error Handling
    
    private func setupGamesListenerWithRetry() {
        gamesListener = db.collection("games")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener(includeMetadataChanges: false) { [weak self] snapshot, error in
                self?.handleGamesSnapshot(snapshot: snapshot, error: error)
            }
    }
    
    private func handleGamesSnapshot(snapshot: QuerySnapshot?, error: Error?) {
        if let error = error {
            handleListenerError(error: error, listenerType: "Games") {
                self.setupGamesListenerWithRetry()
            }
            return
        }
        
        guard let documents = snapshot?.documents else {
            print("⚠️ Games snapshot is nil")
            return
        }
        
        let newGames = documents.compactMap { document -> Game? in
            do {
                var game = try document.data(as: Game.self)
                game.id = document.documentID
                return game
            } catch {
                print("❌ Error decoding game \(document.documentID): \(error)")
                // Log the problematic document data for debugging
                print("📄 Document data: \(document.data())")
                return nil
            }
        }
        
        DispatchQueue.main.async {
            self.games = newGames
            self.connectionState = .connected
            self.retryCount = 0
            print("✅ Games loaded successfully: \(newGames.count) games")
        }
    }
    
    // MARK: - Teams Listener with Enhanced Error Handling
    
    private func setupTeamsListenerWithRetry() {
        teamsListener = db.collection("teams")
            .order(by: "name")
            .addSnapshotListener(includeMetadataChanges: false) { [weak self] snapshot, error in
                self?.handleTeamsSnapshot(snapshot: snapshot, error: error)
            }
    }
    
    private func handleTeamsSnapshot(snapshot: QuerySnapshot?, error: Error?) {
        if let error = error {
            handleListenerError(error: error, listenerType: "Teams") {
                self.setupTeamsListenerWithRetry()
            }
            return
        }
        
        guard let documents = snapshot?.documents else {
            print("⚠️ Teams snapshot is nil")
            return
        }
        
        let newTeams = documents.compactMap { document -> Team? in
            do {
                var team = try document.data(as: Team.self)
                team.id = document.documentID
                return team
            } catch {
                print("❌ Error decoding team \(document.documentID): \(error)")
                return nil
            }
        }
        
        DispatchQueue.main.async {
            self.teams = newTeams
            print("✅ Teams loaded successfully: \(newTeams.count) teams")
        }
    }
    
    // MARK: - Live Games Listener with Enhanced Error Handling
    
    private func setupLiveGamesListenerWithRetry() {
        liveGamesListener = db.collection("liveGames")
            .addSnapshotListener(includeMetadataChanges: false) { [weak self] snapshot, error in
                self?.handleLiveGamesSnapshot(snapshot: snapshot, error: error)
            }
    }
    
    private func handleLiveGamesSnapshot(snapshot: QuerySnapshot?, error: Error?) {
        if let error = error {
            handleListenerError(error: error, listenerType: "LiveGames") {
                self.setupLiveGamesListenerWithRetry()
            }
            return
        }
        
        guard let documents = snapshot?.documents else {
            print("⚠️ LiveGames snapshot is nil")
            return
        }
        
        let newLiveGames = documents.compactMap { document -> LiveGame? in
            do {
                var liveGame = try document.data(as: LiveGame.self)
                liveGame.id = document.documentID
                return liveGame
            } catch {
                print("❌ Error decoding live game \(document.documentID): \(error)")
                print("📄 Document data: \(document.data())")
                return nil
            }
        }
        
        DispatchQueue.main.async {
            self.liveGames = newLiveGames
            print("✅ Live games loaded successfully: \(newLiveGames.count) games")
        }
    }
    
    // MARK: - Enhanced Error Handling
    
    private func handleListenerError(error: Error, listenerType: String, retryAction: @escaping () -> Void) {
        let nsError = error as NSError
        
        print("❌ \(listenerType) listener error: \(error.localizedDescription)")
        print("📊 Error domain: \(nsError.domain)")
        print("📊 Error code: \(nsError.code)")
        print("📊 Error userInfo: \(nsError.userInfo)")
        
        DispatchQueue.main.async {
            self.connectionState = .error
            self.error = "\(listenerType): \(error.localizedDescription)"
        }
        
        // Handle specific error types
        if nsError.domain == "FIRFirestoreErrorDomain" {
            switch nsError.code {
            case 14: // UNAVAILABLE
                scheduleRetry(for: listenerType, retryAction: retryAction)
            case 7: // PERMISSION_DENIED
                print("🔒 Permission denied - check Firestore rules")
            case 16: // UNAUTHENTICATED
                print("🔐 User not authenticated")
            default:
                scheduleRetry(for: listenerType, retryAction: retryAction)
            }
        } else {
            scheduleRetry(for: listenerType, retryAction: retryAction)
        }
    }
    
    private func scheduleRetry(for listenerType: String, retryAction: @escaping () -> Void) {
        guard retryCount < maxRetries else {
            print("🚫 Max retries exceeded for \(listenerType)")
            return
        }
        
        retryCount += 1
        let delay = TimeInterval(retryCount * 2) // Exponential backoff: 2s, 4s, 6s
        
        print("🔄 Scheduling retry \(retryCount)/\(maxRetries) for \(listenerType) in \(delay)s")
        
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            print("🔄 Retrying \(listenerType) listener...")
            retryAction()
        }
    }
    
    // MARK: - Enhanced Write Operations with Error Handling
    
    func addGame(_ game: Game) async throws {
        do {
            var gameData = game
            gameData.createdAt = Date()
            let _ = try await db.collection("games").addDocument(from: gameData)
            print("✅ Game added successfully")
        } catch {
            print("❌ Failed to add game: \(error)")
            throw error
        }
    }
    
    func updateLiveGame(_ liveGame: LiveGame) async throws {
        guard let id = liveGame.id else {
            throw NSError(domain: "FirebaseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Live game ID is required"])
        }
        
        do {
            try await db.collection("liveGames").document(id).setData(from: liveGame)
            print("✅ Live game updated successfully: \(id)")
        } catch {
            print("❌ Failed to update live game: \(error)")
            throw error
        }
    }
    
    // MARK: - Connection Status Helpers
    
    func forceReconnect() {
        print("🔄 Force reconnecting to Firestore...")
        stopListening()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.startListening()
        }
    }
    
    var hasActiveConnection: Bool {
        return connectionState == .connected
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
    
    // MARK: - Existing Computed Properties (already in your file)
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
    
    // MARK: - ADD THESE NEW Efficiency Metrics to CareerStats struct
    
    /// Simple NBA Efficiency Rating: (Points + Rebounds + Assists + Steals + Blocks - Turnovers - Missed FG - Missed FT) / Games
    var efficiencyRating: Double {
        guard totalGames > 0 else { return 0.0 }
        
        let positiveStats = totalPoints + totalRebounds + totalAssists + totalSteals + totalBlocks
        let missedFG = (fg2a + fg3a) - (fg2m + fg3m)
        let missedFT = fta - ftm
        let negativeStats = totalTurnovers + missedFG + missedFT
        
        return Double(positiveStats - negativeStats) / Double(totalGames)
    }
    
    /// Points Per Minute (when playing time is available)
    var pointsPerMinute: Double {
        return totalPlayingTimeMinutes > 0 ? Double(totalPoints) / totalPlayingTimeMinutes : 0.0
    }
    
    /// True Shooting Percentage - More accurate shooting metric
    var trueShootingPercentage: Double {
        let totalShots = Double(fg2a) + Double(fg3a) + (Double(fta) * 0.44)
        guard totalShots > 0 else { return 0.0 }
        return Double(totalPoints) / (2.0 * totalShots)
    }
    
    /// Effective Field Goal Percentage - Accounts for 3-pointers being worth more
    var effectiveFieldGoalPercentage: Double {
        let totalAttempted = fg2a + fg3a
        guard totalAttempted > 0 else { return 0.0 }
        let adjustedMade = Double(fg2m + fg3m) + (Double(fg3m) * 0.5) // 3-pointers get 0.5 bonus
        return adjustedMade / Double(totalAttempted)
    }
    
    /// Overall Efficiency Per Minute (for players with playing time data)
    var efficiencyPerMinute: Double {
        guard totalPlayingTimeMinutes > 0 else { return 0.0 }
        
        let positiveStats = totalPoints + totalRebounds + totalAssists + totalSteals + totalBlocks
        let missedFG = (fg2a + fg3a) - (fg2m + fg3m)
        let missedFT = fta - ftm
        let negativeStats = totalTurnovers + missedFG + missedFT
        
        return Double(positiveStats - negativeStats) / totalPlayingTimeMinutes
    }
    
    /// Simplified PER-like metric (without complex league adjustments)
    var playerEfficiencyRating: Double {
        guard totalGames > 0 else { return 0.0 }
        
        // Simplified version of PER formula focusing on per-game impact
        let fg = Double(fg2m + fg3m)
        let fga = Double(fg2a + fg3a)
        let ft = Double(ftm)
        let fta_stat = Double(fta)
        let threePM = Double(fg3m)
        let ast = Double(totalAssists)
        let reb = Double(totalRebounds)
        let stl = Double(totalSteals)
        let blk = Double(totalBlocks)
        let pf = Double(totalFouls)
        let to = Double(totalTurnovers)
        
        // Simplified PER calculation (approximation)
        let uPER = (fg * 85.91) + (stl * 53.897) + (threePM * 51.757) + (ft * 46.845) +
                   (blk * 39.190) + (pf * -17.174) + ((fga - fg) * -39.190) +
                   ((fta_stat - ft) * -20.091) + (to * -53.897) +
                   (ast * 34.677) + (reb * 14.707)
        
        return uPER / Double(totalGames)
    }
}
