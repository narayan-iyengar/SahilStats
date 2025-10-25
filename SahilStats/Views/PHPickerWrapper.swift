//
//  PHPickerWrapper.swift
//  SahilStats
//
//  UIKit PHPicker wrapper to fix SwiftUI PhotosPicker off-by-one bug
//

import SwiftUI
import PhotosUI

struct PHPickerViewController_SwiftUI: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let teamId: String
    let teamName: String
    let onImageSelected: (UIImage, String, String) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator

        // Store team info in coordinator
        context.coordinator.teamId = teamId
        context.coordinator.teamName = teamName

        debugPrint("🎯 PHPicker: Created for team: \(teamName) (id: \(teamId))")

        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onImageSelected: onImageSelected)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        @Binding var isPresented: Bool
        let onImageSelected: (UIImage, String, String) -> Void
        var teamId: String?
        var teamName: String?

        init(isPresented: Binding<Bool>, onImageSelected: @escaping (UIImage, String, String) -> Void) {
            self._isPresented = isPresented
            self.onImageSelected = onImageSelected
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // Capture team info before dismissing
            let capturedTeamId = teamId
            let capturedTeamName = teamName

            isPresented = false

            guard let result = results.first else {
                debugPrint("⚠️ PHPicker: No image selected")
                return
            }

            guard let teamId = capturedTeamId, let teamName = capturedTeamName else {
                debugPrint("❌ PHPicker: Team info lost")
                return
            }

            debugPrint("📸 PHPicker: Image selected for team: \(teamName), loading...")

            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                if let error = error {
                    debugPrint("❌ PHPicker: Failed to load image - \(error)")
                    return
                }

                guard let image = object as? UIImage else {
                    debugPrint("❌ PHPicker: Object is not UIImage")
                    return
                }

                debugPrint("✅ PHPicker: Image loaded successfully - \(image.size.width)×\(image.size.height)")

                DispatchQueue.main.async {
                    self?.onImageSelected(image, teamId, teamName)
                }
            }
        }
    }
}
