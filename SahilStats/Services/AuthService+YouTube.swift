// File: SahilStats/Services/AuthService+YouTube.swift
// Extension to AuthService for YouTube integration

import Foundation
import FirebaseAuth
import GoogleSignIn
import FirebaseCore
import SwiftUI
import Combine

extension AuthService {
    // MARK: - YouTube Authorization Status
    
    var isYouTubeAuthorized: Bool {
        FirebaseYouTubeAuthManager.shared.isYouTubeAuthorized
    }
    
    // MARK: - Request YouTube Access
    
    func requestYouTubeAccess() async throws {
        try await FirebaseYouTubeAuthManager.shared.requestYouTubeAccess()
    }
    
    // MARK: - Enhanced Google Sign-In with YouTube Scope
    
    func signInWithGoogleForYouTube() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.invalidConfiguration
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw AuthError.noViewController
        }
        
        // Sign in with YouTube scope included
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: rootViewController,
                hint: nil,
                additionalScopes: [
                    "https://www.googleapis.com/auth/youtube.upload",
                    "https://www.googleapis.com/auth/youtube.readonly"
                ]
            )
            
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.invalidCredentials
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            
            _ = try await Auth.auth().signIn(with: credential)
            
            // Store YouTube tokens immediately
            let accessToken = result.user.accessToken.tokenString
            let refreshToken = result.user.refreshToken.tokenString
            let channelName = result.user.profile?.name
            
            try await FirebaseYouTubeAuthManager.shared.storeYouTubeTokens(
                accessToken: accessToken,
                refreshToken: refreshToken,
                channelName: channelName
            )
            
            // Update YouTube authorization status
            await MainActor.run {
                FirebaseYouTubeAuthManager.shared.checkYouTubeAuthorization()
            }
        } catch {
            print("Google Sign-In error: \(error)")
            throw error
        }
    }
}

// MARK: - Convenience Methods for Recording Flow

extension VideoRecordingManager {
    func saveRecordingAndQueueUpload(
        gameId: String,
        teamName: String,
        opponent: String
    ) async {
        // Get the current recording URL from outputURL property
        // Note: Ensure outputURL and saveToPhotoLibrary() exist on VideoRecordingManager
        guard let recordingURL = getLastRecordingURL(),
              FileManager.default.fileExists(atPath: recordingURL.path) else {
            print("❌ No recording to queue")
            return
        }
        
        // Save to photo library first
        await saveToPhotoLibrary()
        
        // Generate metadata
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        let title = "🏀 \(teamName) vs \(opponent) - \(dateFormatter.string(from: Date()))"
        let description = """
        Live game recording
        \(teamName) vs \(opponent)
        
        Recorded: \(dateFormatter.string(from: Date()))
        Game ID: \(gameId)
        
        🏀 SahilStats - Basketball Analytics
        """
        
        // Queue for YouTube upload
        YouTubeUploadManager.shared.queueVideoForUpload(
            videoURL: recordingURL,
            title: title,
            description: description,
            gameId: gameId
        )
        
        print("✅ Video saved and queued for YouTube upload")
    }
}

// MARK: - YouTube Settings Section

struct YouTubeSettingsSection: View {
    @StateObject private var youtubeAuth = FirebaseYouTubeAuthManager.shared
    @StateObject private var uploadManager = YouTubeUploadManager.shared
    @ObservedObject private var wifiMonitor = WifiNetworkMonitor.shared
    @EnvironmentObject var authService: AuthService
    
    @State private var showingUploadStatus = false
    @State private var autoUploadEnabled = true
    @State private var showingError = false
    
    var body: some View {
        Section("YouTube Uploads") {
            // Authorization status
            HStack {
                Image(systemName: youtubeAuth.isYouTubeAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(youtubeAuth.isYouTubeAuthorized ? .green : .red)
                
                Text("YouTube")
                
                Spacer()
                
                Text(youtubeAuth.isYouTubeAuthorized ? "Authorized" : "Not Authorized")
                    .foregroundColor(.secondary)
            }
            
            if !youtubeAuth.isYouTubeAuthorized {
                Button("Authorize YouTube Uploads") {
                    authorizeYouTube()
                }
                .foregroundColor(.red)
            }
            
            // Upload status
            Button(action: { showingUploadStatus = true }) {
                HStack {
                    Text("Upload Status")
                    
                    Spacer()
                    
                    if uploadManager.isUploading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if !uploadManager.pendingUploads.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.orange)
                            Text("\(uploadManager.pendingUploads.count)")
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
            
            // Auto-upload toggle
            Toggle("Auto-upload on WiFi", isOn: $autoUploadEnabled)
                .toggleStyle(SwitchToggleStyle(tint: .orange))
                .disabled(!youtubeAuth.isYouTubeAuthorized)
            
            // Network status
            HStack {
                Image(systemName: wifiMonitor.isWiFi ? "wifi" : "antenna.radiowaves.left.and.right")
                    .foregroundColor(wifiMonitor.isWiFi ? .green : .gray)
                
                Text(wifiMonitor.connectionType.displayName)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if wifiMonitor.isWiFi && !uploadManager.pendingUploads.isEmpty {
                    Text("Uploading...")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showingUploadStatus) {
            UploadStatusView()
        }
        .alert("Authorization Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(youtubeAuth.authError ?? "Failed to authorize YouTube")
        }
    }
    
    private func authorizeYouTube() {
        Task {
            do {
                print("🔍 Starting YouTube authorization")
                print("🔍 GIDSignIn currentUser: \(GIDSignIn.sharedInstance.currentUser?.profile?.email ?? "nil")")
                
                // Always use the full Google Sign-In flow to get YouTube scopes
                // Even if Firebase Auth shows signed in, we need GIDSignIn currentUser
                if GIDSignIn.sharedInstance.currentUser == nil {
                    print("📝 Need to sign in with Google for YouTube")
                    try await authService.signInWithGoogleForYouTube()
                } else {
                    print("✅ GIDSignIn user exists, requesting YouTube scope")
                    try await youtubeAuth.requestYouTubeAccess()
                }
                print("✅ YouTube authorized successfully")
            } catch {
                await MainActor.run {
                    showingError = true
                }
                print("❌ YouTube authorization failed: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    Form {
        YouTubeSettingsSection()
            .environmentObject(AuthService())
    }
}
