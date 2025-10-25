//
//  PHPickerWrapper.swift
//  SahilStats
//
//  UIKit PHPicker wrapper to fix SwiftUI PhotosPicker off-by-one bug
//

import SwiftUI
import PhotosUI

struct PHPickerWrapper: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let teamId: String?
    let teamName: String?
    let onImageSelected: (UIImage, String, String) -> Void  // image, teamId, teamName

    func makeUIViewController(context: Context) -> UIViewController {
        // Return empty view controller - actual picker is presented modally
        return UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented && uiViewController.presentedViewController == nil {
            // Capture team info NOW before presenting picker
            guard let teamId = teamId, let teamName = teamName else {
                debugPrint("❌ PHPickerWrapper: teamId or teamName is nil, not showing picker")
                DispatchQueue.main.async {
                    isPresented = false
                }
                return
            }

            debugPrint("🎯 PHPickerWrapper: Opening picker for team: \(teamName) (id: \(teamId))")

            // Present picker with captured team info
            let picker = makePicker(context: context, teamId: teamId, teamName: teamName)
            uiViewController.present(picker, animated: true)
        } else if !isPresented && uiViewController.presentedViewController != nil {
            // Dismiss picker
            uiViewController.dismiss(animated: true)
        }
    }

    private func makePicker(context: Context, teamId: String, teamName: String) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator

        // Store team info in coordinator for this picker instance
        context.coordinator.currentTeamId = teamId
        context.coordinator.currentTeamName = teamName

        return picker
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onImageSelected: onImageSelected)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        @Binding var isPresented: Bool
        let onImageSelected: (UIImage, String, String) -> Void
        var currentTeamId: String?
        var currentTeamName: String?

        init(isPresented: Binding<Bool>, onImageSelected: @escaping (UIImage, String, String) -> Void) {
            self._isPresented = isPresented
            self.onImageSelected = onImageSelected
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // Capture team info before dismissing
            let teamId = currentTeamId
            let teamName = currentTeamName

            isPresented = false

            guard let result = results.first else {
                debugPrint("⚠️ PHPicker: No image selected")
                return
            }

            guard let capturedTeamId = teamId, let capturedTeamName = teamName else {
                debugPrint("❌ PHPicker: Team info lost")
                return
            }

            debugPrint("📸 PHPicker: Image selected for team: \(capturedTeamName), loading...")

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
                    self?.onImageSelected(image, capturedTeamId, capturedTeamName)
                }
            }
        }
    }
}
