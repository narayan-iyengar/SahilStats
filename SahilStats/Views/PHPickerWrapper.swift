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
    let onImageSelected: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        // Return empty view controller - actual picker is presented modally
        return UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented && uiViewController.presentedViewController == nil {
            // Present picker
            let picker = makePicker(context: context)
            uiViewController.present(picker, animated: true)
        } else if !isPresented && uiViewController.presentedViewController != nil {
            // Dismiss picker
            uiViewController.dismiss(animated: true)
        }
    }

    private func makePicker(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onImageSelected: onImageSelected)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        @Binding var isPresented: Bool
        let onImageSelected: (UIImage) -> Void

        init(isPresented: Binding<Bool>, onImageSelected: @escaping (UIImage) -> Void) {
            self._isPresented = isPresented
            self.onImageSelected = onImageSelected
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            isPresented = false

            guard let result = results.first else {
                debugPrint("⚠️ PHPicker: No image selected")
                return
            }

            debugPrint("📸 PHPicker: Image selected, loading...")

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
                    self?.onImageSelected(image)
                }
            }
        }
    }
}
