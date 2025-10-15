//
//  CameraSettingsView.swift
//  SahilStats
//
//  Advanced camera settings for professional video recording
//
import SwiftUI
import AVFoundation

struct CameraSettingsView: View {
    @StateObject private var settingsManager = CameraSettingsManager.shared
    @State private var showCustomBitrate = false
    @State private var customBitrateString = ""

    var body: some View {
        Form {
            // MARK: - Video Quality

            Section {
                Picker("Resolution", selection: $settingsManager.settings.resolution) {
                    ForEach(CameraSettings.VideoResolution.allCases, id: \.self) { resolution in
                        HStack {
                            Text(resolution.displayName)
                            Spacer()
                            if !isResolutionSupported(resolution) {
                                Text("Not supported")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tag(resolution)
                    }
                }
                .disabled(!isResolutionSupported(settingsManager.settings.resolution))

                Picker("Frame Rate", selection: $settingsManager.settings.frameRate) {
                    ForEach(CameraSettings.FrameRate.allCases, id: \.self) { frameRate in
                        Text(frameRate.displayName).tag(frameRate)
                    }
                }

                Picker("Codec", selection: $settingsManager.settings.codec) {
                    ForEach(CameraSettings.VideoCodec.allCases, id: \.self) { codec in
                        Text(codec.displayName).tag(codec)
                    }
                }

            } header: {
                Text("Video Quality")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if settingsManager.settings.resolution == .uhd4K {
                        Text("4K provides the highest quality for professional results and enables future AI auto-tracking features.")
                    } else {
                        Text("Higher resolutions provide better quality but larger file sizes.")
                    }

                    if settingsManager.settings.codec == .hevc {
                        Text("HEVC (H.265) offers better compression than H.264, reducing file sizes by up to 50% with the same quality.")
                            .padding(.top, 4)
                    }
                }
            }

            // MARK: - Bitrate

            Section {
                HStack {
                    Text("Bitrate")
                    Spacer()
                    if let custom = settingsManager.settings.customBitrate {
                        Text("\(String(format: "%.1f", Double(custom) / 1_000_000)) Mbps (Custom)")
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(String(format: "%.1f", settingsManager.settings.bitrateInMbps)) Mbps (Default)")
                            .foregroundColor(.secondary)
                    }
                }

                Toggle("Use Custom Bitrate", isOn: $showCustomBitrate)
                    .onChange(of: showCustomBitrate) { _, newValue in
                        if !newValue {
                            settingsManager.settings.customBitrate = nil
                            customBitrateString = ""
                        } else {
                            customBitrateString = String(Int(settingsManager.settings.bitrateInMbps))
                        }
                    }

                if showCustomBitrate {
                    HStack {
                        TextField("Bitrate (Mbps)", text: $customBitrateString)
                            .keyboardType(.numberPad)
                            .onChange(of: customBitrateString) { _, newValue in
                                if let mbps = Int(newValue), mbps > 0, mbps <= 100 {
                                    settingsManager.settings.customBitrate = mbps * 1_000_000
                                }
                            }

                        Text("Mbps")
                            .foregroundColor(.secondary)
                    }
                }

            } header: {
                Text("Bitrate")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Higher bitrate = better quality but larger files.")

                    if settingsManager.settings.resolution == .uhd4K {
                        Text("Recommended for 4K: 15-30 Mbps")
                    } else if settingsManager.settings.resolution == .fullHD {
                        Text("Recommended for 1080p: 6-12 Mbps")
                    } else {
                        Text("Recommended for 720p: 3-8 Mbps")
                    }
                }
                .padding(.top, 4)
            }

            // MARK: - Camera Features

            Section {
                Toggle("Video Stabilization", isOn: $settingsManager.settings.stabilizationEnabled)

            } header: {
                Text("Camera Features")
            } footer: {
                Text("Stabilization reduces camera shake for smoother videos.")
            }

            // MARK: - Information

            Section {
                HStack {
                    Text("Resolution")
                    Spacer()
                    let dims = settingsManager.settings.resolution.dimensions
                    Text("\(dims.width) × \(dims.height)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Est. File Size (1 min)")
                    Spacer()
                    Text(estimatedFileSizePerMinute())
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Device Support")
                    Spacer()
                    if settingsManager.validateSettings() {
                        Text("✓ Supported")
                            .foregroundColor(.green)
                    } else {
                        Text("⚠️ Limited")
                            .foregroundColor(.orange)
                    }
                }

            } header: {
                Text("Information")
            }

            // MARK: - Reset

            Section {
                Button(role: .destructive) {
                    withAnimation {
                        settingsManager.resetToDefaults()
                        showCustomBitrate = false
                        customBitrateString = ""
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text("Reset to Defaults")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Camera Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Initialize custom bitrate field if set
            if let custom = settingsManager.settings.customBitrate {
                showCustomBitrate = true
                customBitrateString = String(Int(Double(custom) / 1_000_000))
            }
        }
    }

    // MARK: - Helper Methods

    private func isResolutionSupported(_ resolution: CameraSettings.VideoResolution) -> Bool {
        let session = AVCaptureSession()
        return session.canSetSessionPreset(resolution.sessionPreset)
    }

    private func estimatedFileSizePerMinute() -> String {
        // Bitrate × 60 seconds ÷ 8 bits per byte
        let bytesPerMinute = settingsManager.settings.bitrate * 60 / 8
        let megabytes = Double(bytesPerMinute) / 1_000_000

        if megabytes < 1000 {
            return String(format: "%.0f MB", megabytes)
        } else {
            return String(format: "%.1f GB", megabytes / 1000)
        }
    }
}
