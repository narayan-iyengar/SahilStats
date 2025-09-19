// File: SahilStats/Services/AuthService.swift (Enhanced with Firebase Auth)

import Foundation
import FirebaseAuth
import GoogleSignIn
import FirebaseCore
import Combine

class AuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isSignedIn = false
    @Published var isAdmin = false
    @Published var userRole: UserRole = .guest
    @Published var isLoading = true
    @Published var authError: AuthError?
    
    // Admin email addresses from your PWA
    private let adminEmails = [
        "niyengar@gmail.com",
        "goofygal1@gmail.com",
        "maighnaj@gmail.com",
        "syon.iyengar@gmail.com"
    ]
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
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
    
    enum AuthError: LocalizedError, Equatable {
        case signInCancelled
        case accessDenied
        case networkError
        case invalidCredentials
        case emailAlreadyInUse
        case weakPassword
        case tooManyRequests
        case userNotFound
        case unknownError(String)
        
        var errorDescription: String? {
            switch self {
            case .signInCancelled:
                return "Sign-in was cancelled"
            case .accessDenied:
                return "Access denied. Only family administrators can sign in."
            case .networkError:
                return "Network error. Please check your connection."
            case .invalidCredentials:
                return "Invalid email or password. Please try again."
            case .emailAlreadyInUse:
                return "An account with this email already exists."
            case .weakPassword:
                return "Password should be at least 6 characters long."
            case .tooManyRequests:
                return "Too many failed attempts. Please try again later."
            case .userNotFound:
                return "No account found with this email address."
            case .unknownError(let message):
                return "An error occurred: \(message)"
            }
        }
    }
    
    init() {
        // Configure Google Sign-In
        setupGoogleSignIn()
        
        // Listen to Firebase auth state changes
        setupAuthStateListener()
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupGoogleSignIn() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("Error: Could not find GoogleService-Info.plist or CLIENT_ID")
            return
        }
        
        guard let app = FirebaseApp.app() else {
            print("Error: Firebase not configured")
            return
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
    }
    
    private func setupAuthStateListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
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
            // Clear any previous errors
            await MainActor.run {
                self.authError = nil
            }
            
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            
            // Check if user is admin
            if !checkAdminStatus(result.user.email) {
                try await signOut()
                throw AuthError.accessDenied
            }
            
        } catch let error as AuthError {
            await MainActor.run {
                self.authError = error
            }
            throw error
        } catch {
            let authError = mapFirebaseError(error)
            await MainActor.run {
                self.authError = authError
            }
            throw authError
        }
    }
    
    func createAccount(email: String, password: String) async throws {
        // Only allow account creation for admin emails
        guard checkAdminStatus(email) else {
            let error = AuthError.accessDenied
            await MainActor.run {
                self.authError = error
            }
            throw error
        }
        
        do {
            await MainActor.run {
                self.authError = nil
            }
            
            _ = try await Auth.auth().createUser(withEmail: email, password: password)
            // User will be automatically signed in
            
        } catch {
            let authError = mapFirebaseError(error)
            await MainActor.run {
                self.authError = authError
            }
            throw authError
        }
    }
    
    func signInWithGoogle() async throws {
        guard let presentingViewController = await MainActor.run(body: {
            return UIApplication.shared.windows.first?.rootViewController
        }) else {
            throw AuthError.unknownError("Could not find presenting view controller")
        }
        
        do {
            await MainActor.run {
                self.authError = nil
            }
            
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.unknownError("Failed to get ID token")
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            
            let authResult = try await Auth.auth().signIn(with: credential)
            
            // Check if user is admin
            if !checkAdminStatus(authResult.user.email) {
                try await signOut()
                throw AuthError.accessDenied
            }
            
        } catch let error as AuthError {
            await MainActor.run {
                self.authError = error
            }
            throw error
        } catch {
            let authError = mapFirebaseError(error)
            await MainActor.run {
                self.authError = authError
            }
            throw authError
        }
    }
    
    func signInAnonymously() async throws {
        do {
            await MainActor.run {
                self.authError = nil
            }
            
            _ = try await Auth.auth().signInAnonymously()
            // Anonymous users are guests by default
            
        } catch {
            let authError = mapFirebaseError(error)
            await MainActor.run {
                self.authError = authError
            }
            throw authError
        }
    }
    
    func signOut() async throws {
        do {
            // Sign out from Google if signed in
            GIDSignIn.sharedInstance.signOut()
            
            // Sign out from Firebase
            try Auth.auth().signOut()
            
            // Reset state on main thread
            await MainActor.run {
                currentUser = nil
                isSignedIn = false
                isAdmin = false
                userRole = .guest
                authError = nil
            }
            
        } catch {
            let authError = mapFirebaseError(error)
            await MainActor.run {
                self.authError = authError
            }
            throw authError
        }
    }
    
    func resetPassword(email: String) async throws {
        do {
            await MainActor.run {
                self.authError = nil
            }
            
            try await Auth.auth().sendPasswordReset(withEmail: email)
            
        } catch {
            let authError = mapFirebaseError(error)
            await MainActor.run {
                self.authError = authError
            }
            throw authError
        }
    }
    
    func deleteAccount() async throws {
        guard let user = currentUser else {
            throw AuthError.userNotFound
        }
        
        do {
            await MainActor.run {
                self.authError = nil
            }
            
            try await user.delete()
            
            // Reset state
            await MainActor.run {
                currentUser = nil
                isSignedIn = false
                isAdmin = false
                userRole = .guest
            }
            
        } catch {
            let authError = mapFirebaseError(error)
            await MainActor.run {
                self.authError = authError
            }
            throw authError
        }
    }
    
    // MARK: - Helper Methods
    
    func checkAdminStatus(_ email: String?) -> Bool {
        guard let email = email?.lowercased() else { return false }
        return adminEmails.contains(email)
    }
    
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
    
    private func mapFirebaseError(_ error: Error) -> AuthError {
        guard let authError = error as NSError? else {
            return .unknownError(error.localizedDescription)
        }
        
        switch authError.code {
        case AuthErrorCode.networkError.rawValue:
            return .networkError
        case AuthErrorCode.invalidEmail.rawValue,
             AuthErrorCode.wrongPassword.rawValue:
            return .invalidCredentials
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return .emailAlreadyInUse
        case AuthErrorCode.weakPassword.rawValue:
            return .weakPassword
        case AuthErrorCode.tooManyRequests.rawValue:
            return .tooManyRequests
        case AuthErrorCode.userNotFound.rawValue:
            return .userNotFound
        case AuthErrorCode.userDisabled.rawValue:
            return .accessDenied
        default:
            return .unknownError(authError.localizedDescription)
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
    
    var currentUserEmail: String? {
        return currentUser?.email
    }
    
    var isAnonymous: Bool {
        return currentUser?.isAnonymous ?? true
    }
}
