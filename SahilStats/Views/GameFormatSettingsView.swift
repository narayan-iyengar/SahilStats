//
//  GameFormatSettingsView.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 10/4/25.
//
import SwiftUI

struct GameFormatSettingsView: View {
    @StateObject private var settingsManager = SettingsManager.shared

    var body: some View {
        List {
            Section {
                // Use Picker like in GameSetupView
                Picker("Format", selection: $settingsManager.gameFormat) {
                    ForEach(GameFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Game Format")
            } footer: {
                Text("Choose whether games are divided into halves or quarters.")
            }

            Section {
                // Use Stepper with +/- buttons like in GameSetupView
                Stepper("\(settingsManager.gameFormat.quarterName) Length: \(settingsManager.quarterLength) min",
                        value: $settingsManager.quarterLength, in: 1...30)
            } header: {
                Text("Length per \(settingsManager.gameFormat.quarterName)")
            } footer: {
                Text("Set the duration for each \(settingsManager.gameFormat.quarterName.lowercased()). This will be used as the default for new games.")
            }
        }
        .navigationTitle("Game Format")
    }
}
