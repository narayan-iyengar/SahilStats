//
//  AppInfoView.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 10/4/25.
//
import SwiftUI

struct AppInfoView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("2.0.0")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Build")
                    Spacer()
                    Text("2025.1")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("App Information")
            }
            
            Section {
                HStack {
                    Text("Player")
                    Spacer()
                    Text("Sahil")
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }
            } header: {
                Text("Dedicated To")
            }
        }
        .navigationTitle("About")
    }
}
