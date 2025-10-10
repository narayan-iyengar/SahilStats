// SahilStats/Views/ConnectionWaitingRoomView.swift

import SwiftUI

struct ConnectionWaitingRoomView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var multipeer = MultipeerConnectivityManager.shared

    var body: some View {
        VStack(spacing: 20) {
            Text("Connecting...")
                .font(.largeTitle)
            
            ProgressView()
            
            Text(statusText)
                .foregroundColor(.secondary)

            Button("Cancel") {
                multipeer.stopSession()
                dismiss()
            }
            .padding(.top, 40)
        }
        .onChange(of: multipeer.connectionState) { oldState, newState in
            // Automatically dismiss when the connection is successful
            if case .connected = newState {
                dismiss()
            }
        }
    }
    
    private var statusText: String {
        switch multipeer.connectionState {
        case .searching:
            return "Searching for recorder..."
        case .connecting(let name):
            return "Connecting to \(name)..."
        case .connected:
            return "Connection successful!"
        case .idle:
            return "Canceled."
        }
    }
}
