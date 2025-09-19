//
//  SharedButtonStyles..swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/19/25.
//

// File: SahilStats/Views/SharedButtonStyles.swift
// Consolidated button styles to avoid duplicate definitions

import SwiftUI

// MARK: - Shared Button Styles for iPad/iPhone

struct ScoreButtonStyle: ButtonStyle {
    let isIPad: Bool
    
    init(isIPad: Bool = false) {
        self.isIPad = isIPad
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isIPad ? .title : .title2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: isIPad ? 56 : 44, height: isIPad ? 56 : 44)
            .background(Color.orange)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct StatusButtonStyle: ButtonStyle {
    let isSelected: Bool
    let isIPad: Bool
    
    init(isSelected: Bool, isIPad: Bool = false) {
        self.isSelected = isSelected
        self.isIPad = isIPad
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isIPad ? .title3 : .body)
            .fontWeight(.semibold)
            .foregroundColor(isSelected ? .white : .orange)
            .padding(.vertical, isIPad ? 16 : 12)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.orange : Color.orange.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: isIPad ? 12 : 8)
                    .stroke(Color.orange.opacity(0.3), lineWidth: isSelected ? 0 : 1)
            )
            .cornerRadius(isIPad ? 12 : 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ControlButtonStyle: ButtonStyle {
    let color: Color
    let isIPad: Bool
    
    init(color: Color, isIPad: Bool = false) {
        self.color = color
        self.isIPad = isIPad
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isIPad ? .title3 : .headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.vertical, isIPad ? 18 : 14)
            .padding(.horizontal, isIPad ? 20 : 16)
            .frame(maxWidth: .infinity)
            .background(color)
            .cornerRadius(isIPad ? 12 : 8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct UnifiedStatButtonStyle: ButtonStyle {
    let color: Color
    let isIPad: Bool
    
    init(color: Color = .orange, isIPad: Bool = false) {
        self.color = color
        self.isIPad = isIPad
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isIPad ? .title3 : .headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(width: isIPad ? 48 : 36, height: isIPad ? 48 : 36)
            .background(color)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    let isIPad: Bool
    
    init(isIPad: Bool = false) {
        self.isIPad = isIPad
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isIPad ? .title3 : .body)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.vertical, isIPad ? 18 : 16)
            .frame(maxWidth: .infinity)
            .background(Color.orange)
            .cornerRadius(isIPad ? 16 : 12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    let isIPad: Bool
    
    init(isIPad: Bool = false) {
        self.isIPad = isIPad
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isIPad ? .title3 : .body)
            .fontWeight(.semibold)
            .foregroundColor(.orange)
            .padding(.vertical, isIPad ? 16 : 12)
            .frame(maxWidth: .infinity)
            .background(Color.orange.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: isIPad ? 12 : 8)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(isIPad ? 12 : 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    let isIPad: Bool
    
    init(isIPad: Bool = false) {
        self.isIPad = isIPad
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isIPad ? .title3 : .body)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.vertical, isIPad ? 16 : 12)
            .frame(maxWidth: .infinity)
            .background(Color.red)
            .cornerRadius(isIPad ? 12 : 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct StatButtonStyle: ButtonStyle {
    let isIPad: Bool
    
    init(isIPad: Bool = false) {
        self.isIPad = isIPad
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isIPad ? .title3 : .headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(width: isIPad ? 40 : 32, height: isIPad ? 40 : 32)
            .background(Color.orange)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct LiveScoreButtonStyle: ButtonStyle {
    let isIPad: Bool
    
    init(isIPad: Bool = false) {
        self.isIPad = isIPad
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isIPad ? .title : .title2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: isIPad ? 56 : 44, height: isIPad ? 56 : 44)
            .background(Color.orange)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
