// File: SahilStats/Views/Components/GameListComponents.swift

import SwiftUI

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .orange))
            Text("Loading games...")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let canCreateGames: Bool
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "basketball.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)
            
            Text("No games yet!")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Start playing to see your stats here")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if canCreateGames {
                NavigationLink("Create Your First Game") {
                    GameSetupView()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding()
    }
}

// MARK: - Admin Status Indicator
struct AdminStatusIndicator: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var connectionManager = MultipeerConnectivityManager.shared
    @State private var showingAdminMenu = false
    
    var body: some View {
        Button(action: { showingAdminMenu = true }) {
            ZStack {
                // Base admin icon with connection-aware color and pulsing
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundColor(adminIconColor)
                    .opacity(adminIconOpacity)
                    .scaleEffect(isScanning ? 1.1 : 1.0)
                    .animation(
                        isScanning ? 
                        Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) :
                        .easeInOut(duration: 0.3),
                        value: isScanning
                    )
                
                // Small gear overlay for admin feel
                Image(systemName: "gearshape.fill")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .frame(width: 10, height: 10)
                    .background(adminIconColor)
                    .clipShape(Circle())
                    .offset(x: 8, y: 6)
            }
        }
        .sheet(isPresented: $showingAdminMenu) {
            AdminMenuSheet()
                .presentationDetents([.medium])
        }
    }
    
    private var baseColor: Color {
        if authService.isSignedIn && !authService.isAnonymous {
            return .blue  // Fully signed in admin
        } else if authService.isAnonymous {
            return .orange  // Guest user
        } else {
            return .gray  // Not signed in
        }
    }
    
    private var adminIconColor: Color {
        switch connectionManager.connectionStatus {
        case .connected:
            return .green  // Connected - green
        case .scanning, .connecting, .foundTrustedDevice:
            return .orange  // Active connection attempt - orange
        case .error:
            return .red  // Error - red
        default:
            return baseColor  // Default based on auth status
        }
    }
    
    private var adminIconOpacity: Double {
        switch connectionManager.connectionStatus {
        case .scanning, .connecting:
            return 0.8  // Slightly transparent when actively connecting
        default:
            return 1.0  // Fully opaque otherwise
        }
    }
    
    private var isScanning: Bool {
        switch connectionManager.connectionStatus {
        case .scanning, .connecting:
            return true
        default:
            return false
        }
    }
}

// MARK: - Admin Menu Sheet
struct AdminMenuSheet: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var connectionManager = MultipeerConnectivityManager.shared
    @ObservedObject private var roleManager = DeviceRoleManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Connection status - more prominent
                connectionStatusCard

                // Device role selection - only show when not connected
                if !connectionManager.connectionStatus.isConnected {
                    deviceRoleToggle
                }

                // Connection actions
                connectionActionButton

                Spacer()
            }
            .padding(20)
            .navigationTitle("Multi-Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var deviceRoleToggle: some View {
        VStack(spacing: 12) {
            Text("My Role")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                // Controller button
                Button(action: {
                    roleManager.setPreferredRole(.controller)
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.title3)
                            .foregroundColor(roleManager.preferredRole == .controller ? .white : .blue)
                        Text("Control")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(roleManager.preferredRole == .controller ? .white : .primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(roleManager.preferredRole == .controller ? Color.blue : Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }

                // Recorder button
                Button(action: {
                    roleManager.setPreferredRole(.recorder)
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: "video.fill")
                            .font(.title3)
                            .foregroundColor(roleManager.preferredRole == .recorder ? .white : .orange)
                        Text("Record")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(roleManager.preferredRole == .recorder ? .white : .primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(roleManager.preferredRole == .recorder ? Color.orange : Color.orange.opacity(0.1))
                    .cornerRadius(10)
                }
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var connectionStatusCard: some View {
        VStack(spacing: 14) {
            // Status header
            HStack {
                Image(systemName: connectionIcon)
                    .font(.title2)
                    .foregroundColor(connectionManager.connectionStatus.color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(connectionTitle)
                        .font(.headline)
                    Text(connectionManager.connectionStatus.displayText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Connected device info with role switch
            if let device = connectionManager.connectedDevice {
                Divider()

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(device.name)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        HStack(spacing: 8) {
                            Image(systemName: roleManager.preferredRole == .controller ? "gamecontroller.fill" : "video.fill")
                                .font(.caption)
                                .foregroundColor(roleManager.preferredRole == .controller ? .blue : .orange)
                            Text("I'm \(roleManager.preferredRole.displayName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Role switch button - requires reconnection
                    Button(action: {
                        // Switch roles locally and reconnect
                        if let peer = connectionManager.connectedPeer {
                            print("🔄 User requested role switch - will disconnect and reconnect")
                            // Save the new roles
                            TrustedDevicesManager.shared.switchRoles(for: peer)
                            roleManager.toggleRole()
                            // Disconnect and let auto-reconnect handle it with new roles
                            connectionManager.disconnect()
                            // Auto-reconnect will kick in after 5 seconds with new roles
                        }
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(16)
        .background(connectionManager.connectionStatus.color.opacity(0.08))
        .cornerRadius(12)
    }
    
    private var connectionActionButton: some View {
        VStack(spacing: 10) {
            if connectionManager.connectionStatus.isConnected {
                // Disconnect button
                Button(action: {
                    print("🔌 Disconnecting from device")
                    connectionManager.disconnect()
                }) {
                    Text("Disconnect")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else {
                // Connect/Scan button
                Button(action: {
                    print("🔍 Starting device scan...")
                    connectionManager.startBackgroundScanning()
                }) {
                    HStack(spacing: 10) {
                        if case .scanning = connectionManager.connectionStatus {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.subheadline)
                        }

                        Text(scanButtonText)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isScanning)
            }
        }
    }
    
    // Helper properties
    private var connectionIcon: String {
        switch connectionManager.connectionStatus {
        case .scanning: return "antenna.radiowaves.left.and.right"
        case .foundTrustedDevice: return "dot.radiowaves.left.and.right"
        case .connecting: return "antenna.radiowaves.left.and.right"
        case .connected: return "link.circle.fill"
        case .unavailable: return "questionmark.circle"
        case .disabled: return "power"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
    
    private var connectionTitle: String {
        switch connectionManager.connectionStatus {
        case .scanning: return "Scanning for Devices"
        case .foundTrustedDevice: return "Device Found"
        case .connecting: return "Connecting"
        case .connected: return "Connected"
        case .unavailable: return "No Devices Available"
        case .disabled: return "Background Scanning Disabled"
        case .error: return "Connection Error"
        }
    }
    
    private var scanButtonText: String {
        switch connectionManager.connectionStatus {
        case .scanning: return "Scanning..."
        default: return "Scan for Devices"
        }
    }
    
    private var isScanning: Bool {
        switch connectionManager.connectionStatus {
        case .scanning: return true
        default: return false
        }
    }
}

// MARK: - Enhanced User Status Indicator
struct UserStatusIndicator: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        Image(systemName: statusIcon)
            .foregroundColor(statusColor)
            .font(.body) // Make it bigger
            .frame(width: 24, height: 24) // Fixed frame for consistent centering
            .background(statusColor.opacity(0.1))
            .clipShape(Circle())
    }
    
    private var statusIcon: String {
        if authService.isSignedIn && !authService.isAnonymous {
            return "person.crop.circle.fill"
        } else if authService.isAnonymous {
            return "person.crop.circle"
        } else {
            return "person.crop.circle.badge.xmark"
        }
    }
    
    private var statusColor: Color {
        if authService.isSignedIn && !authService.isAnonymous {
            return .green
        } else if authService.isAnonymous {
            return .orange
        } else {
            return .red
        }
    }
    
    private var statusText: String {
        if authService.isSignedIn && !authService.isAnonymous {
            return authService.userRole.displayName
        } else if authService.isAnonymous {
            return "Guest"
        } else {
            return "Not Signed In"
        }
    }
}



// MARK: - Live Game Button
struct LiveGameButton: View {
    let action: () -> Void
    var liveGame: LiveGame? = nil

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                // Pulsing red circle
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .opacity(0.8)
                    .animation(.easeInOut(duration: 1).repeatForever(), value: true)

                Text("LIVE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.red.opacity(0.1))
            .cornerRadius(12)
        }
    }
}


// MARK: - Game Delete Alert
struct GameDeleteAlert: View {
    @Binding var gameToDelete: Game?
    let onDelete: (Game) -> Void
    
    var body: some View {
        Group {
            Button("Cancel", role: .cancel) {
                gameToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let game = gameToDelete {
                    onDelete(game)
                }
                gameToDelete = nil
            }
        }
    }
}

// MARK: - Reusable Dismiss Button
struct DismissButton: View {
    let action: () -> Void
    let isIPad: Bool
    
    init(action: @escaping () -> Void, isIPad: Bool = false) {
        self.action = action
        self.isIPad = isIPad
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: isIPad ? 20 : 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: isIPad ? 44 : 40, height: isIPad ? 44 : 40)
                .background(.ultraThinMaterial, in: Circle())
        }
    }
}
