//
//  AccountDetails.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 10/4/25.
//
import SwiftUI
import FirebaseAuth

struct AccountDetailsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingDeleteAlert = false
    
    var body: some View {
        List {
            Section("Account Information") {
                if let email = authService.currentUser?.email {
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(email)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("Account Type")
                    Spacer()
                    Text(authService.userRole.displayName)
                        .foregroundColor(.secondary)
                }
            }
            
            Section {
                Button("Sign Out") {
                    Task {
                        try? await authService.signOut()
                    }
                }
                .foregroundColor(.red)
            }
            
            Section {
                Button("Delete Account") {
                    showingDeleteAlert = true
                }
                .foregroundColor(.red)
            } footer: {
                Text("Deleting your account will permanently remove all your data. This action cannot be undone.")
                    .font(.caption)
            }
        }
        .navigationTitle("Account")
        .alert("Delete Account", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    try? await authService.deleteAccount()
                }
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone.")
        }
    }
}
