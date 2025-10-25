//
//  PhotoPickerCoordinator.swift
//  SahilStats
//
//  Presents PHPicker directly from window without SwiftUI presentation issues
//

import UIKit
import PhotosUI
import SwiftUI

class PhotoPickerCoordinator: NSObject, ObservableObject, PHPickerViewControllerDelegate {
    @Published var isPresented = false

    private var completion: ((UIImage) -> Void)?
    private var presentedPicker: PHPickerViewController?

    func presentPicker(completion: @escaping (UIImage) -> Void) {
        self.completion = completion

        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self

        // Find the root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            debugPrint("❌ PhotoPickerCoordinator: Could not find root view controller")
            return
        }

        // Find the topmost presented view controller
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }

        self.presentedPicker = picker
        topController.present(picker, animated: true) {
            debugPrint("✅ PhotoPickerCoordinator: Picker presented successfully")
        }
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        presentedPicker = nil

        guard let result = results.first else {
            debugPrint("⚠️ PhotoPickerCoordinator: No image selected")
            completion = nil
            return
        }

        debugPrint("📸 PhotoPickerCoordinator: Image selected, loading...")

        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            if let error = error {
                debugPrint("❌ PhotoPickerCoordinator: Failed to load image - \(error)")
                return
            }

            guard let image = object as? UIImage else {
                debugPrint("❌ PhotoPickerCoordinator: Object is not UIImage")
                return
            }

            debugPrint("✅ PhotoPickerCoordinator: Image loaded - \(image.size.width)×\(image.size.height)")

            DispatchQueue.main.async {
                self?.completion?(image)
                self?.completion = nil
            }
        }
    }
}
