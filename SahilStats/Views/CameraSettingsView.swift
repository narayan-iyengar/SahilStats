//
//  CameraSettingsView.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 10/4/25.
//
import SwiftUI
import AVFoundation

struct CameraSettingsView: View {
    @StateObject private var videoManager = VideoRecordingManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        List {
            Section {
                MediaAccessStatus()
            } header: {
                Text("Camera Access")
            }
            
            Section {
                Picker("Quality", selection: $settingsManager.videoQuality) {
                    Text("High (1080p)").tag("High")
                    Text("Medium (720p)").tag("Medium")
                    Text("Low (480p)").tag("Low")
                }
            } header: {
                Text("Video Quality")
            } footer: {
                Text("Higher quality videos take up more storage space.")
            }
            
            Section {
                Toggle("Record Audio", isOn: .constant(true))
                    .disabled(true)
                
                Toggle("Stabilization", isOn: .constant(true))
                    .disabled(true)
            } header: {
                Text("Recording Options")
            } footer: {
                Text("Additional recording options coming soon.")
            }
        }
        .navigationTitle("Camera")
    }
}
