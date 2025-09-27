//
//  MediaIntegration.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/23/25.
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - Enhanced Game Detail View with Media

struct EnhancedGameDetailView: View {
    @State var game: Game
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebaseService = FirebaseService.shared
    @EnvironmentObject var authService: AuthService
    
    @State private var showingCameraCapture = false
    @State private var showingVideoRecording = false
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerView
                    mediaSection
                    playerStatsSection
                    shootingPercentagesSection
                }
                .padding()
            }
            .navigationTitle("Game Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Game Media")
                    .font(isIPad ? .title2 : .headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                
                Spacer()
                
                Menu {
                    if FirebaseService.shared.hasLiveGame {
                        Button(action: { showingVideoRecording = true }) {
                            Label("Record Video", systemImage: "video.fill")
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(isIPad ? 20 : 16)
        .background(Color.orange.opacity(0.05))
        .cornerRadius(isIPad ? 16 : 12)
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(game.teamName) vs \(game.opponent)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                if game.outcome == .win {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow)
                        .font(.title)
                }
            }
            
            HStack {
                Text("Final Score: \(game.myTeamScore) - \(game.opponentScore)")
                    .font(.title2)
                    .foregroundColor(game.outcome.color == "green" ? .green : .red)
            }
            
            HStack {
                Text(game.formattedDate)
                if let location = game.location, !location.isEmpty {
                    Text("• \(location)")
                }
            }
            .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var playerStatsSection: some View {
        PlayerStatsSection(
            game: $game,
            authService: authService,
            firebaseService: firebaseService,
            isIPad: isIPad
        )
    }
    
    private var shootingPercentagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shooting Percentages")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ShootingPercentageCard(
                    title: "Field Goal",
                    percentage: String(format: "%.0f%%", game.fieldGoalPercentage * 100),
                    fraction: "\(game.fg2m + game.fg3m)/\(game.fg2a + game.fg3a)",
                    color: .blue
                )
                ShootingPercentageCard(
                    title: "Three Point",
                    percentage: String(format: "%.0f%%", game.threePointPercentage * 100),
                    fraction: "\(game.fg3m)/\(game.fg3a)",
                    color: .green
                )
            }
        }
    }
}

// MARK: - Orientation Manager

@MainActor
class OrientationManager: ObservableObject {
    @Published var orientation = UIDevice.current.orientation
    @Published var isLandscape = false
    
    init() {
        updateLandscapeState()
        startObserving()
    }
    
    private func startObserving() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateOrientation()
        }
    }
    
    private func updateOrientation() {
        let newOrientation = UIDevice.current.orientation
        
        if newOrientation.isValidInterfaceOrientation {
            orientation = newOrientation
            updateLandscapeState()
            print("Orientation updated: \(orientation.rawValue), isLandscape: \(isLandscape)")
        }
    }
    
    private func updateLandscapeState() {
        isLandscape = orientation.isLandscape
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }
}

extension UIDeviceOrientation {
    var isValidInterfaceOrientation: Bool {
        switch self {
        case .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight:
            return true
        default:
            return false
        }
    }
}






// ✅ NEW: Landscape-optimized score overlay component
struct LandscapeLiveScoreOverlay: View {
    let game: LiveGame
    let recordingDuration: TimeInterval
    let isRecording: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Main horizontal scoreboard
            HStack(spacing: 0) {
                // Away team (left third)
                HStack(spacing: 12) {
                    Text(String(game.opponent.prefix(3)).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("\(game.awayScore)")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(.red)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 30)
                
                // Center info (middle third)
                VStack(spacing: 2) {
                    Text(ordinalPeriod(game.period))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.orange)
                    
                    Text(game.currentClockDisplay)
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(.white)
                        .monospacedDigit()
                    
                    // Recording indicator
                    if isRecording {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                            Text("REC \(formatDuration(recordingDuration))")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.orange.opacity(0.6), lineWidth: 1)
                        )
                )
                .frame(maxWidth: .infinity)
                
                // Home team (right third)
                HStack(spacing: 12) {
                    Text("\(game.homeScore)")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(.blue)
                        .monospacedDigit()
                    
                    Text(String(game.teamName.prefix(3)).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 30)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70) // Fixed height for consistent appearance
            .background(
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.black.opacity(0.8),
                                Color.black.opacity(0.6)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .edgesIgnoringSafeArea(.horizontal) // Extend to edges horizontally
            )
        }
        .edgesIgnoringSafeArea(.bottom) // Extend to bottom edge
    }
    
    private func ordinalPeriod(_ period: Int) -> String {
        switch period {
        case 1: return "1ST"
        case 2: return "2ND"
        case 3: return "3RD"
        case 4: return "4TH"
        default: return "\(period)TH"
        }
    }
}

// MARK: - Enhanced Live Game View with Landscape-Only Recording

struct EnhancedLiveGameView: View {
    let liveGame: LiveGame
    @StateObject private var recordingManager = VideoRecordingManager.shared
    @State private var showingVideoRecording = false
    
    var body: some View {
        VStack(spacing: 0) {
            enhancedLiveGameHeader()
            
            ScrollView {
                VStack(spacing: 20) {
                    existingLiveGameContent()
                }
                .padding()
            }
        }
        .fullScreenCover(isPresented: $showingVideoRecording) {
            CleanVideoRecordingView(liveGame: liveGame)
        }
    }
    
    @ViewBuilder
    private func enhancedLiveGameHeader() -> some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .opacity(0.8)
                        .animation(.easeInOut(duration: 1).repeatForever(), value: true)
                    
                    Text("LIVE GAME")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    VideoRecordingButton(liveGame: liveGame)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
        )
    }
    
    @ViewBuilder
    private func existingLiveGameContent() -> some View {
        VStack(spacing: 20) {
            Text("Live Game Content")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Score: \(liveGame.homeScore) - \(liveGame.awayScore)")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Period \(liveGame.period)")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Updated Video Recording Button

struct VideoRecordingButton: View {
    let liveGame: LiveGame
    @StateObject private var recordingManager = VideoRecordingManager.shared
    @State private var showingVideoRecording = false
    
    var body: some View {
        Button(action: {
            showingVideoRecording = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "video.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("Record")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.blue.opacity(0.9))
            .cornerRadius(20)
        }
        .fullScreenCover(isPresented: $showingVideoRecording) {
            // Use the new landscape-native video recording view
            CleanVideoRecordingView(liveGame: liveGame)
        }
    }
}


// MARK: - Camera Preview View

struct CameraPreviewView: UIViewRepresentable {
    @StateObject private var recordingManager = VideoRecordingManager.shared
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        if let previewLayer = recordingManager.previewLayer {
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
        } else {
            if let newPreviewLayer = recordingManager.setupCamera() {
                newPreviewLayer.frame = view.bounds
                view.layer.addSublayer(newPreviewLayer)
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = recordingManager.previewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
}

// MARK: - Camera Capture View

struct CameraCapture: UIViewControllerRepresentable {
    let gameId: String
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraDevice = .rear
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCapture
        
        init(_ parent: CameraCapture) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}


// MARK: - Supporting Views

struct StatItem: View {
    let title: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct MediaAccessStatus: View {
    @StateObject private var recordingManager = VideoRecordingManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permissions")
                .font(.headline)
            
            HStack {
                Image(systemName: recordingManager.canRecordVideo ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(recordingManager.canRecordVideo ? .green : .orange)
                
                Text("Camera & Microphone")
                    .font(.subheadline)
                
                Spacer()
                
                if !recordingManager.canRecordVideo {
                    Button("Enable") {
                        if recordingManager.shouldShowSettingsAlert {
                            recordingManager.openCameraSettings()
                        } else {
                            Task {
                                await recordingManager.requestCameraAccess()
                            }
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .onAppear {
            recordingManager.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }
}
