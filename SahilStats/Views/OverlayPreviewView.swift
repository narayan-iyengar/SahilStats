//
//  OverlayPreviewView.swift
//  SahilStats
//
//  Overlay Preview Mode - Test score overlay without recording
//

import SwiftUI

struct OverlayPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var selectedScenario: TestScenario = .yourTeams
    @State private var orientation: UIDeviceOrientation = .landscapeRight
    @State private var showZoomIndicator = false
    @State private var currentZoomLevel: CGFloat = 1.0

    enum TestScenario: String, CaseIterable, Identifiable {
        case yourTeams = "Your Teams"
        case normal = "Normal Game"
        case longNames = "Long Team Names"
        case highScore = "High Score"
        case closeGame = "Close Game"
        case overtime = "Overtime"
        case quarters = "Quarters Format"

        var id: String { rawValue }

        func overlayData(teams: [Team]) -> SimpleScoreOverlayData {
            switch self {
            case .yourTeams:
                // Use actual user teams if available
                let homeTeam = teams.first
                let awayTeam = teams.count > 1 ? teams[1] : nil

                return SimpleScoreOverlayData(
                    homeTeam: homeTeam?.name ?? "Your Team",
                    awayTeam: awayTeam?.name ?? "Opponent",
                    homeScore: 42,
                    awayScore: 38,
                    quarter: 2,
                    clockTime: "6:30",
                    gameFormat: .halves,
                    isRecording: true,
                    recordingDuration: "12:45",
                    homeLogoURL: homeTeam?.logoURL,
                    awayLogoURL: awayTeam?.logoURL
                )
            case .normal:
                return SimpleScoreOverlayData(
                    homeTeam: "Warriors",
                    awayTeam: "Lakers",
                    homeScore: 45,
                    awayScore: 38,
                    quarter: 2,
                    clockTime: "8:24",
                    gameFormat: .halves,
                    isRecording: true,
                    recordingDuration: "15:36",
                    homeLogoURL: "https://cdn.nba.com/logos/nba/1610612744/primary/L/logo.svg",
                    awayLogoURL: "https://cdn.nba.com/logos/nba/1610612747/primary/L/logo.svg"
                )
            case .longNames:
                return SimpleScoreOverlayData(
                    homeTeam: "Central High School Warriors",
                    awayTeam: "St. Mary's Catholic Academy",
                    homeScore: 23,
                    awayScore: 21,
                    quarter: 1,
                    clockTime: "12:45",
                    gameFormat: .halves,
                    isRecording: true,
                    recordingDuration: "07:15",
                    homeLogoURL: "https://cdn.nba.com/logos/nba/1610612744/primary/L/logo.svg",
                    awayLogoURL: "https://cdn.nba.com/logos/nba/1610612738/primary/L/logo.svg"
                )
            case .highScore:
                return SimpleScoreOverlayData(
                    homeTeam: "Phoenix",
                    awayTeam: "Dragons",
                    homeScore: 124,
                    awayScore: 118,
                    quarter: 2,
                    clockTime: "0:42",
                    gameFormat: .halves,
                    isRecording: true,
                    recordingDuration: "45:18",
                    homeLogoURL: "https://cdn.nba.com/logos/nba/1610612756/primary/L/logo.svg",
                    awayLogoURL: "https://cdn.nba.com/logos/nba/1610612761/primary/L/logo.svg"
                )
            case .closeGame:
                return SimpleScoreOverlayData(
                    homeTeam: "Thunder",
                    awayTeam: "Storm",
                    homeScore: 67,
                    awayScore: 67,
                    quarter: 2,
                    clockTime: "0:03",
                    gameFormat: .halves,
                    isRecording: true,
                    recordingDuration: "39:57",
                    homeLogoURL: "https://cdn.nba.com/logos/nba/1610612760/primary/L/logo.svg",
                    awayLogoURL: "https://cdn.nba.com/logos/nba/1610612745/primary/L/logo.svg"
                )
            case .overtime:
                return SimpleScoreOverlayData(
                    homeTeam: "Eagles",
                    awayTeam: "Hawks",
                    homeScore: 88,
                    awayScore: 85,
                    quarter: 5,
                    clockTime: "2:30",
                    gameFormat: .quarters,
                    isRecording: true,
                    recordingDuration: "52:30",
                    homeLogoURL: "https://cdn.nba.com/logos/nba/1610612737/primary/L/logo.svg",
                    awayLogoURL: "https://cdn.nba.com/logos/nba/1610612737/primary/L/logo.svg"
                )
            case .quarters:
                return SimpleScoreOverlayData(
                    homeTeam: "Spartans",
                    awayTeam: "Trojans",
                    homeScore: 12,
                    awayScore: 9,
                    quarter: 1,
                    clockTime: "5:00",
                    gameFormat: .quarters,
                    isRecording: true,
                    recordingDuration: "03:00",
                    homeLogoURL: "https://cdn.nba.com/logos/nba/1610612762/primary/L/logo.svg",
                    awayLogoURL: "https://cdn.nba.com/logos/nba/1610612758/primary/L/logo.svg"
                )
            }
        }
    }

    private var currentOverlayData: SimpleScoreOverlayData {
        selectedScenario.overlayData(teams: firebaseService.teams)
    }

    var body: some View {
        ZStack {
            // Dark background to simulate recording
            Color.black
                .ignoresSafeArea()

            // Overlay preview
            SimpleScoreOverlay(
                overlayData: currentOverlayData,
                orientation: orientation,
                recordingDuration: currentOverlayData.recordingDuration,
                isRecording: currentOverlayData.isRecording
            )

            // Controls overlay (top-left corner)
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 12) {
                        // Back button
                        Button {
                            dismiss()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.caption)
                                Text("Back")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.3))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                        }
                        .padding(.top, 8)

                        // Scenario picker
                        Menu {
                            ForEach(TestScenario.allCases) { scenario in
                                Button(scenario.rawValue) {
                                    selectedScenario = scenario
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedScenario.rawValue)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                        }

                        // Orientation toggle
                        Button {
                            withAnimation {
                                orientation = orientation == .landscapeRight ? .landscapeLeft : .landscapeRight
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.caption)
                                Text("Rotate")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                        }

                        // Info text
                        Text("Preview Mode")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))

                        // Show helpful message if "Your Teams" selected
                        if selectedScenario == .yourTeams {
                            if firebaseService.teams.isEmpty {
                                Text("Upload team logos in Settings → Teams")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(8)
                            } else {
                                Text("\(firebaseService.teams.count) team\(firebaseService.teams.count == 1 ? "" : "s") loaded")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                    Spacer()
                }

                Spacer()
            }
            .edgesIgnoringSafeArea(.bottom)
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: 0)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
        .onAppear {
            firebaseService.startListening()
        }
    }
}

#Preview {
    NavigationView {
        OverlayPreviewView()
    }
}
