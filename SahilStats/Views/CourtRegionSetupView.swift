//
//  CourtRegionSetupView.swift
//  SahilStats
//
//  Visual court region alignment for DockKit tracking
//  Allows user to define basketball court area before recording
//

import SwiftUI
import AVFoundation

struct CourtRegionSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var gimbalManager = GimbalTrackingManager.shared

    @State private var courtRegion: CGRect
    @State private var isDragging = false
    @State private var dragStart: CGPoint = .zero

    // Default court region - extra-wide for automatic detection
    // Works for baseline, courtside, or corner positions
    private let defaultRegion = CGRect(
        x: 0.02,
        y: 0.05,
        width: 0.96,
        height: 0.9
    )

    init() {
        // Load saved region or use default
        if let savedRegion = GimbalTrackingManager.shared.getSavedCourtRegion() {
            _courtRegion = State(initialValue: savedRegion)
        } else {
            _courtRegion = State(initialValue: defaultRegion)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Camera Preview Layer
                CourtAlignmentCameraView()
                    .ignoresSafeArea()

                // Court Region Overlay
                GeometryReader { geometry in
                    let frame = CGRect(
                        x: courtRegion.minX * geometry.size.width,
                        y: courtRegion.minY * geometry.size.height,
                        width: courtRegion.width * geometry.size.width,
                        height: courtRegion.height * geometry.size.height
                    )

                    ZStack {
                        // Dimmed areas outside court region
                        Color.black.opacity(0.5)
                            .mask(
                                Rectangle()
                                    .fill(Color.white)
                                    .overlay(
                                        Rectangle()
                                            .frame(width: frame.width, height: frame.height)
                                            .position(x: frame.midX, y: frame.midY)
                                            .blendMode(.destinationOut)
                                    )
                            )

                        // Court region frame
                        Rectangle()
                            .strokeBorder(Color.green, lineWidth: 3)
                            .frame(width: frame.width, height: frame.height)
                            .position(x: frame.midX, y: frame.midY)

                        // Corner handles
                        ForEach(0..<4) { index in
                            Circle()
                                .fill(Color.green)
                                .frame(width: 30, height: 30)
                                .position(cornerPosition(index, in: frame))
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            adjustRegion(corner: index, to: value.location, in: geometry.size)
                                        }
                                )
                        }

                        // Center drag handle for moving entire region
                        Circle()
                            .fill(Color.green.opacity(0.5))
                            .frame(width: 50, height: 50)
                            .position(x: frame.midX, y: frame.midY)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if !isDragging {
                                            isDragging = true
                                            dragStart = value.startLocation
                                        }
                                        moveRegion(from: dragStart, to: value.location, in: geometry.size)
                                    }
                                    .onEnded { _ in
                                        isDragging = false
                                    }
                            )

                        // Instructions
                        VStack {
                            Spacer()
                            VStack(spacing: 12) {
                                Text("Align Court Region")
                                    .font(.title2)
                                    .fontWeight(.bold)

                                Text("Drag corners to resize • Drag center to move")
                                    .font(.caption)

                                Text("Frame should cover the basketball court")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                            .padding(.bottom, 100)
                        }
                    }
                }

                // Control Buttons
                VStack {
                    HStack {
                        Button("Reset") {
                            withAnimation {
                                courtRegion = defaultRegion
                            }
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()

                    Spacer()

                    Button("Save Court Region") {
                        gimbalManager.saveCourtRegion(courtRegion)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .padding()
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Helper Methods

    private func cornerPosition(_ index: Int, in frame: CGRect) -> CGPoint {
        switch index {
        case 0: return CGPoint(x: frame.minX, y: frame.minY) // Top-left
        case 1: return CGPoint(x: frame.maxX, y: frame.minY) // Top-right
        case 2: return CGPoint(x: frame.minX, y: frame.maxY) // Bottom-left
        case 3: return CGPoint(x: frame.maxX, y: frame.maxY) // Bottom-right
        default: return .zero
        }
    }

    private func adjustRegion(corner: Int, to location: CGPoint, in size: CGSize) {
        let normalized = CGPoint(
            x: max(0, min(1, location.x / size.width)),
            y: max(0, min(1, location.y / size.height))
        )

        var newRegion = courtRegion

        switch corner {
        case 0: // Top-left
            newRegion = CGRect(
                x: min(normalized.x, courtRegion.maxX - 0.1),
                y: min(normalized.y, courtRegion.maxY - 0.1),
                width: courtRegion.maxX - min(normalized.x, courtRegion.maxX - 0.1),
                height: courtRegion.maxY - min(normalized.y, courtRegion.maxY - 0.1)
            )
        case 1: // Top-right
            newRegion = CGRect(
                x: courtRegion.minX,
                y: min(normalized.y, courtRegion.maxY - 0.1),
                width: max(0.1, normalized.x - courtRegion.minX),
                height: courtRegion.maxY - min(normalized.y, courtRegion.maxY - 0.1)
            )
        case 2: // Bottom-left
            newRegion = CGRect(
                x: min(normalized.x, courtRegion.maxX - 0.1),
                y: courtRegion.minY,
                width: courtRegion.maxX - min(normalized.x, courtRegion.maxX - 0.1),
                height: max(0.1, normalized.y - courtRegion.minY)
            )
        case 3: // Bottom-right
            newRegion = CGRect(
                x: courtRegion.minX,
                y: courtRegion.minY,
                width: max(0.1, normalized.x - courtRegion.minX),
                height: max(0.1, normalized.y - courtRegion.minY)
            )
        default:
            break
        }

        courtRegion = newRegion
    }

    private func moveRegion(from start: CGPoint, to current: CGPoint, in size: CGSize) {
        let delta = CGPoint(
            x: (current.x - start.x) / size.width,
            y: (current.y - start.y) / size.height
        )

        var newRegion = courtRegion
        newRegion.origin.x += delta.x
        newRegion.origin.y += delta.y

        // Keep region within bounds
        newRegion.origin.x = max(0, min(1 - newRegion.width, newRegion.origin.x))
        newRegion.origin.y = max(0, min(1 - newRegion.height, newRegion.origin.y))

        courtRegion = newRegion
        dragStart = current
    }
}

// MARK: - Court Alignment Camera Preview

struct CourtAlignmentCameraView: UIViewRepresentable {
    func makeUIView(context: Context) -> CourtAlignmentPreviewView {
        let previewView = CourtAlignmentPreviewView()
        previewView.setupCamera()
        return previewView
    }

    func updateUIView(_ uiView: CourtAlignmentPreviewView, context: Context) {}

    class CourtAlignmentPreviewView: UIView {
        private var captureSession: AVCaptureSession?
        private var previewLayer: AVCaptureVideoPreviewLayer?

        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        func setupCamera() {
            let session = AVCaptureSession()
            session.sessionPreset = .high

            guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: backCamera) else {
                debugPrint("❌ Could not access back camera")
                return
            }

            if session.canAddInput(input) {
                session.addInput(input)
            }

            let previewLayer = layer as! AVCaptureVideoPreviewLayer
            previewLayer.session = session
            previewLayer.videoGravity = .resizeAspectFill

            self.captureSession = session
            self.previewLayer = previewLayer

            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }

        deinit {
            captureSession?.stopRunning()
        }
    }
}

// MARK: - Preview

#Preview {
    CourtRegionSetupView()
}
