//
//  LocalVideoPlayerView.swift
//  SahilStats
//
//  Video player for local game recordings
//

import SwiftUI
import AVKit

struct LocalVideoPlayerView: View {
    let videoURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                if let player = player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.white)
                        Text("Loading video...")
                            .foregroundColor(.white)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        player?.pause()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.8), for: .navigationBar)
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func setupPlayer() {
        print("🎥 Setting up video player for: \(videoURL.path)")

        // Check if file exists
        if FileManager.default.fileExists(atPath: videoURL.path) {
            player = AVPlayer(url: videoURL)
            print("✅ Video player created successfully")
        } else {
            print("❌ Video file not found at: \(videoURL.path)")
        }
    }
}
