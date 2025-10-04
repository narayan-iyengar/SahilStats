// File: SahilStats/Services/FirebaseYouTubeAuthManager.swift
// Manages YouTube OAuth tokens stored in Firebase

import Foundation
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import Combine

class FirebaseYouTubeAuthManager: ObservableObject {
    static let shared = FirebaseYouTubeAuthManager()
    
    private var db: Firestore {  // ✅ GOOD
        Firestore.firestore()
    }
    
    @Published var isYouTubeAuthorized = false
    @Published var youtubeChannelName: String?
    @Published var authError: String?
    
    private init() {
        //checkYouTubeAuthorization()
    }
    
    // MARK: - Check Authorization Status
    
    func checkYouTubeAuthorization() {
        guard let userId = Auth.auth().currentUser?.uid else {
            isYouTubeAuthorized = false
            return
        }
        
        db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            DispatchQueue.main.async {
                if let data = snapshot?.data(),
                   let hasYouTube = data["hasYouTubeAuth"] as? Bool,
                   hasYouTube {
                    self?.isYouTubeAuthorized = true
                    self?.youtubeChannelName = data["youtubeChannelName"] as? String
                } else {
                    self?.isYouTubeAuthorized = false
                }
            }
        }
    }
    
    // MARK: - Request YouTube Access
    
    func requestYouTubeAccess() async throws {
        // Get the root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw YouTubeAuthError.noViewController
        }
        
        // Request additional YouTube scopes
        let scopes = [
            "https://www.googleapis.com/auth/youtube.upload",
            "https://www.googleapis.com/auth/youtube.readonly"
        ]
        
        guard let currentUser = GIDSignIn.sharedInstance.currentUser else {
            throw YouTubeAuthError.notSignedIn
        }
        
        let result: GIDSignInResult = try await withCheckedThrowingContinuation { continuation in
            currentUser.addScopes(scopes, presenting: rootViewController) { signInResult, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let signInResult = signInResult {
                    continuation.resume(returning: signInResult)
                } else {
                    continuation.resume(throwing: YouTubeAuthError.noAccessToken)
                }
            }
        }

        // Get tokens from the result
        let accessToken = result.user.accessToken.tokenString

        let refreshToken = result.user.refreshToken.tokenString
        let channelName = result.user.profile?.name
        
        // Store in Firebase
        try await storeYouTubeTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            channelName: channelName
        )
    }
    
    // MARK: - Store YouTube Tokens
    
    func storeYouTubeTokens(
        accessToken: String,
        refreshToken: String?,
        channelName: String?
    ) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw YouTubeAuthError.notSignedIn
        }
        
        var data: [String: Any] = [
            "hasYouTubeAuth": true,
            "youtubeAccessToken": accessToken,
            "youtubeAuthTimestamp": Timestamp()
        ]
        
        if let refreshToken = refreshToken {
            data["youtubeRefreshToken"] = refreshToken
        }
        
        if let channelName = channelName {
            data["youtubeChannelName"] = channelName
        }
        
        try await db.collection("users").document(userId).setData(data, merge: true)
        
        await MainActor.run {
            self.isYouTubeAuthorized = true
            self.youtubeChannelName = channelName
        }
    }
    
    // MARK: - Get Stored Tokens
    
    func getYouTubeTokens() async throws -> (accessToken: String, refreshToken: String?) {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw YouTubeAuthError.notSignedIn
        }
        
        let snapshot = try await db.collection("users").document(userId).getDocument()
        
        guard let data = snapshot.data(),
              let accessToken = data["youtubeAccessToken"] as? String else {
            throw YouTubeAuthError.noTokensStored
        }
        
        let refreshToken = data["youtubeRefreshToken"] as? String
        
        return (accessToken, refreshToken)
    }
    
    // MARK: - Refresh Access Token
    
    func refreshAccessToken() async throws -> String {
        let (_, refreshToken) = try await getYouTubeTokens()
        
        guard let refreshToken = refreshToken else {
            throw YouTubeAuthError.noRefreshToken
        }
        
        // Use Google's token refresh endpoint
        let url = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Get client ID from GoogleService-Info.plist
        guard let clientId = getClientId() else {
            throw YouTubeAuthError.invalidConfiguration
        }
        
        let bodyParams = [
            "client_id": clientId,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        
        let bodyString = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw YouTubeAuthError.tokenRefreshFailed
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let newAccessToken = json?["access_token"] as? String else {
            throw YouTubeAuthError.tokenRefreshFailed
        }
        
        // Update stored token
        try await updateAccessToken(newAccessToken)
        
        return newAccessToken
    }
    
    private func updateAccessToken(_ token: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw YouTubeAuthError.notSignedIn
        }
        
        try await db.collection("users").document(userId).updateData([
            "youtubeAccessToken": token,
            "youtubeAuthTimestamp": Timestamp()
        ])
    }
    
    // MARK: - Revoke YouTube Access
    
    func revokeYouTubeAccess() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw YouTubeAuthError.notSignedIn
        }
        
        // Get the access token to revoke
        let (accessToken, _) = try await getYouTubeTokens()
        
        // Revoke the token with Google
        let url = URL(string: "https://oauth2.googleapis.com/revoke?token=\(accessToken)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        _ = try await URLSession.shared.data(for: request)
        
        // Remove from Firebase
        try await db.collection("users").document(userId).updateData([
            "hasYouTubeAuth": false,
            "youtubeAccessToken": FieldValue.delete(),
            "youtubeRefreshToken": FieldValue.delete(),
            "youtubeChannelName": FieldValue.delete()
        ])
        
        await MainActor.run {
            self.isYouTubeAuthorized = false
            self.youtubeChannelName = nil
        }
    }
    
    // MARK: - Helper Methods
    
    private func getClientId() -> String? {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            return nil
        }
        return clientId
    }
}

// MARK: - YouTube Auth Errors

enum YouTubeAuthError: LocalizedError {
    case notSignedIn
    case noViewController
    case noAccessToken
    case noRefreshToken
    case noTokensStored
    case tokenRefreshFailed
    case invalidConfiguration
    
    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "You must be signed in to authorize YouTube"
        case .noViewController:
            return "Unable to present authorization screen"
        case .noAccessToken:
            return "Failed to get YouTube access token"
        case .noRefreshToken:
            return "No refresh token available"
        case .noTokensStored:
            return "No YouTube tokens found. Please authorize again."
        case .tokenRefreshFailed:
            return "Failed to refresh YouTube access token"
        case .invalidConfiguration:
            return "YouTube API not properly configured"
        }
    }
}
