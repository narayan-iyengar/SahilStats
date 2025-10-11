//
//  ConnectionStatusNotification.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 10/3/25.
//

// ConnectionStatusNotification.swift
// Native iOS-style banner that shows connection progress

import SwiftUI
import Combine
import MultipeerConnectivity


// MARK: - Enhanced No Live Game View with Lottie

struct NoLiveGameLottieView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: isIPad ? 40 : 32) {
                Spacer()
                
                // Lottie animation
                LottieView(name: "no-game-animation")
                    .frame(width: isIPad ? 300 : 200, height: isIPad ? 300 : 200)
                
                VStack(spacing: isIPad ? 20 : 16) {
                    Text("No Live Game")
                        .font(isIPad ? .system(size: 44, weight: .bold) : .largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("The game has ended or is no longer available")
                        .font(isIPad ? .title3 : .body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, isIPad ? 60 : 40)
                }
                
                Spacer()
                
                // Action button
                Button("Back to Dashboard") {
                    dismissToRoot()
                }
                .buttonStyle(UnifiedPrimaryButtonStyle(isIPad: isIPad))
                .padding(.horizontal, isIPad ? 80 : 40)
                
                Spacer()
            }
        }
    }
    
    private func dismissToRoot() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            dismiss()
            return
        }
        
        var currentVC = rootViewController
        while let presented = currentVC.presentedViewController {
            currentVC = presented
        }
        
        currentVC.dismiss(animated: true)
    }
}


