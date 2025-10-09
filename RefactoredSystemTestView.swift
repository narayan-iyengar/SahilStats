//
//  RefactoredSystemTestView.swift
//  SahilStats
//
//  Test view for the new background connection system and eliminated waiting room
//

import SwiftUI

struct RefactoredSystemTestView: View {
    @ObservedObject private var connectionManager = UnifiedConnectionManager.shared
    @ObservedObject private var navigation = NavigationCoordinator.shared
    @ObservedObject private var multipeer = MultipeerConnectivityManager.shared
    @State private var showingGameSetup = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection
                    
                    // Background Connection Status
                    connectionStatusSection
                    
                    // Navigation State
                    navigationStateSection
                    
                    // Multipeer Status
                    multipeerStateSection
                    
                    // Test Actions
                    testActionsSection
                    
                    // Summary
                    summarySection
                }
                .padding()
            }
            .navigationTitle("System Test")
            .sheet(isPresented: $showingGameSetup) {
                GameSetupView()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("Background Connection System Test")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("This view tests the new system where:\n• Devices connect automatically in background\n• Waiting room is eliminated\n• Multi-device setup is instant")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var connectionStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Connection Manager", systemImage: "antenna.radiowaves.left.and.right")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                statusRow("Status:", connectionManager.connectionStatus.displayText, statusColor)
                statusRow("Can Use Multi-Device:", connectionManager.connectionStatus.canUseMultiDevice ? "Yes" : "No", 
                         connectionManager.connectionStatus.canUseMultiDevice ? .green : .red)
                
                if let device = connectionManager.connectedDevice {
                    statusRow("Connected Device:", device.name, .green)
                    statusRow("Device Role:", device.role.rawValue.capitalized, .blue)
                    statusRow("Connected:", "\(device.connectedAt) ago", .secondary)
                }
                
                statusRow("Background Scanning:", connectionManager.isBackgroundScanningEnabled ? "Yes" : "No", 
                         connectionManager.isBackgroundScanningEnabled ? .green : .red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var navigationStateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Navigation Coordinator", systemImage: "map")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                statusRow("Current Flow:", flowDescription(navigation.currentFlow), .primary)
                statusRow("User Explicitly Joined:", navigation.userExplicitlyJoinedGame ? "Yes" : "No", 
                         navigation.userExplicitlyJoinedGame ? .green : .gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var multipeerStateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Multipeer Connectivity", systemImage: "network")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                statusRow("Connection State:", multipeer.connectionState.displayName, 
                         multipeer.connectionState.isConnected ? .green : .orange)
                statusRow("Connected Peers:", "\(multipeer.connectedPeers.count)", 
                         multipeer.connectedPeers.isEmpty ? .gray : .green)
                statusRow("Discovered Peers:", "\(multipeer.discoveredPeers.count)", .blue)
                statusRow("Is Browsing:", multipeer.isBrowsing ? "Yes" : "No", multipeer.isBrowsing ? .green : .gray)
                statusRow("Is Advertising:", multipeer.isAdvertising ? "Yes" : "No", multipeer.isAdvertising ? .green : .gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var testActionsSection: some View {
        VStack(spacing: 12) {
            Text("Test Actions")
                .font(.headline)
            
            VStack(spacing: 8) {
                Button("Test Game Setup Flow") {
                    showingGameSetup = true
                }
                .buttonStyle(.borderedProminent)
                
                HStack(spacing: 12) {
                    Button("Enable Background Scanning") {
                        connectionManager.enable()
                    }
                    .buttonStyle(.bordered)
                    .disabled(connectionManager.isBackgroundScanningEnabled)
                    
                    Button("Disable Background Scanning") {
                        connectionManager.disable()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!connectionManager.isBackgroundScanningEnabled)
                }
                
                Button("Force Reconnect") {
                    connectionManager.reconnect()
                }
                .buttonStyle(.bordered)
                
                Button("Return to Dashboard") {
                    navigation.returnToDashboard()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var summarySection: some View {
        VStack(spacing: 12) {
            Text("System Summary")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 6) {
                summaryItem("✅ Background scanning:", connectionManager.isBackgroundScanningEnabled ? "Active" : "Disabled")
                summaryItem("🔗 Instant connection:", connectionManager.connectionStatus.canUseMultiDevice ? "Available" : "Not available")
                summaryItem("⚡ Waiting room bypass:", connectionManager.connectionStatus.canUseMultiDevice ? "Active" : "Standard flow")
                summaryItem("📱 Status indicator:", "Visible in main dashboard")
            }
        }
        .padding()
        .background(connectionManager.connectionStatus.canUseMultiDevice ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    // Helper views
    private func statusRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundColor(color)
        }
        .font(.subheadline)
    }
    
    private func summaryItem(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Text(icon)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
    
    private var statusColor: Color {
        connectionManager.connectionStatus.color
    }
    
    private func flowDescription(_ flow: NavigationCoordinator.AppFlow) -> String {
        switch flow {
        case .dashboard: return "Dashboard"
        case .liveGame: return "Live Game"
        case .gameSetup: return "Game Setup"
        case .recording: return "Recording"
        }
    }
}

#Preview {
    RefactoredSystemTestView()
}
