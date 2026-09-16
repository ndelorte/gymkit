import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Small set of shared visual tokens. Kept intentionally minimal — most views
/// lean on system materials and Dynamic Type rather than a custom design system.
enum Theme {
    static let cornerRadius: CGFloat = 16
    static let cardPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 24
    static let minTapTarget: CGFloat = 52

    static let completedGreen = Color.green
    static let prGold = Color(red: 1.0, green: 0.78, blue: 0.18)
}

extension View {
    func cardStyle() -> some View {
        self
            .padding(Theme.cardPadding)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}

enum Haptics {
    static func setCompleted() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    static func lightTap() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
