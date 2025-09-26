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


struct ImprovedScoreButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: 44, height: 44)
            .background(Color.orange)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Compact status button style (smaller for player status)
struct CompactStatusButtonStyle: ButtonStyle {
    let isSelected: Bool
    let isIPad: Bool
    
    init(isSelected: Bool, isIPad: Bool = false) {
        self.isSelected = isSelected
        self.isIPad = isIPad
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isIPad ? .caption : .caption2)
            .fontWeight(.medium)
            .foregroundColor(isSelected ? .white : .orange)
            .padding(.vertical, isIPad ? 8 : 6) // Smaller padding
            .padding(.horizontal, isIPad ? 12 : 10)
            .background(isSelected ? Color.orange : Color.orange.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: isIPad ? 8 : 6)
                    .stroke(Color.orange.opacity(0.3), lineWidth: isSelected ? 0 : 1)
            )
            .cornerRadius(isIPad ? 8 : 6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}



// BIGGER game control button style
struct BiggerCompactControlButtonStyle: ButtonStyle {
    let color: Color
    let isIPad: Bool
    
    init(color: Color, isIPad: Bool = false) {
        self.color = color
        self.isIPad = isIPad
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isIPad ? .body : .subheadline) // BIGGER: Increased font size
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.vertical, isIPad ? 14 : 12) // BIGGER: Increased vertical padding
            .padding(.horizontal, isIPad ? 16 : 12) // BIGGER: Increased horizontal padding
            .frame(maxWidth: .infinity)
            .frame(minHeight: isIPad ? 48 : 40) // BIGGER: Set minimum height
            .background(color)
            .cornerRadius(isIPad ? 10 : 8) // BIGGER: Slightly larger corner radius
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}







struct PostGameScoreButtonStyle: ButtonStyle {
    let isIPad: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isIPad ? .system(size: 24, weight: .bold) : .title3) // BIGGER on iPad
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: isIPad ? 56 : 40, height: isIPad ? 56 : 40) // BIGGER on iPad
            .background(Color.blue)
            .cornerRadius(isIPad ? 16 : 10) // BIGGER corner radius on iPad
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct UnifiedPrimaryButtonStyle: ButtonStyle {
    let isIPad: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isIPad ? .title2 : .headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.vertical, isIPad ? 20 : 16)
            .padding(.horizontal, isIPad ? 32 : 24)
            .frame(maxWidth: .infinity)
            .background(Color.orange)
            .cornerRadius(isIPad ? 16 : 12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}


struct LiveStatButtonStyle: ButtonStyle {
    let color: Color
    let isIPad: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isIPad ? .title3 : .headline)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: isIPad ? 44 : 36, height: isIPad ? 44 : 36)
            .background(color)
            .overlay(
                RoundedRectangle(cornerRadius: isIPad ? 12 : 10)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(isIPad ? 12 : 10)
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .shadow(color: color.opacity(0.3), radius: configuration.isPressed ? 2 : 4, x: 0, y: configuration.isPressed ? 1 : 2)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct PillButtonStyle: ButtonStyle {
    let isIPad: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isIPad ? .body : .headline)
            .fontWeight(.semibold)
            .foregroundColor(.orange)
            .padding(.horizontal, isIPad ? 20 : 16)
            .padding(.vertical, isIPad ? 12 : 8)
            .background(Color.orange.opacity(0.1))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Add this to SharedButtonStyles.swift

struct ToolbarPillButtonStyle: ButtonStyle {
    let isIPad: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isIPad ? .body : .headline)
            .fontWeight(.semibold)
            .foregroundColor(.orange)
            // Reduced horizontal padding to fit in the toolbar
            .padding(.horizontal, isIPad ? 14 : 10)
            .padding(.vertical, isIPad ? 10 : 6)
            .background(Color.orange.opacity(0.1))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}


struct RecordingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.red)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct UnifiedSecondaryButtonStyle: ButtonStyle {
    let isIPad: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isIPad ? .title3 : .body)
            .fontWeight(.medium)
            .foregroundColor(.orange)
            .padding(.vertical, isIPad ? 16 : 12)
            .padding(.horizontal, isIPad ? 28 : 20)
            .frame(maxWidth: .infinity)
            .background(Color.orange.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: isIPad ? 12 : 8)
                    .stroke(Color.orange.opacity(0.5), lineWidth: 1.5)
            )
            .cornerRadius(isIPad ? 12 : 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}












struct LargerControlButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.vertical, 18)
            .padding(.horizontal, 20)
            .background(color)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct iPadStatButtonStyle: ButtonStyle {
    let color: Color
    
    init(color: Color = .orange) {
        self.color = color
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(width: 40, height: 40)
            .background(color)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct iPhoneStatButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(width: 32, height: 32)
            .background(Color.orange)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
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
