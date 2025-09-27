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



// MARK: - Landscape-Only Video Recording View

struct VideoRecordingView: View {
    let liveGame: LiveGame
    @StateObject private var recordingManager = VideoRecordingManager.shared
    @StateObject private var orientationManager = OrientationManager()
    @Environment(\.dismiss) private var dismiss
    @State private var isLiveIndicatorVisible = true
    @State private var screenSize: CGSize = .zero
    
    private var isLandscape: Bool {
        orientationManager.isLandscape
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CameraPreviewView()
                    .ignoresSafeArea(.all)
                
                if isLandscape {
                    // Landscape mode - full recording interface
                    landscapeRecordingInterface
                } else {
                    // Portrait mode - rotation prompt
                    portraitRotationPrompt
                }
            }
            .onAppear {
                screenSize = geometry.size
                // Only start camera in landscape mode
                if isLandscape {
                    recordingManager.startCameraSession()
                }
                isLiveIndicatorVisible = true
            }
            .onChange(of: geometry.size) { oldSize, newSize in
                withAnimation(.easeInOut(duration: 0.3)) {
                    screenSize = newSize
                }
            }
            .onChange(of: isLandscape) { oldValue, newValue in
                if newValue {
                    // Switched to landscape - start camera
                    recordingManager.startCameraSession()
                } else {
                    // Switched to portrait - stop camera and recording
                    if recordingManager.isRecording {
                        Task { await recordingManager.stopRecording() }
                    }
                    recordingManager.stopCameraSession()
                }
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onDisappear {
            recordingManager.stopCameraSession()
        }
    }
    
    @ViewBuilder
    private var landscapeRecordingInterface: some View {
        ZStack {
            VStack {
                // Top bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    
                    Spacer()
                    
                    if recordingManager.isRecording {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .opacity(isLiveIndicatorVisible ? 1.0 : 0.3)
                                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isLiveIndicatorVisible)
                            
                            Text("REC")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.red)
                            
                            Text(recordingManager.recordingTimeString)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    
                    Spacer()
                    
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
                
                // Record button at bottom
                Button(action: toggleRecording) {
                    ZStack {
                        Circle()
                            .stroke(.white, lineWidth: 4)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .fill(recordingManager.isRecording ? .red : .white)
                            .frame(width: recordingManager.isRecording ? 32 : 68)
                            .scaleEffect(recordingManager.isRecording ? 0.8 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: recordingManager.isRecording)
                        
                        if recordingManager.isRecording {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.white)
                                .frame(width: 24, height: 24)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            
            // Horizontal scoreboard overlay positioned at bottom edge
            VStack {
                Spacer() // Push to bottom
                
                VStack(spacing: 8) {
                    // Main scoreboard - horizontal layout
                    HStack(spacing: 40) {
                        // Away team
                        VStack(spacing: 4) {
                            Text(liveGame.opponent)
                                .font(.caption)
                                .foregroundColor(.white)
                            Text("\(liveGame.awayScore)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                        
                        // Center info
                        VStack(spacing: 2) {
                            Text("Period \(liveGame.period)")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text(liveGame.currentClockDisplay)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        // Home team
                        VStack(spacing: 4) {
                            Text(liveGame.teamName)
                                .font(.caption)
                                .foregroundColor(.white)
                            Text("\(liveGame.homeScore)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Recording indicator if recording
                    if recordingManager.isRecording {
                        Text("REC \(recordingManager.recordingTimeString)")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Rectangle()
                        .fill(.black.opacity(0.7))
                        .ignoresSafeArea(.all, edges: .horizontal)
                )
                .ignoresSafeArea(.all, edges: .bottom)
            }
        }
    }
    
    @ViewBuilder
    private var horizontalScoreboard: some View {
        // Create a horizontal bar that spans the full width at bottom
        HStack(spacing: 0) {
            // Away team (left third)
            HStack(spacing: 12) {
                Text(String(liveGame.opponent.prefix(3)).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Text("\(liveGame.awayScore)")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 30)
            
            // Center info (middle third)
            VStack(spacing: 2) {
                Text(ordinalPeriod(liveGame.period))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.orange)
                
                Text(liveGame.currentClockDisplay)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.orange.opacity(0.6), lineWidth: 1)
                    )
            )
            .frame(maxWidth: .infinity)
            
            // Home team (right third)
            HStack(spacing: 12) {
                Text("\(liveGame.homeScore)")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.white)
                    .monospacedDigit()
                
                Text(String(liveGame.teamName.prefix(3)).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 30)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60) // Fixed height for consistent appearance
        .background(
            Rectangle()
                .fill(Color.blue.opacity(0.9))
                .edgesIgnoringSafeArea(.horizontal) // Extend to edges horizontally
        )
        .edgesIgnoringSafeArea(.bottom) // Extend to bottom edge
    }
    
    @ViewBuilder
    private var portraitRotationPrompt: some View {
        ZStack {
            // Semi-transparent overlay
            Rectangle()
                .fill(.black.opacity(0.8))
                .ignoresSafeArea(.all)
            
            VStack(spacing: 24) {
                // Rotation icon with animation
                Image(systemName: "rotate.right")
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(90))
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isLiveIndicatorVisible)
                
                VStack(spacing: 12) {
                    Text("Rotate to Landscape")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Video recording is only available in landscape mode for the best experience")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                // Game info preview
                VStack(spacing: 8) {
                    Text("\(liveGame.teamName) vs \(liveGame.opponent)")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    Text("\(liveGame.homeScore) - \(liveGame.awayScore)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("\(ordinalPeriod(liveGame.period)) • \(liveGame.currentClockDisplay)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 20)
                
                // Dismiss button
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.top, 20)
            }
        }
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
    
    private func toggleRecording() {
        // Only allow recording in landscape mode
        guard isLandscape else { return }
        
        if recordingManager.isRecording {
            Task { await recordingManager.stopRecording() }
        } else {
            Task { await recordingManager.startRecording() }
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
            VideoRecordingView(liveGame: liveGame)
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
            VideoRecordingView(liveGame: liveGame)
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
