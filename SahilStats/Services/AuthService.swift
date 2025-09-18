// File: SahilStats/Services/AuthService.swift (Fixed)

import Foundation
import FirebaseAuth
import Combine

class AuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isSignedIn = false
    @Published var isAdmin = false
    @Published var userRole: UserRole = .guest
    @Published var isLoading = true
    
    // Admin email addresses from your PWA
    private let adminEmails = [
        "niyengar@gmail.com",
        "goofygal1@gmail.com",
        "maighnaj@gmail.com",
        "syon.iyengar@gmail.com"
    ]
    
    enum UserRole: String, CaseIterable {
        case admin = "admin"
        case viewer = "viewer"
        case guest = "guest"
        
        var displayName: String {
            switch self {
            case .admin: return "Administrator"
            case .viewer: return "Viewer"
            case .guest: return "Guest"
            }
        }
        
        var canWrite: Bool {
            return self == .admin
        }
        
        var canDelete: Bool {
            return self == .admin
        }
        
        var canAccessSettings: Bool {
            return self == .admin
        }
        
        var canManageLiveGames: Bool {
            return self == .admin
        }
    }
    
    enum AuthError: LocalizedError {
        case signInCancelled
        case accessDenied
        case networkError
        case unknownError
        
        var errorDescription: String? {
            switch self {
            case .signInCancelled:
                return "Sign-in was cancelled"
            case .accessDenied:
                return "Access denied. Only family administrators can sign in."
            case .networkError:
                return "Network error. Please check your connection."
            case .unknownError:
                return "An unknown error occurred"
            }
        }
    }
    
    init() {
        // Listen to Firebase auth state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                self?.currentUser = user
                self?.isSignedIn = user != nil && !user!.isAnonymous
                self?.updateUserRole()
                self?.isLoading = false
            }
        }
    }
    
    // MARK: - Authentication Methods
    
    func signInWithEmail(_ email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            
            // Check if user is admin
            if !checkAdminStatus(result.user.email) {
                try await signOut()
                throw AuthError.accessDenied
            }
            
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkError
        }
    }
    
    func createAccount(email: String, password: String) async throws {
        // Only allow account creation for admin emails
        guard checkAdminStatus(email) else {
            throw AuthError.accessDenied
        }
        
        do {
            _ = try await Auth.auth().createUser(withEmail: email, password: password)
            // User will be automatically signed in
        } catch {
            throw AuthError.networkError
        }
    }
    
    func signInAnonymously() async throws {
        do {
            _ = try await Auth.auth().signInAnonymously()
            // Anonymous users are guests by default
        } catch {
            throw AuthError.networkError
        }
    }
    
    func signOut() async throws {
        do {
            try Auth.auth().signOut()
            
            // Reset state on main thread
            await MainActor.run {
                currentUser = nil
                isSignedIn = false
                isAdmin = false
                userRole = .guest
            }
            
        } catch {
            throw AuthError.networkError
        }
    }
    
    func checkAdminStatus(_ email: String?) -> Bool {
        guard let email = email?.lowercased() else { return false }
        return adminEmails.contains(email)
    }
    
    // MARK: - Private Methods
    
    private func updateUserRole() {
        guard let user = currentUser else {
            userRole = .guest
            isAdmin = false
            return
        }
        
        if user.isAnonymous {
            userRole = .guest
            isAdmin = false
        } else if checkAdminStatus(user.email) {
            userRole = .admin
            isAdmin = true
        } else {
            userRole = .viewer
            isAdmin = false
        }
    }
    
    // MARK: - Permission Helpers
    
    func canPerform(_ action: AdminAction) -> Bool {
        return userRole.canWrite
    }
    
    func requireAdmin(for action: String) throws {
        guard userRole == .admin else {
            throw AuthError.accessDenied
        }
    }
    
    func showAccessDenied(for action: String) {
        print("Access denied: Only administrators can \(action)")
    }
}

enum AdminAction {
    case createGame
    case editGame
    case deleteGame
    case manageLiveGames
    case accessSettings
    case addTeam
    case deleteTeam
    
    var description: String {
        switch self {
        case .createGame: return "create games"
        case .editGame: return "edit games"
        case .deleteGame: return "delete games"
        case .manageLiveGames: return "manage live games"
        case .accessSettings: return "access settings"
        case .addTeam: return "add teams"
        case .deleteTeam: return "delete teams"
        }
    }
}

// MARK: - Extensions for UI

extension AuthService {
    var statusText: String {
        if isLoading {
            return "Loading..."
        } else if isSignedIn {
            return "Signed in as \(userRole.displayName)"
        } else {
            return "Not signed in"
        }
    }
    
    var canCreateGames: Bool {
        return userRole.canWrite
    }
    
    var canEditGames: Bool {
        return userRole.canWrite
    }
    
    var canDeleteGames: Bool {
        return userRole.canDelete
    }
    
    var showAdminFeatures: Bool {
        return userRole == .admin
    }
}
