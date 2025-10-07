// SimpleCameraPreviewView.swift - Fixed version with proper camera setup

import SwiftUI
import AVFoundation

/*
 struct SimpleCameraPreviewView: UIViewRepresentable {
 @StateObject private var recordingManager = VideoRecordingManager.shared
 @Binding var isCameraReady: Bool
 
 
 func makeUIView(context: Context) -> UIView {
 let view = UIView()
 view.backgroundColor = .black
 
 // Request camera permission first
 Task {
 await recordingManager.requestCameraAccess()
 
 // Set up the preview layer after permissions are granted
 DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
 if let previewLayer = recordingManager.setupCamera() {
 previewLayer.frame = view.bounds
 previewLayer.videoGravity = .resizeAspectFill
 view.layer.addSublayer(previewLayer)
 
 // Camera is ready - wait a bit more for everything to initialize
 DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
 isCameraReady = true
 }
 } else {
 // If camera setup fails, show a placeholder
 let label = UILabel()
 label.text = "Camera not available"
 label.textColor = .white
 label.textAlignment = .center
 label.frame = view.bounds
 label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
 view.addSubview(label)
 
 // Still mark as "ready" so UI shows
 DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
 isCameraReady = true
 }
 }
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
 */
struct SimpleCameraPreviewView: UIViewRepresentable {
    @Binding var isCameraReady: Bool
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Remove any existing preview layers
        uiView.layer.sublayers?.removeAll { $0 is AVCaptureVideoPreviewLayer }
        
        if let previewLayer = VideoRecordingManager.shared.previewLayer {
            print("🎥 SimpleCameraPreviewView: Adding preview layer to view")
            previewLayer.frame = uiView.bounds
            previewLayer.videoGravity = .resizeAspectFill
            
            // Ensure the preview layer is added on the main thread
            DispatchQueue.main.async {
                uiView.layer.addSublayer(previewLayer)
                
                if !isCameraReady {
                    isCameraReady = true
                    print("✅ SimpleCameraPreviewView: Camera marked as ready")
                }
            }
        } else {
            print("⚠️ SimpleCameraPreviewView: No preview layer available yet")
        }
    }
}
