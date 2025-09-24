//
//  PhotosManager.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/23/25.
//
// MARK: - Create new file: SahilStats/Services/PhotosManager.swift

import Foundation
import Photos
import UIKit
import SwiftUI

class PhotosManager: ObservableObject {
    static let shared = PhotosManager()
    
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    
    private init() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    }
    
    func requestPhotoLibraryAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        await MainActor.run {
            self.authorizationStatus = status
        }
        return status == .authorized || status == .limited
    }
    
    func saveImageToPhotoLibrary(_ image: UIImage) async throws {
        guard await requestPhotoLibraryAccess() else {
            throw PhotosError.accessDenied
        }
        
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
            request.creationDate = Date()
        }
    }
    
    func saveVideoToPhotoLibrary(at url: URL) async throws {
        guard await requestPhotoLibraryAccess() else {
            throw PhotosError.accessDenied
        }
        
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }
    
    enum PhotosError: LocalizedError {
        case accessDenied
        
        var errorDescription: String? {
            switch self {
            case .accessDenied:
                return "Photo library access denied"
            }
        }
    }
}
