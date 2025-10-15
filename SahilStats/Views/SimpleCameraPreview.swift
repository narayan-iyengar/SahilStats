// SimpleCameraPreviewView.swift - Fixed version with detailed logging

import SwiftUI
import AVFoundation

struct SimpleCameraPreviewView: UIViewRepresentable {
    @Binding var isCameraReady: Bool
    @ObservedObject private var recordingManager = VideoRecordingManager.shared
    
    class Coordinator: NSObject {
        var parent: SimpleCameraPreviewView
        var hasAddedPreviewLayer = false
        var checkTimer: Timer?
        var initialZoom: CGFloat = 1.0

        init(_ parent: SimpleCameraPreviewView) {
            self.parent = parent
        }

        deinit {
            checkTimer?.invalidate()
        }

        // MARK: - Gesture Handlers

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard parent.recordingManager.getCurrentVideoDevice() != nil else { return }

            switch gesture.state {
            case .began:
                initialZoom = parent.recordingManager.getCurrentZoom()
            case .changed:
                let newZoom = initialZoom * gesture.scale
                parent.recordingManager.setZoom(factor: newZoom)
            default:
                break
            }
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view else { return }

            let touchPoint = gesture.location(in: view)

            // Convert to normalized coordinates (0.0 to 1.0)
            let normalizedPoint = CGPoint(
                x: touchPoint.x / view.bounds.width,
                y: touchPoint.y / view.bounds.height
            )

            // Focus at the tapped point
            parent.recordingManager.focusAt(point: normalizedPoint)

            // Show visual feedback
            showFocusIndicator(at: touchPoint, in: view)
        }

        private func showFocusIndicator(at point: CGPoint, in view: UIView) {
            // Remove any existing focus indicator
            view.subviews.filter { $0.tag == 1001 }.forEach { $0.removeFromSuperview() }

            // Create focus indicator
            let focusView = UIView(frame: CGRect(x: point.x - 40, y: point.y - 40, width: 80, height: 80))
            focusView.layer.borderColor = UIColor.yellow.cgColor
            focusView.layer.borderWidth = 2
            focusView.layer.cornerRadius = 40
            focusView.backgroundColor = .clear
            focusView.tag = 1001
            focusView.alpha = 0

            view.addSubview(focusView)

            // Animate focus indicator
            UIView.animate(withDuration: 0.2, animations: {
                focusView.alpha = 1
                focusView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            }) { _ in
                UIView.animate(withDuration: 0.3, delay: 0.5, options: [], animations: {
                    focusView.alpha = 0
                }) { _ in
                    focusView.removeFromSuperview()
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        print("🎥 SimpleCameraPreviewView: makeUIView called")

        // Add pinch gesture for zoom
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        view.addGestureRecognizer(pinchGesture)
        print("✅ Added pinch gesture for zoom")

        // Add tap gesture for focus
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tapGesture)
        print("✅ Added tap gesture for focus")

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
            // FIXED: Move setupCamera to background thread to avoid UI blocking
            DispatchQueue.global(qos: .userInitiated).async {
                if let newPreviewLayer = self.recordingManager.setupCamera() {
                    DispatchQueue.main.async {
                        print("✅ SimpleCameraPreviewView: Created new preview layer from setupCamera")
                        self.addPreviewLayer(newPreviewLayer, to: view, coordinator: coordinator)
                    }
                } else {
                    DispatchQueue.main.async {
                        print("❌ SimpleCameraPreviewView: Failed to setup camera")
                    }
                }
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
                print("⚠️ Session not running, starting it on background thread...")
                // FIXED: Move session.startRunning() to background thread to avoid UI blocking
                DispatchQueue.global(qos: .userInitiated).async {
                    session.startRunning()
                    
                    // Return to main thread for UI updates
                    DispatchQueue.main.async {
                        print("✅ Session started successfully on background thread")
                        // Wait for session to fully start
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.completePreviewLayerSetup(previewLayer, view: view, coordinator: coordinator)
                        }
                    }
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

        // Set INITIAL orientation (VideoRecordingManager will handle rotation updates)
        if let connection = previewLayer.connection {
            print("🎥 Connection is active: \(connection.isActive)")
            print("🎥 Connection is enabled: \(connection.isEnabled)")
            print("🎥 Connection has video input: \(connection.inputPorts.first?.mediaType == .video)")

            // Ensure connection is enabled
            if !connection.isEnabled {
                connection.isEnabled = true
                print("✅ Enabled preview connection")
            }

            // Set initial orientation using same angle mappings as VideoRecordingManager
            let deviceOrientation = UIDevice.current.orientation
            let rotationAngle: CGFloat

            switch deviceOrientation {
            case .portrait:
                rotationAngle = 90
            case .portraitUpsideDown:
                rotationAngle = 270
            case .landscapeLeft:
                rotationAngle = 270  // Match VideoRecordingManager
            case .landscapeRight:
                rotationAngle = 180  // Match VideoRecordingManager (your position)
            default:
                rotationAngle = 180  // Default to landscape right
            }

            if connection.isVideoRotationAngleSupported(rotationAngle) {
                connection.videoRotationAngle = rotationAngle
                print("✅ Set INITIAL preview orientation to \(rotationAngle)° for device orientation \(deviceOrientation.rawValue)")
            } else {
                print("⚠️ Rotation angle \(rotationAngle)° not supported")
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
