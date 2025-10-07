// ConnectionWaitingRoomView.swift - REFACTORED

import SwiftUI
import MultipeerConnectivity
import Combine

struct ConnectionWaitingRoomView: View {
    let role: DeviceRoleManager.DeviceRole
    
    @StateObject private var multipeer = MultipeerConnectivityManager.shared
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            LottieView(name: "connection-animation")
                .frame(width: isIPad ? 250 : 180, height: isIPad ? 250 : 180)
            
            VStack(spacing: 12) {
                if multipeer.connectionState.isConnected {
                    Text("Connected & Ready!")
                        .font(isIPad ? .title : .title2)
                        .fontWeight(.bold)
                    Text("Waiting for controller to start the game...")
                        .font(isIPad ? .body : .subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("Connecting...")
                        .font(isIPad ? .title : .title2)
                        .fontWeight(.bold)
                    Text(role == .controller ? "Searching for recorder..." : "Waiting for controller...")
                        .font(isIPad ? .body : .subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            
            if multipeer.connectionState.isConnected, let peer = multipeer.connectedPeers.first {
                Text("Connected to \(peer.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Spacer()
            
            Button("Cancel") {
                // Tell the manager to reset the entire state machine
                LiveGameManager.shared.reset()
            }
            .buttonStyle(UnifiedSecondaryButtonStyle(isIPad: isIPad))
            .padding(.horizontal, 40)
        }
        .padding()
    }
}
