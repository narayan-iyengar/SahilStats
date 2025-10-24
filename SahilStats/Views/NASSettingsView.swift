//
//  NASSettingsView.swift
//  SahilStats
//
//  NAS upload configuration
//

import SwiftUI

struct NASSettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var testingConnection = false
    @State private var testResult: String?
    @State private var showingTestResult = false

    var body: some View {
        Form {
            Section {
                TextField("NAS URL", text: $settingsManager.nasUploadURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .placeholder(when: settingsManager.nasUploadURL.isEmpty) {
                        Text("http://192.168.1.x:8000")
                            .foregroundColor(.secondary)
                    }
            } header: {
                Text("Upload Endpoint")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter the URL of your NAS API endpoint.")
                        .font(.caption)

                    Text("Examples:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.top, 4)

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
                .disabled(settingsManager.nasUploadURL.isEmpty || testingConnection)
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
                            Text("3. Tap 'Upload to NAS' button")
                            Text("4. NAS processes video with professional overlays")
                            Text("5. Get final video back!")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .listRowBackground(Color.blue.opacity(0.1))
            }
        }
        .navigationTitle("NAS Upload")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func testConnection() {
        guard !settingsManager.nasUploadURL.isEmpty else { return }

        testingConnection = true
        testResult = nil

        Task {
            do {
                guard let url = URL(string: "\(settingsManager.nasUploadURL)/health") else {
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
        NASSettingsView()
    }
}
