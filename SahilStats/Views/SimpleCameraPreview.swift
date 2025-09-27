//
//  SimpleCameraPreview.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/27/25.
//
// SimpleCameraPreviewView.swift - Create this as a new file

import SwiftUI
import AVFoundation

struct SimpleCameraPreviewView: UIViewRepresentable {
    @StateObject private var recordingManager = VideoRecordingManager.shared
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        // Set up the preview layer
        if let previewLayer = recordingManager.setupCamera() {
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
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
