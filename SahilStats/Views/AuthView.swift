// File: SahilStats/Views/AuthView.swift (Enhanced with Firebase Auth)

import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSigningIn = false
    @State private var isCreatingAccount = false
    @State private var showError = false
    @State private var showCreateAccount = false
    @State private var showForgotPassword = false
    @State private var resetEmail = ""
    @State private var showResetSuccess = false
    
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
                                .rotationEffect(.degrees(isSigningIn || isCreatingAccount ? 360 : 0))
                                .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isSigningIn || isCreatingAccount)
                            
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
                        
                        // Authentication Form
                        if showForgotPassword {
                            ForgotPasswordForm()
                        } else {
                            AuthenticationForm()
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
            .alert("Password Reset", isPresented: $showResetSuccess) {
                Button("OK") {
                    showResetSuccess = false
                    showForgotPassword = false
                }
            } message: {
                Text("Password reset instructions have been sent to \(resetEmail)")
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
    
    // MARK: - Authentication Form
    
    private func AuthenticationForm() -> some View {
        VStack(spacing: 16) {
            Text(showCreateAccount ? "Create Admin Account" : "Sign In")
                .font(.headline)
                .foregroundColor(.orange)
            
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
            
            // Confirm Password Field (only for account creation)
            if showCreateAccount {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Confirm Password")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    SecureField("Confirm password", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isSigningIn || isCreatingAccount)
                }
            }
            
            // Primary Action Button
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
            .disabled(isSigningIn || isCreatingAccount || !isFormValid)
            .opacity((isSigningIn || isCreatingAccount || !isFormValid) ? 0.6 : 1.0)
            
            // Google Sign-In Button
            if !showCreateAccount {
                Button(action: signInWithGoogle) {
                    HStack {
                        Image(systemName: "globe")
                            .font(.headline)
                        
                        Text("Sign in with Google")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .disabled(isSigningIn || isCreatingAccount)
                .opacity((isSigningIn || isCreatingAccount) ? 0.6 : 1.0)
            }
            
            // Secondary Actions
            HStack(spacing: 20) {
                // Toggle between sign in and create account
                Button(action: {
                    showCreateAccount.toggle()
                    clearForm()
                }) {
                    Text(showCreateAccount ? "Already have an account? Sign In" : "Need an account? Create One")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .disabled(isSigningIn || isCreatingAccount)
                
                if !showCreateAccount {
                    Button("Forgot Password?") {
                        showForgotPassword = true
                        clearForm()
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                    .disabled(isSigningIn || isCreatingAccount)
                }
            }
            
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
    }
    
    // MARK: - Forgot Password Form
    
    private func ForgotPasswordForm() -> some View {
        VStack(spacing: 16) {
            Text("Reset Password")
                .font(.headline)
                .foregroundColor(.orange)
            
            Text("Enter your email address and we'll send you instructions to reset your password.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Email")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Enter your email", text: $resetEmail)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disabled(isSigningIn)
            }
            
            Button(action: resetPassword) {
                HStack {
                    if isSigningIn {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    
                    Text("Send Reset Instructions")
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.orange)
                .cornerRadius(8)
            }
            .disabled(isSigningIn || resetEmail.isEmpty || !isValidEmail(resetEmail))
            .opacity((isSigningIn || resetEmail.isEmpty || !isValidEmail(resetEmail)) ? 0.6 : 1.0)
            
            Button("Back to Sign In") {
                showForgotPassword = false
                resetEmail = ""
            }
            .font(.caption)
            .foregroundColor(.orange)
            .disabled(isSigningIn)
        }
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        if showCreateAccount {
            return !email.isEmpty &&
                   !password.isEmpty &&
                   !confirmPassword.isEmpty &&
                   password == confirmPassword &&
                   password.count >= 6 &&
                   isValidEmail(email)
        } else {
            return !email.isEmpty && !password.isEmpty && isValidEmail(email)
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
    
    private func createAccount() {
        guard password == confirmPassword else {
            // This should be caught by form validation, but just in case
            return
        }
        
        isCreatingAccount = true
        
        Task {
            do {
                try await authService.createAccount(email: email, password: password)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                // Error is handled by the auth service and will trigger the alert
            }
            
            await MainActor.run {
                isCreatingAccount = false
            }
        }
    }
    
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
    
    private func resetPassword() {
        isSigningIn = true
        
        Task {
            do {
                try await authService.resetPassword(email: resetEmail)
                await MainActor.run {
                    showResetSuccess = true
                }
            } catch {
                // Error is handled by the auth service and will trigger the alert
            }
            
            await MainActor.run {
                isSigningIn = false
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        resetEmail = ""
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
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
