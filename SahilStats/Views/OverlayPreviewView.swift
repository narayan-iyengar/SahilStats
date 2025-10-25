//
//  OverlayPreviewView.swift
//  SahilStats
//
//  Overlay Preview Mode - Test score overlay without recording
//

import SwiftUI

struct OverlayPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedScenario: TestScenario = .normal
    @State private var orientation: UIDeviceOrientation = .landscapeRight
    @State private var showZoomIndicator = false
    @State private var currentZoomLevel: CGFloat = 1.0

    enum TestScenario: String, CaseIterable, Identifiable {
        case normal = "Normal Game"
        case longNames = "Long Team Names"
        case highScore = "High Score"
        case closeGame = "Close Game"
        case overtime = "Overtime"
        case quarters = "Quarters Format"

        var id: String { rawValue }

        var overlayData: SimpleScoreOverlayData {
            switch self {
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
                    recordingDuration: "15:36"
                )
            case .longNames:
                return SimpleScoreOverlayData(
                    homeTeam: "Central High School",
                    awayTeam: "St. Mary's Academy",
                    homeScore: 23,
                    awayScore: 21,
                    quarter: 1,
                    clockTime: "12:45",
                    gameFormat: .halves,
                    isRecording: true,
                    recordingDuration: "07:15"
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
                    recordingDuration: "45:18"
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
                    recordingDuration: "39:57"
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
                    recordingDuration: "52:30"
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
                    recordingDuration: "03:00"
                )
            }
        }
    }

    var body: some View {
        ZStack {
            // Dark background to simulate recording
            Color.black
                .ignoresSafeArea()

            // Overlay preview
            SimpleScoreOverlay(
                overlayData: selectedScenario.overlayData,
                orientation: orientation,
                recordingDuration: selectedScenario.overlayData.recordingDuration,
                isRecording: selectedScenario.overlayData.isRecording
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
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.3))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                        }

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
                    }
                    .padding(16)

                    Spacer()
                }

                Spacer()
            }
        }
        .navigationTitle("Overlay Preview")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
    }
}

#Preview {
    NavigationView {
        OverlayPreviewView()
    }
}
