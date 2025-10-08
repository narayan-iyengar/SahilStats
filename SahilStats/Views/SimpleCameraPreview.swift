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
        
        // Add a loading indicator while camera initializes
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .white
        activityIndicator.center = view.center
        activityIndicator.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        activityIndicator.tag = 999 // Tag to identify it later
        
        // Add a loading label
        let loadingLabel = UILabel()
        loadingLabel.text = "Initializing Camera..."
        loadingLabel.textColor = .white
        loadingLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        loadingLabel.textAlignment = .center
        loadingLabel.sizeToFit()
        loadingLabel.center = CGPoint(x: view.center.x, y: view.center.y + 50)
        loadingLabel.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
        view.addSubview(loadingLabel)
        loadingLabel.tag = 998 // Tag to identify it later
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Only add preview layer if we don't already have one
        let hasPreviewLayer = uiView.layer.sublayers?.contains { $0 is AVCaptureVideoPreviewLayer } ?? false
        
        if !hasPreviewLayer, let previewLayer = VideoRecordingManager.shared.previewLayer {
            print("🎥 SimpleCameraPreviewView: Adding preview layer to view")
            
            // Configure preview layer
            previewLayer.frame = uiView.bounds
            previewLayer.videoGravity = .resizeAspectFill
            
            // Add preview layer
            uiView.layer.insertSublayer(previewLayer, at: 0)
            
            // Remove loading indicator and label
            if let activityIndicator = uiView.viewWithTag(999) as? UIActivityIndicatorView {
                activityIndicator.stopAnimating()
                activityIndicator.removeFromSuperview()
            }
            if let loadingLabel = uiView.viewWithTag(998) {
                loadingLabel.removeFromSuperview()
            }
            
            print("✅ SimpleCameraPreviewView: Preview layer added successfully")
            
        } else if hasPreviewLayer {
            // Update existing preview layer frame
            if let previewLayer = uiView.layer.sublayers?.first(where: { $0 is AVCaptureVideoPreviewLayer }) as? AVCaptureVideoPreviewLayer {
                previewLayer.frame = uiView.bounds
            }
        } else {
            print("⚠️ SimpleCameraPreviewView: No preview layer available yet")
            
            // Update loading label to show we're still waiting
            if let loadingLabel = uiView.viewWithTag(998) as? UILabel {
                loadingLabel.text = "Waiting for camera..."
            }
        }
    }
}
