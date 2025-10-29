//
//  PhotosVideoPlayerView.swift
//  SahilStats
//
//  Video player that supports both Photos library assets and file URLs
//

import SwiftUI
import AVKit
import Photos

struct PhotosVideoPlayerView: View {
    let photosAssetId: String?
    let videoURL: URL?

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var errorMessage: String?

    init(photosAssetId: String) {
        self.photosAssetId = photosAssetId
        self.videoURL = nil
    }

    init(videoURL: URL) {
        self.photosAssetId = nil
        self.videoURL = videoURL
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                if let player = player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        Text("Error Loading Video")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
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
                    .padding(.leading, 8)
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
        if let assetId = photosAssetId {
            // Load from Photos library
            debugPrint("🎥 Loading video from Photos library: \(assetId)")
            loadVideoFromPhotos(assetId: assetId)
        } else if let url = videoURL {
            // Load from file URL
            debugPrint("🎥 Loading video from URL: \(url.path)")
            loadVideoFromURL(url: url)
        } else {
            errorMessage = "No video source provided"
        }
    }

    private func loadVideoFromPhotos(assetId: String) {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)

        guard let asset = fetchResult.firstObject else {
            forcePrint("❌ Photos asset not found: \(assetId)")
            errorMessage = "Video not found in Photos library"
            return
        }

        debugPrint("✅ Found Photos asset, requesting video...")

        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
            DispatchQueue.main.async {
                if let avAsset = avAsset {
                    debugPrint("✅ Video loaded from Photos library")
                    self.player = AVPlayer(playerItem: AVPlayerItem(asset: avAsset))
                } else {
                    forcePrint("❌ Failed to load video from Photos")
                    self.errorMessage = "Unable to load video from Photos library"
                }
            }
        }
    }

    private func loadVideoFromURL(url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            player = AVPlayer(url: url)
            forcePrint("✅ Video player created from URL")
        } else {
            forcePrint("❌ Video file not found at: \(url.path)")
            errorMessage = "Video file not found"
        }
    }
}
