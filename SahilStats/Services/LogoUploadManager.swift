//
//  LogoUploadManager.swift
//  SahilStats
//
//  Handles team logo uploads to Firebase Storage
//

import UIKit
import FirebaseStorage
import SwiftUI
import Combine

class LogoUploadManager: ObservableObject {
    static let shared = LogoUploadManager()

    private let storage = Storage.storage()
    @MainActor @Published var isUploading = false
    @MainActor @Published var uploadProgress: Double = 0.0
    @MainActor @Published var uploadError: String?

    private init() {}

    // MARK: - Image Processing

    /// Resize image to 512x512px square (recommended size for logos)
    nonisolated func resizeImage(_ image: UIImage, to size: CGSize = CGSize(width: 512, height: 512)) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Compress image to target file size (default 200KB)
    nonisolated func compressImage(_ image: UIImage, maxSizeKB: Int = 200) -> Data? {
        var compression: CGFloat = 1.0
        var imageData = image.jpegData(compressionQuality: compression)

        // Reduce quality until we hit target size or minimum quality
        while let data = imageData, data.count > maxSizeKB * 1024, compression > 0.1 {
            compression -= 0.1
            imageData = image.jpegData(compressionQuality: compression)
        }

        // If JPEG compression isn't enough, try PNG
        if let data = imageData, data.count > maxSizeKB * 1024 {
            return image.pngData()
        }

        return imageData
    }

    // MARK: - Firebase Storage Upload

    /// Upload logo to Firebase Storage and return download URL
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - teamId: The team ID (used for storage path)
    /// - Returns: Download URL string
    func uploadTeamLogo(_ image: UIImage, teamId: String) async throws -> String {
        debugPrint("🚀 LogoUploadManager.uploadTeamLogo() started")
        debugPrint("   teamId: \(teamId)")
        debugPrint("   image size: \(image.size.width)×\(image.size.height)")

        await MainActor.run {
            isUploading = true
            uploadProgress = 0.0
            uploadError = nil
        }

        defer {
            Task { @MainActor in
                isUploading = false
                debugPrint("🏁 LogoUploadManager.uploadTeamLogo() finished - isUploading set to false")
            }
        }

        // Process image on background thread to avoid priority inversion
        let imageData = try await Task.detached(priority: .userInitiated) {
            // Resize to 512x512px
            print("🔄 Resizing image to 512×512px...")
            guard let resizedImage = self.resizeImage(image) else {
                print("❌ Image resize failed!")
                throw LogoUploadError.resizeFailed
            }
            print("✅ Image resized successfully")

            // Compress to ~200KB
            print("🗜️ Compressing image...")
            guard let imageData = self.compressImage(resizedImage) else {
                print("❌ Image compression failed!")
                throw LogoUploadError.compressionFailed
            }
            print("✅ Image compressed: \(imageData.count / 1024)KB")
            print("📤 Uploading logo - Original: \(image.size), Resized: 512×512, Compressed: \(imageData.count / 1024)KB")

            return imageData
        }.value

        // Create storage reference
        debugPrint("🔗 Creating Firebase Storage reference...")
        let storageRef = storage.reference()
        let logoPath = "logos/\(teamId).png"
        let logoRef = storageRef.child(logoPath)
        debugPrint("   Storage path: \(logoPath)")
        debugPrint("   Bucket: \(storageRef.bucket)")

        // Upload with metadata
        debugPrint("📋 Setting up metadata...")
        let metadata = StorageMetadata()
        metadata.contentType = "image/png"
        metadata.customMetadata = [
            "teamId": teamId,
            "uploadedAt": ISO8601DateFormatter().string(from: Date())
        ]

        // Upload the data
        debugPrint("☁️ Starting Firebase Storage upload...")
        do {
            let _ = try await logoRef.putDataAsync(imageData, metadata: metadata) { progress in
                if let progress = progress {
                    Task { @MainActor in
                        self.uploadProgress = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                        debugPrint("📊 Upload progress: \(Int(self.uploadProgress * 100))% (\(progress.completedUnitCount)/\(progress.totalUnitCount) bytes)")
                    }
                }
            }
            debugPrint("✅ Firebase Storage upload completed!")
        } catch {
            debugPrint("❌ Firebase Storage upload failed!")
            debugPrint("   Error: \(error)")
            debugPrint("   Error type: \(type(of: error))")
            if let nsError = error as NSError? {
                debugPrint("   Domain: \(nsError.domain)")
                debugPrint("   Code: \(nsError.code)")
                debugPrint("   User info: \(nsError.userInfo)")
            }
            throw error
        }

        // Get download URL
        debugPrint("🌐 Fetching download URL...")
        do {
            let downloadURL = try await logoRef.downloadURL()
            debugPrint("✅ Logo uploaded successfully!")
            debugPrint("   Download URL: \(downloadURL.absoluteString)")
            return downloadURL.absoluteString
        } catch {
            debugPrint("❌ Failed to get download URL!")
            debugPrint("   Error: \(error)")
            throw error
        }
    }

    /// Delete logo from Firebase Storage
    nonisolated func deleteTeamLogo(teamId: String) async throws {
        let storageRef = storage.reference()
        let logoPath = "logos/\(teamId).png"
        let logoRef = storageRef.child(logoPath)

        try await logoRef.delete()
        debugPrint("🗑️ Logo deleted: \(logoPath)")
    }
}

// MARK: - Errors

enum LogoUploadError: LocalizedError {
    case resizeFailed
    case compressionFailed
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .resizeFailed:
            return "Failed to resize image"
        case .compressionFailed:
            return "Failed to compress image"
        case .uploadFailed:
            return "Failed to upload image to server"
        }
    }
}
