//
//  UnifiedConnectionStatusIndicator.swift
//  SahilStats
//
//  Streamlined connection status indicator for the unified connection system
//

import SwiftUI

struct UnifiedConnectionStatusIndicator: View {
    @ObservedObject private var connectionManager = UnifiedConnectionManager.shared
    @State private var showingDetails = false
    
    var body: some View {
        Button(action: { showingDetails = true }) {
            Image(systemName: connectionIcon)
                .foregroundColor(connectionManager.connectionStatus.color)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(connectionManager.connectionStatus.color.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetails) {
            ConnectionDetailsSheet()
                .presentationDetents([.height(350)])
        }
        .opacity(shouldShowIndicator ? 1 : 0)
    }
    
    private var isConnectionDisabled: Bool {
        if case .disabled = connectionManager.connectionStatus {
            return true
        }
        return false
    }
    
    private var shouldShowIndicator: Bool {
        // Only show when connected - hide scanning/connecting to prevent global antenna icons
        switch connectionManager.connectionStatus {
        case .connected:
            return true
        default:
            return false
        }
    }
    
    private var connectionIcon: String {
        switch connectionManager.connectionStatus {
        case .scanning:
            return "antenna.radiowaves.left.and.right"
        case .foundTrustedDevice:
            return "dot.radiowaves.left.and.right"
        case .connecting:
            return "antenna.radiowaves.left.and.right"
        case .connected:
            return "link.circle.fill"  // Chain link - represents "connected"
        case .unavailable:
            return "circle"  // Simple empty circle - much more subtle
        case .disabled:
            return "power"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Connection Details Sheet
struct ConnectionDetailsSheet: View {
    @ObservedObject private var connectionManager = UnifiedConnectionManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Current Status
                currentStatusCard
                
                // Connected Device Info
                if let device = connectionManager.connectedDevice {
                    connectedDeviceCard(device)
                }
                
                // Control Actions
                controlActions
                
                Spacer()
            }
            .padding()
            .navigationTitle("Connection Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var currentStatusCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: connectionIcon)
                    .font(.title2)
                    .foregroundColor(connectionManager.connectionStatus.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(.headline)
                    
                    Text(connectionManager.connectionStatus.displayText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Text(statusDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func connectedDeviceCard(_ device: UnifiedConnectionManager.ConnectedDevice) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected Device")
                .font(.headline)
            
            HStack(spacing: 12) {
                Image(systemName: deviceRoleIcon(device.role))
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Role: \(device.role.rawValue.capitalized)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Connected")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(device.connectedAt.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var controlActions: some View {
        VStack(spacing: 12) {
            Text("Actions")
                .font(.headline)
            
            VStack(spacing: 8) {
                if connectionManager.connectionStatus.isConnected {
                    Button("Disconnect") {
                        connectionManager.disconnect()
                    }
                    .buttonStyle(.bordered)
                } else if !isCurrentlyScanning {
                    Button("Scan for Devices") {
                        connectionManager.startBackgroundScanning()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Button("Reconnect") {
                    connectionManager.reconnect()
                }
                .buttonStyle(.bordered)
                
                Button(connectionManager.isBackgroundScanningEnabled ? "Disable Background Scanning" : "Enable Background Scanning") {
                    if connectionManager.isBackgroundScanningEnabled {
                        connectionManager.disable()
                    } else {
                        connectionManager.enable()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var isCurrentlyScanning: Bool {
        if case .scanning = connectionManager.connectionStatus {
            return true
        }
        return false
    }
    
    // Helper properties
    private var connectionIcon: String {
        switch connectionManager.connectionStatus {
        case .scanning: return "magnifyingglass"
        case .foundTrustedDevice: return "dot.radiowaves.left.and.right"
        case .connecting: return "antenna.radiowaves.left.and.right"
        case .connected: return "checkmark.circle.fill"
        case .unavailable: return "exclamationmark.triangle"
        case .disabled: return "power"
        case .error: return "xmark.circle"
        }
    }
    
    private var statusTitle: String {
        switch connectionManager.connectionStatus {
        case .scanning: return "Scanning for Devices"
        case .foundTrustedDevice: return "Trusted Device Found"
        case .connecting: return "Connecting"
        case .connected: return "Connected"
        case .unavailable: return "No Devices Available"
        case .disabled: return "Background Scanning Disabled"
        case .error: return "Connection Error"
        }
    }
    
    private var statusDescription: String {
        switch connectionManager.connectionStatus {
        case .scanning:
            return "Looking for trusted devices nearby. This may take up to 10 seconds."
        case .foundTrustedDevice(let name):
            return "Found trusted device '\(name)'. Attempting to connect..."
        case .connecting(let name):
            return "Establishing connection with '\(name)'..."
        case .connected(let name):
            return "Successfully connected to '\(name)'. Multi-device features are now available."
        case .unavailable:
            return "No trusted devices found nearby. Multi-device features are not available."
        case .disabled:
            return "Background device scanning is disabled. Enable it to use multi-device features."
        case .error(let message):
            return "Connection failed: \(message). You can try scanning again."
        }
    }
    
    private func deviceRoleIcon(_ role: DeviceRoleManager.DeviceRole) -> String {
        switch role {
        case .controller: return "gamecontroller"
        case .recorder: return "video"
        case .viewer: return "eye"
        case .none: return "questionmark"
        }
    }
}
