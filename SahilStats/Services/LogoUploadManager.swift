//
//  LogoUploadManager.swift
//  SahilStats
//
//  Handles team logo uploads to Firebase Storage
//

import UIKit
import FirebaseStorage
import SwiftUI

@MainActor
class LogoUploadManager: ObservableObject {
    static let shared = LogoUploadManager()

    private let storage = Storage.storage()
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var uploadError: String?

    private init() {}

    // MARK: - Image Processing

    /// Resize image to 512x512px square (recommended size for logos)
    func resizeImage(_ image: UIImage, to size: CGSize = CGSize(width: 512, height: 512)) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Compress image to target file size (default 200KB)
    func compressImage(_ image: UIImage, maxSizeKB: Int = 200) -> Data? {
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
        isUploading = true
        uploadProgress = 0.0
        uploadError = nil

        defer {
            Task { @MainActor in
                isUploading = false
            }
        }

        // Resize to 512x512px
        guard let resizedImage = resizeImage(image) else {
            throw LogoUploadError.resizeFailed
        }

        // Compress to ~200KB
        guard let imageData = compressImage(resizedImage) else {
            throw LogoUploadError.compressionFailed
        }

        debugPrint("📤 Uploading logo - Original size: \(image.size), Resized: 512x512, Compressed: \(imageData.count / 1024)KB")

        // Create storage reference
        let storageRef = storage.reference()
        let logoPath = "logos/\(teamId).png"
        let logoRef = storageRef.child(logoPath)

        // Upload with metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/png"
        metadata.customMetadata = [
            "teamId": teamId,
            "uploadedAt": ISO8601DateFormatter().string(from: Date())
        ]

        // Upload the data
        let _ = try await logoRef.putDataAsync(imageData, metadata: metadata) { progress in
            if let progress = progress {
                Task { @MainActor in
                    self.uploadProgress = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                    debugPrint("📊 Upload progress: \(Int(self.uploadProgress * 100))%")
                }
            }
        }

        // Get download URL
        let downloadURL = try await logoRef.downloadURL()
        debugPrint("✅ Logo uploaded successfully: \(downloadURL.absoluteString)")

        return downloadURL.absoluteString
    }

    /// Delete logo from Firebase Storage
    func deleteTeamLogo(teamId: String) async throws {
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
