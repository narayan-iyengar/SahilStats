// File: SahilStats/Views/AuthView.swift (Simplified - Google Sign-In Only)

import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    @State private var isSigningIn = false
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [Color(.systemBackground), Color(.systemGray6)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer(minLength: 40)
                        
                        // Logo and Title Section
                        VStack(spacing: 16) {
                            Image(systemName: "basketball.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.orange)
                                .rotationEffect(.degrees(isSigningIn ? 360 : 0))
                                .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isSigningIn)
                            
                            Text("Sahil's Stats")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                            
                            Text("Track stats, progress, and share with family.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Info Card
                        InfoCard()
                        
                        // Authentication Section
                        VStack(spacing: 16) {
                            Text("Sign In")
                                .font(.headline)
                                .foregroundColor(.orange)
                            
                            // Google Sign-In Button
                            Button(action: signInWithGoogle) {
                                HStack {
                                    if isSigningIn {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "globe")
                                            .font(.headline)
                                    }
                                    
                                    Text("Sign in with Google")
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.blue)
                                .cornerRadius(8)
                            }
                            .disabled(isSigningIn)
                            .opacity(isSigningIn ? 0.6 : 1.0)
                            
                            // Continue as Guest button
                            Button(action: continueAsGuest) {
                                Text("Continue as Guest")
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .disabled(isSigningIn)
                            
                            Text("Only family administrators can sign in")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationBarHidden(true)
            .alert("Authentication Error", isPresented: $showError) {
                Button("OK") {
                    showError = false
                }
            } message: {
                if let error = authService.authError {
                    Text(error.localizedDescription)
                }
            }
            .onChange(of: authService.authError) { _, newError in
                if newError != nil {
                    showError = true
                }
            }
        }
    }
    
    // MARK: - Info Card
    
    private func InfoCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "basketball.fill")
                    .foregroundColor(.orange)
                Text("Welcome to Sahil's Stats!")
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(icon: "eye.fill", text: "Anyone can view games and stats")
                InfoRow(icon: "person.badge.plus.fill", text: "Family admins can sign in to create and manage games")
                InfoRow(icon: "play.circle.fill", text: "No sign-in required to view live games")
            }
        }
        .padding()
        .background(Color(.systemBlue).opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemBlue).opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
    private func signInWithGoogle() {
        isSigningIn = true
        
        Task {
            do {
                try await authService.signInWithGoogle()
                await MainActor.run {
                    dismiss()
                }
            } catch {
                // Error is handled by the auth service and will trigger the alert
            }
            
            await MainActor.run {
                isSigningIn = false
            }
        }
    }
    
    private func continueAsGuest() {
        Task {
            do {
                try await authService.signInAnonymously()
                await MainActor.run {
                    dismiss()
                }
            } catch {
                // Error is handled by the auth service and will trigger the alert
            }
        }
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthService())
}
