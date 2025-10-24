//
//  ProcessingServerSettingsView.swift
//  SahilStats
//
//  Processing server upload configuration
//

import SwiftUI

struct ProcessingServerSettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var testingConnection = false
    @State private var testResult: String?
    @State private var showingTestResult = false

    var body: some View {
        Form {
            Section {
                TextField("Server URL", text: $settingsManager.processingServerURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .placeholder(when: settingsManager.processingServerURL.isEmpty) {
                        Text("http://192.168.0.101:8000")
                            .foregroundColor(.secondary)
                    }
            } header: {
                Text("Server Endpoint")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter the URL of your processing server API.")
                        .font(.caption)

                    Text("Examples:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.top, 4)

                    Text("• MacBook Pro: http://192.168.0.101:8000")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("• Mac Mini: http://192.168.1.100:8000")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("• Localhost (testing): http://localhost:8000")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Button(action: testConnection) {
                    HStack {
                        if testingConnection {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Testing Connection...")
                                .foregroundColor(.secondary)
                        } else {
                            Image(systemName: "network")
                            Text("Test Connection")
                        }
                    }
                }
                .disabled(settingsManager.processingServerURL.isEmpty || testingConnection)
            } header: {
                Text("Connection")
            } footer: {
                if let result = testResult {
                    Text(result)
                        .font(.caption)
                        .foregroundColor(result.contains("✅") ? .green : .red)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("How It Works")
                                .font(.caption)
                                .fontWeight(.semibold)

                            Text("1. Record your game on iPhone")
                            Text("2. Video uploads to YouTube automatically")
                            Text("3. Tap 'Upload to Server' button in game details")
                            Text("4. Server processes video with professional overlays")
                            Text("5. Get your final video back!")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .listRowBackground(Color.blue.opacity(0.1))
            }
        }
        .navigationTitle("Processing Server")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func testConnection() {
        guard !settingsManager.processingServerURL.isEmpty else { return }

        testingConnection = true
        testResult = nil

        Task {
            do {
                guard let url = URL(string: "\(settingsManager.processingServerURL)/health") else {
                    throw NSError(domain: "Invalid URL", code: -1)
                }

                let (_, response) = try await URLSession.shared.data(from: url)

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    await MainActor.run {
                        testResult = "✅ Connection successful!"
                        testingConnection = false
                    }
                } else {
                    throw NSError(domain: "Invalid response", code: -1)
                }
            } catch {
                await MainActor.run {
                    testResult = "❌ Connection failed: \(error.localizedDescription)"
                    testingConnection = false
                }
            }
        }
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    NavigationView {
        ProcessingServerSettingsView()
    }
}
