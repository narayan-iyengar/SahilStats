//
//  UnifiedSystemTestView.swift
//  SahilStats
//
//  Comprehensive test view for the completely refactored connection system
//

import SwiftUI

struct UnifiedSystemTestView: View {
    @ObservedObject private var connectionManager = UnifiedConnectionManager.shared
    @ObservedObject private var navigation = NavigationCoordinator.shared
    @ObservedObject private var trustedDevices = TrustedDevicesManager.shared
    @State private var showingGameSetup = false
    @State private var testResults: [TestResult] = []
    
    struct TestResult: Identifiable {
        let id = UUID()
        let test: String
        let status: String
        let color: Color
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // System Status Overview
                    systemStatusSection
                    
                    // Connection Manager Status
                    //connectionManagerSection
                    
                    // Test Controls
                    testControlsSection
                    
                    // Test Results
                    if !testResults.isEmpty {
                        testResultsSection
                    }
                    
                    // Live Features Test
                    liveTestSection
                }
                .padding()
            }
            .navigationTitle("🔥 Unified System")
            .sheet(isPresented: $showingGameSetup) {
                GameSetupView()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("COMPLETELY REFACTORED SYSTEM")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 8) {
                Text("✅ Eliminated waiting room")
                Text("⚡ Instant background connections")  
                Text("🔄 Unified connection manager")
                Text("📱 Smart status indicator")
                Text("🧹 Cleaned up codebase")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var systemStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("System Status", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 8) {
                statusRow("Background Scanning:", connectionManager.isBackgroundScanningEnabled ? "✅ Enabled" : "❌ Disabled")
                statusRow("Connection Status:", connectionManager.connectionStatus.displayText, connectionManager.connectionStatus.color)
                statusRow("Trusted Devices:", "\(trustedDevices.trustedDeviceCount) configured", trustedDevices.hasTrustedDevices ? .green : .gray)
                statusRow("Navigation State:", navigationStateText, navigationStateColor)
                statusRow("Instant Multi-Device:", connectionManager.connectionStatus.canUseMultiDevice ? "✅ Available" : "❌ Not available")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(systemStatusColor.opacity(0.1))
                .stroke(systemStatusColor, lineWidth: 1)
        )
    }
    /*
    private var connectionManagerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Connection Manager", systemImage: "antenna.radiowaves.left.and.right")
                .font(.headline)
            
            if let connectedDevice = connectionManager.connectedDevice {
                connectedDeviceView(connectedDevice)
            } else {
                Text("No connected devices")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                statusRow("Discovered Peers:", "\(connectionManager.discoveredPeers.count)")
                statusRow("Pending Invitations:", "\(connectionManager.pendingInvitations.count)")
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
     */
    
    private func connectedDeviceView(_ device: UnifiedConnectionManager.ConnectedDevice) -> some View {
        HStack(spacing: 12) {
            Image(systemName: deviceIcon(device.role))
                .font(.title2)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Role: \(device.role.rawValue.capitalized)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Connected \(device.connectedAt, style: .relative) ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
        .padding(12)
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var testControlsSection: some View {
        VStack(spacing: 16) {
            Text("Test Controls")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                
                testButton("Test Game Setup", icon: "gamecontroller") {
                    showingGameSetup = true
                }
                
                testButton("Run Connection Test", icon: "network") {
                    runConnectionTest()
                }
                
                testButton("Force Reconnect", icon: "arrow.clockwise") {
                    connectionManager.reconnect()
                    addTestResult("Force Reconnect", "Initiated", .orange)
                }
                
                testButton("Toggle Scanning", icon: "magnifyingglass") {
                    if connectionManager.isBackgroundScanningEnabled {
                        connectionManager.disable()
                        addTestResult("Background Scanning", "Disabled", .red)
                    } else {
                        connectionManager.enable()
                        addTestResult("Background Scanning", "Enabled", .green)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var testResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Test Results")
                    .font(.headline)
                
                Spacer()
                
                Button("Clear") {
                    testResults.removeAll()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            ForEach(testResults.suffix(5)) { result in
                HStack {
                    Text(result.test)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text(result.status)
                        .font(.caption)
                        .foregroundColor(result.color)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .background(result.color.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var liveTestSection: some View {
        VStack(spacing: 12) {
            Text("🔴 Live System Test")
                .font(.headline)
                .foregroundColor(.red)
            
            Text("The new system eliminates the waiting room entirely. When you tap 'Test Game Setup', you should see:")
                .font(.subheadline)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 6) {
                testExpectation("✅ Connection indicator in top-right")
                testExpectation("⚡ Instant multi-device option when connected")
                testExpectation("🚫 No waiting room screens")
                testExpectation("🎯 Direct role selection → game flow")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
    
    // Helper Views
    private func statusRow(_ label: String, _ value: String, _ color: Color = .primary) -> some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundColor(color)
        }
        .font(.subheadline)
    }
    
    private func testButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                
                Text(title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(8)
        }
    }
    
    private func testExpectation(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    // Helper Properties
    private var systemStatusColor: Color {
        if connectionManager.connectionStatus.canUseMultiDevice {
            return .green
        } else if connectionManager.isBackgroundScanningEnabled {
            return .orange
        } else {
            return .gray
        }
    }
    
    private var navigationStateText: String {
        switch navigation.currentFlow {
        case .dashboard: return "Dashboard"
        case .liveGame: return "Live Game"
        case .gameSetup: return "Game Setup"
        case .recording: return "Recording"
        }
    }
    
    private var navigationStateColor: Color {
        switch navigation.currentFlow {
        case .dashboard: return .green
        case .liveGame: return .blue
        case .gameSetup: return .orange
        case .recording: return .red
        }
    }
    
    private func deviceIcon(_ role: DeviceRoleManager.DeviceRole) -> String {
        switch role {
        case .controller: return "gamecontroller"
        case .recorder: return "video"
        case .viewer: return "eye"
        case .none: return "questionmark"
        }
    }
    
    // Helper Methods
    private func addTestResult(_ test: String, _ status: String, _ color: Color) {
        let result = TestResult(test: test, status: status, color: color)
        testResults.append(result)
    }
    
    private func runConnectionTest() {
        addTestResult("Connection Test", "Running...", .orange)
        
        // Test background scanning
        connectionManager.startBackgroundScanning()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if connectionManager.connectionStatus.isConnected {
                addTestResult("Connection Test", "✅ Connected", .green)
            } else if connectionManager.connectionStatus == .scanning {
                addTestResult("Connection Test", "🔍 Scanning", .orange)
            } else {
                addTestResult("Connection Test", "❌ No devices", .red)
            }
        }
    }
}

#Preview {
    UnifiedSystemTestView()
}
