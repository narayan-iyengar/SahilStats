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
                Picker("Format", selection: $settingsManager.gameFormat) {
                    Text("Halves").tag(GameFormat.halves)
                    Text("Quarters").tag(GameFormat.quarters)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Game Format")
            } footer: {
                Text("Choose whether games are divided into halves or quarters.")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Minutes", value: $settingsManager.quarterLength, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                        Text("minutes")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Length per \(settingsManager.gameFormat.quarterName)")
            } footer: {
                Text("Set the duration for each \(settingsManager.gameFormat.quarterName.lowercased()).")
            }
        }
        .navigationTitle("Game Format")
    }
}
