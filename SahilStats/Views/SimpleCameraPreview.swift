// SimpleCameraPreviewView.swift - Fixed version with detailed logging

import SwiftUI
import AVFoundation

struct SimpleCameraPreviewView: UIViewRepresentable {
    @Binding var isCameraReady: Bool
    @StateObject private var recordingManager = VideoRecordingManager.shared
    
    class Coordinator: NSObject {
        var parent: SimpleCameraPreviewView
        var hasAddedPreviewLayer = false
        var checkTimer: Timer?
        
        init(_ parent: SimpleCameraPreviewView) {
            self.parent = parent
        }
        
        deinit {
            checkTimer?.invalidate()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        print("🎥 SimpleCameraPreviewView: makeUIView called")
        
        // Add loading indicator
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .white
        activityIndicator.center = view.center
        activityIndicator.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        activityIndicator.tag = 999
        
        // Start checking for preview layer availability
        context.coordinator.checkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            DispatchQueue.main.async {
                if !context.coordinator.hasAddedPreviewLayer {
                    self.checkAndAddPreviewLayer(to: view, coordinator: context.coordinator)
                }
            }
        }
        
        // Try to add preview layer immediately
        checkAndAddPreviewLayer(to: view, coordinator: context.coordinator)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update the preview layer frame if it exists
        if let previewLayer = uiView.layer.sublayers?.first(where: { $0 is AVCaptureVideoPreviewLayer }) as? AVCaptureVideoPreviewLayer {
            print("🎥 SimpleCameraPreviewView: Updating preview layer frame to \(uiView.bounds)")
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            previewLayer.frame = uiView.bounds
            CATransaction.commit()
        } else if !context.coordinator.hasAddedPreviewLayer {
            print("🎥 SimpleCameraPreviewView: No preview layer in updateUIView, trying to add")
            checkAndAddPreviewLayer(to: uiView, coordinator: context.coordinator)
        }
    }
    
    private func checkAndAddPreviewLayer(to view: UIView, coordinator: Coordinator) {
        print("🔍 SimpleCameraPreviewView: Checking for preview layer...")
        
        // Check if preview layer already exists in view
        if view.layer.sublayers?.contains(where: { $0 is AVCaptureVideoPreviewLayer }) == true {
            print("✅ SimpleCameraPreviewView: Preview layer already exists in view")
            coordinator.hasAddedPreviewLayer = true
            coordinator.checkTimer?.invalidate()
            return
        }
        
        // Try to get preview layer from recording manager
        if let previewLayer = recordingManager.previewLayer {
            print("✅ SimpleCameraPreviewView: Found preview layer in recording manager")
            addPreviewLayer(previewLayer, to: view, coordinator: coordinator)
        } else {
            print("⚠️ SimpleCameraPreviewView: No preview layer available from recording manager")
            
            // Try to setup camera which will create both session and preview layer
            if let newPreviewLayer = recordingManager.setupCamera() {
                print("✅ SimpleCameraPreviewView: Created new preview layer from setupCamera")
                addPreviewLayer(newPreviewLayer, to: view, coordinator: coordinator)
            } else {
                print("❌ SimpleCameraPreviewView: Failed to setup camera")
            }
        }
    }
    
    private func addPreviewLayer(_ previewLayer: AVCaptureVideoPreviewLayer, to view: UIView, coordinator: Coordinator) {
        print("🎥 SimpleCameraPreviewView: Adding preview layer to view")
        print("🎥 Preview layer session: \(previewLayer.session != nil ? "exists" : "nil")")
        print("🎥 Preview layer connection: \(previewLayer.connection != nil ? "exists" : "nil")")
        
        // CRITICAL: Ensure session is running before adding preview layer
        if let session = previewLayer.session {
            print("🎥 Session running status: \(session.isRunning)")
            if !session.isRunning {
                print("⚠️ Session not running, starting it now...")
                session.startRunning()
                // Wait for session to start
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.completePreviewLayerSetup(previewLayer, view: view, coordinator: coordinator)
                }
                return
            }
        }
        
        completePreviewLayerSetup(previewLayer, view: view, coordinator: coordinator)
    }
    
    private func completePreviewLayerSetup(_ previewLayer: AVCaptureVideoPreviewLayer, view: UIView, coordinator: Coordinator) {
        print("🎥 SimpleCameraPreviewView: Completing preview layer setup")
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // Remove any existing preview layers first
        view.layer.sublayers?.forEach { sublayer in
            if sublayer is AVCaptureVideoPreviewLayer {
                sublayer.removeFromSuperlayer()
            }
        }
        
        // Configure preview layer
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        
        // Set video orientation for landscape
        if let connection = previewLayer.connection {
            print("🎥 Connection is active: \(connection.isActive)")
            print("🎥 Connection is enabled: \(connection.isEnabled)")
            print("🎥 Connection has video input: \(connection.inputPorts.first?.mediaType == .video)")
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .landscapeRight
                print("✅ Set video orientation to landscape")
            }
            // Ensure connection is enabled
            if !connection.isEnabled {
                connection.isEnabled = true
                print("✅ Enabled preview connection")
            }
        } else {
            print("⚠️ No connection available on preview layer")
        }
        
        // Add to view
        view.layer.addSublayer(previewLayer)
        
        CATransaction.commit()
        
        // Force a layout update
        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        // Remove loading indicator
        if let activityIndicator = view.viewWithTag(999) as? UIActivityIndicatorView {
            activityIndicator.stopAnimating()
            activityIndicator.removeFromSuperview()
        }
        
        coordinator.hasAddedPreviewLayer = true
        coordinator.checkTimer?.invalidate()
        
        // Mark camera as ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isCameraReady = true
            print("✅ SimpleCameraPreviewView: Camera marked as ready, session running: \(previewLayer.session?.isRunning ?? false)")
        }
        
        print("✅ SimpleCameraPreviewView: Preview layer added successfully")
    }
}
