//
//  QRCodeScannerView.swift
//  SahilStats
//
//  QR code scanner for joining games on camera/recorder device
//

import SwiftUI
import AVFoundation

struct QRCodeScannerView: View {
    @ObservedObject private var navigation = NavigationCoordinator.shared
    @ObservedObject private var firebaseService = FirebaseService.shared
    @ObservedObject private var roleManager = DeviceRoleManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var scannedGame: LiveGame?
    @State private var showingGameJoin = false
    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        ZStack {
            // Camera scanner
            QRScannerViewController(
                onCodeScanned: handleQRCodeScanned
            )
            .ignoresSafeArea()

            // Overlay UI
            VStack {
                // Top bar
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(8)

                    Spacer()
                }
                .padding()

                Spacer()

                // Scanning frame
                VStack(spacing: 20) {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 250, height: 250)

                    Text("Scan QR Code to Join Game")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                }

                Spacer()
            }
        }
        .sheet(isPresented: $showingGameJoin) {
            if let game = scannedGame {
                GameJoinConfirmationView(
                    liveGame: game,
                    onJoin: joinGame,
                    onCancel: {
                        showingGameJoin = false
                        scannedGame = nil
                    }
                )
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private func handleQRCodeScanned(_ code: String) {
        debugPrint("📱 QR Code scanned: \(code.prefix(50))...")

        guard let qrData = GameQRCodeManager.shared.parseQRCode(from: code) else {
            errorMessage = "Invalid QR code. Please scan a SahilStats game code."
            showingError = true
            return
        }

        guard let liveGame = qrData.toLiveGame() else {
            errorMessage = "Failed to parse game details from QR code."
            showingError = true
            return
        }

        debugPrint("✅ Parsed game: \(liveGame.teamName) vs \(liveGame.opponent)")

        // Show confirmation before joining
        scannedGame = liveGame
        showingGameJoin = true
    }

    private func joinGame(_ liveGame: LiveGame) {
        Task {
            do {
                guard let gameId = liveGame.id else {
                    throw NSError(domain: "QRCodeScanner", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "Game ID missing"])
                }

                // Set device role as recorder (camera phone)
                try await roleManager.setDeviceRole(.recorder, for: gameId)
                debugPrint("✅ Device role set to recorder")

                // Navigate to recording view
                await MainActor.run {
                    navigation.currentFlow = .recording(liveGame)
                    dismiss()
                }

            } catch {
                await MainActor.run {
                    errorMessage = "Failed to join game: \(error.localizedDescription)"
                    showingError = true
                    scannedGame = nil
                    showingGameJoin = false
                }
            }
        }
    }
}

// MARK: - Game Join Confirmation

struct GameJoinConfirmationView: View {
    let liveGame: LiveGame
    let onJoin: (LiveGame) -> Void
    let onCancel: () -> Void
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 16) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("Join as Camera Phone")
                        .font(.title2)
                        .fontWeight(.bold)

                    VStack(spacing: 8) {
                        Text(liveGame.teamName)
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text("vs")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(liveGame.opponent)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }

                    Text(liveGame.location ?? "Unknown Location")
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("What happens next:")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: "1.circle.fill")
                                .foregroundColor(.blue)
                            Text("Camera will open automatically")
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "2.circle.fill")
                                .foregroundColor(.blue)
                            Text("Wait for stats phone to start recording")
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "3.circle.fill")
                                .foregroundColor(.blue)
                            Text("Video saves automatically at game end")
                        }
                    }
                    .font(.body)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                Spacer()

                VStack(spacing: 12) {
                    Button("Join Game") {
                        onJoin(liveGame)
                    }
                    .buttonStyle(UnifiedPrimaryButtonStyle(isIPad: isIPad))

                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(UnifiedSecondaryButtonStyle(isIPad: isIPad))
                }
            }
            .padding()
            .navigationTitle("Join Game")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - QR Scanner View Controller Wrapper

struct QRScannerViewController: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewControllerImpl {
        let controller = QRScannerViewControllerImpl()
        controller.onCodeScanned = onCodeScanned
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewControllerImpl, context: Context) {
        // No updates needed
    }
}

class QRScannerViewControllerImpl: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var onCodeScanned: ((String) -> Void)?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScanning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }

    private func setupCamera() {
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            forcePrint("❌ Failed to get video capture device")
            return
        }

        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            forcePrint("❌ Failed to create video input: \(error)")
            return
        }

        guard let captureSession = captureSession else { return }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            forcePrint("❌ Failed to add video input")
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            forcePrint("❌ Failed to add metadata output")
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.frame = view.layer.bounds
        previewLayer?.videoGravity = .resizeAspectFill

        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }
    }

    private func startScanning() {
        hasScanned = false
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    private func stopScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                       didOutput metadataObjects: [AVMetadataObject],
                       from connection: AVCaptureConnection) {
        guard !hasScanned else { return }

        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }

            hasScanned = true
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))

            onCodeScanned?(stringValue)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
}

#Preview {
    QRCodeScannerView()
}
