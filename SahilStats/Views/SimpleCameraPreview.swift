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
                print("🤏 Pinch zoom started at \(String(format: "%.1f", initialZoom))x")
            case .changed:
                let newZoom = initialZoom * gesture.scale
                let actualZoom = parent.recordingManager.setZoom(factor: newZoom)
                print("🤏 Pinch zoom: \(String(format: "%.1f", actualZoom))x")
            case .ended:
                let finalZoom = parent.recordingManager.getCurrentZoom()
                print("🤏 Pinch zoom ended at \(String(format: "%.1f", finalZoom))x")
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
        print("🎥 Initial view frame: \(view.frame)")
        print("🎥 Initial view bounds: \(view.bounds)")

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
        // Skip if view hasn't been laid out yet (bounds are zero)
        guard uiView.bounds.width > 0 && uiView.bounds.height > 0 else {
            print("⏸️ SimpleCameraPreviewView: Skipping update, view not laid out yet (bounds: \(uiView.bounds))")
            return
        }

        // Update the preview layer frame if it exists
        if let previewLayer = uiView.layer.sublayers?.first(where: { $0 is AVCaptureVideoPreviewLayer }) as? AVCaptureVideoPreviewLayer {
            if previewLayer.frame != uiView.bounds {
                print("🎥 SimpleCameraPreviewView: Updating preview layer frame to \(uiView.bounds)")
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                previewLayer.frame = uiView.bounds
                CATransaction.commit()
            }
        } else if !context.coordinator.hasAddedPreviewLayer {
            print("🎥 SimpleCameraPreviewView: No preview layer in updateUIView, trying to add")
            checkAndAddPreviewLayer(to: uiView, coordinator: context.coordinator)
        }
    }
    
    private func checkAndAddPreviewLayer(to view: UIView, coordinator: Coordinator) {
        print("🔍 SimpleCameraPreviewView: Checking for preview layer...")

        // Skip if view hasn't been laid out yet (bounds are zero)
        guard view.bounds.width > 0 && view.bounds.height > 0 else {
            print("⏸️ SimpleCameraPreviewView: Skipping preview setup, view not laid out yet")
            return
        }

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
            print("⏸️ SimpleCameraPreviewView: Preview layer not ready yet, will retry...")
            // Don't call setupCamera() here - RecorderReadyView or CleanVideoRecordingView
            // already called it. Just wait for the timer to retry.
        }
    }
    
    private func addPreviewLayer(_ previewLayer: AVCaptureVideoPreviewLayer, to view: UIView, coordinator: Coordinator) {
        print("🎥 SimpleCameraPreviewView: Adding preview layer to view")
        print("🎥 Preview layer session: \(previewLayer.session != nil ? "exists" : "nil")")
        print("🎥 Preview layer connection: \(previewLayer.connection != nil ? "exists" : "nil")")

        // Check session status but DON'T start it - RecorderReadyView or CleanVideoRecordingView already did
        if let session = previewLayer.session {
            print("🎥 Session running status: \(session.isRunning)")
            if !session.isRunning {
                print("⚠️ Session not running yet, will wait for it to start...")
                // Don't start session here - it's already being started by the parent view
                // Just wait a bit and retry
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if session.isRunning {
                        print("✅ Session started by parent view, proceeding with preview setup")
                        self.completePreviewLayerSetup(previewLayer, view: view, coordinator: coordinator)
                    } else {
                        print("⏸️ Session still not running, will retry via timer")
                    }
                }
                return
            }
        }

        completePreviewLayerSetup(previewLayer, view: view, coordinator: coordinator)
    }
    
    private func completePreviewLayerSetup(_ previewLayer: AVCaptureVideoPreviewLayer, view: UIView, coordinator: Coordinator) {
        print("🎥 SimpleCameraPreviewView: Completing preview layer setup")
        print("🎥 View bounds: \(view.bounds)")

        // Skip if view hasn't been laid out yet
        guard view.bounds.width > 0 && view.bounds.height > 0 else {
            print("⏸️ SimpleCameraPreviewView: View not laid out yet, deferring setup")
            // Retry after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.completePreviewLayerSetup(previewLayer, view: view, coordinator: coordinator)
            }
            return
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // Remove any existing preview layers first
        view.layer.sublayers?.forEach { sublayer in
            if sublayer is AVCaptureVideoPreviewLayer {
                sublayer.removeFromSuperlayer()
            }
        }

        // Configure preview layer with proper frame
        previewLayer.frame = view.bounds

        // Use letterbox or fill based on feature flag
        if VideoRecordingManager.useLetterboxPreview {
            previewLayer.videoGravity = .resizeAspect  // Letterbox - shows entire frame with black bars
            print("🎥 Set preview layer frame to: \(previewLayer.frame) [LETTERBOX MODE]")
        } else {
            previewLayer.videoGravity = .resizeAspectFill  // Fill - crops to fill screen
            print("🎥 Set preview layer frame to: \(previewLayer.frame) [FILL MODE]")
        }

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
