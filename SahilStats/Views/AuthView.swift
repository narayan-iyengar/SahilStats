// File: SahilStats/Views/AuthView.swift (Fixed)

import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSigningIn = false
    @State private var isCreatingAccount = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showCreateAccount = false
    
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
                        
                        // Sign In Form
                        VStack(spacing: 16) {
                            if showCreateAccount {
                                Text("Create Admin Account")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                            } else {
                                Text("Sign In")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                            }
                            
                            // Email Field
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Email")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                TextField("Enter admin email", text: $email)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .disabled(isSigningIn || isCreatingAccount)
                            }
                            
                            // Password Field
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Password")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                SecureField("Enter password", text: $password)
                                    .textFieldStyle(.roundedBorder)
                                    .disabled(isSigningIn || isCreatingAccount)
                            }
                            
                            // Sign In Button
                            Button(action: handlePrimaryAction) {
                                HStack {
                                    if isSigningIn || isCreatingAccount {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    }
                                    
                                    Text(showCreateAccount ? "Create Account" : "Sign In")
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.orange)
                                .cornerRadius(8)
                            }
                            .disabled(isSigningIn || isCreatingAccount || email.isEmpty || password.isEmpty)
                            .opacity((isSigningIn || isCreatingAccount || email.isEmpty || password.isEmpty) ? 0.6 : 1.0)
                            
                            // Toggle between sign in and create account
                            Button(action: {
                                showCreateAccount.toggle()
                            }) {
                                Text(showCreateAccount ? "Already have an account? Sign In" : "Need an account? Create One")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .disabled(isSigningIn || isCreatingAccount)
                            
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
                            .disabled(isSigningIn || isCreatingAccount)
                            
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
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func handlePrimaryAction() {
        if showCreateAccount {
            createAccount()
        } else {
            signIn()
        }
    }
    
    private func signIn() {
        isSigningIn = true
        
        Task {
            do {
                try await authService.signInWithEmail(email, password: password)
                dismiss()
            } catch let error as AuthService.AuthError {
                handleAuthError(error)
            } catch {
                handleAuthError(.unknownError)
            }
            
            // Reset loading state - no need for MainActor since we're already on main thread
            isSigningIn = false
        }
    }
    
    private func createAccount() {
        isCreatingAccount = true
        
        Task {
            do {
                try await authService.createAccount(email: email, password: password)
                dismiss()
            } catch let error as AuthService.AuthError {
                handleAuthError(error)
            } catch {
                handleAuthError(.unknownError)
            }
            
            // Reset loading state - no need for MainActor since we're already on main thread
            isCreatingAccount = false
        }
    }
    
    private func continueAsGuest() {
        Task {
            do {
                try await authService.signInAnonymously()
                dismiss()
            } catch {
                handleAuthError(.networkError)
            }
        }
    }
    
    private func handleAuthError(_ error: AuthService.AuthError) {
        errorMessage = error.localizedDescription
        showError = true
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
