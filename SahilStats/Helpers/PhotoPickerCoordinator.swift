//
//  PhotoPickerCoordinator.swift
//  SahilStats
//
//  Presents PHPicker directly from window without SwiftUI presentation issues
//

import UIKit
import PhotosUI
import SwiftUI

class PhotoPickerCoordinator: NSObject, PHPickerViewControllerDelegate {
    private var completion: ((UIImage) -> Void)?
    private var presentedPicker: PHPickerViewController?
    private var presentationWindow: UIWindow?

    func presentPicker(completion: @escaping (UIImage) -> Void) {
        self.completion = completion

        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self

        // Find the window scene
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            debugPrint("❌ PhotoPickerCoordinator: Could not find window scene")
            return
        }

        // Create a dedicated presentation window to avoid UIHostingController hierarchy warnings
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIViewController()
        window.windowLevel = .alert + 1
        window.makeKeyAndVisible()

        self.presentationWindow = window
        self.presentedPicker = picker

        // Present from the dedicated window
        DispatchQueue.main.async {
            window.rootViewController?.present(picker, animated: true) {
                debugPrint("✅ PhotoPickerCoordinator: Picker presented successfully")
            }
        }
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true) { [weak self] in
            // Clean up presentation window after dismissal
            self?.presentationWindow?.isHidden = true
            self?.presentationWindow = nil
        }
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
