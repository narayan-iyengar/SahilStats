// SimpleCameraPreviewView.swift - Fixed version with proper camera setup

import SwiftUI
import AVFoundation

struct SimpleCameraPreviewView: UIViewRepresentable {
    @StateObject private var recordingManager = VideoRecordingManager.shared
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        // Request camera permission first
        Task {
            await recordingManager.requestCameraAccess()
        }
        
        // Set up the preview layer after a short delay to ensure permissions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let previewLayer = recordingManager.setupCamera() {
                previewLayer.frame = view.bounds
                previewLayer.videoGravity = .resizeAspectFill
                view.layer.addSublayer(previewLayer)
            } else {
                // If camera setup fails, show a placeholder
                let label = UILabel()
                label.text = "Camera not available"
                label.textColor = .white
                label.textAlignment = .center
                label.frame = view.bounds
                label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                view.addSubview(label)
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update preview layer frame when view size changes
        if let previewLayer = recordingManager.previewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
}
