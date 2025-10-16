//
//  ScrollOffsetPreferenceKey.swift
//  SahilStats
//
//  PreferenceKey for tracking scroll offset to implement collapsible headers
//

import SwiftUI

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// Helper view to track scroll offset
struct ScrollOffsetModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geometry.frame(in: .named("scroll")).minY
                        )
                }
            )
    }
}

extension View {
    func trackScrollOffset() -> some View {
        modifier(ScrollOffsetModifier())
    }
}
