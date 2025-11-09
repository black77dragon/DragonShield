import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum Theme {
    static let primaryAccent = Color(red: 26/255, green: 115/255, blue: 232/255)

    /// Neutral surface used by dashboard tiles and cards. Adapts to the active color scheme.
    static var surface: Color { tileBackground }

    static var textPrimary: Color { .primary }

    static var tileBackground: Color {
#if os(macOS)
        Color(nsColor: .controlBackgroundColor)
#else
        Color(uiColor: .secondarySystemBackground)
#endif
    }

    static var tileBorder: Color {
#if os(macOS)
        Color(nsColor: .separatorColor).opacity(0.35)
#else
        Color(uiColor: .separator).opacity(0.35)
#endif
    }

    static var tileShadow: Color {
#if os(macOS)
        Color.black.opacity(0.25)
#else
        Color.black.opacity(0.2)
#endif
    }
}

enum AssetClassCode: String {
    case liquidity = "LIQ"
    case equity = "EQ"
    case fixedIncome = "FI"
    case realAssets = "REAL"
    case alternatives = "ALT"
    case derivatives = "DERIV"
    case other = "OTHER"
}

extension Theme {
    static let assetClassColors: [AssetClassCode: Color] = [
        .liquidity: Color(red: 0.63, green: 0.75, blue: 0.90),
        .equity: Color(red: 0.61, green: 0.77, blue: 0.69),
        .fixedIncome: Color(red: 0.86, green: 0.73, blue: 0.57),
        .realAssets: Color(red: 0.74, green: 0.69, blue: 0.85),
        .alternatives: Color(red: 0.86, green: 0.67, blue: 0.65),
        .derivatives: Color(red: 0.67, green: 0.82, blue: 0.86),
        .other: Color(red: 0.78, green: 0.80, blue: 0.83)
    ]

    static let currencyColors: [String: Color] = [
        "CHF": Color(red: 0.55, green: 0.66, blue: 0.83),
        "USD": Color(red: 0.57, green: 0.75, blue: 0.66),
        "EUR": Color(red: 0.67, green: 0.61, blue: 0.84),
        "BTC": Color(red: 0.90, green: 0.74, blue: 0.57)
    ]
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Theme.primaryAccent)
            .foregroundColor(.white)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.primaryAccent, lineWidth: 1)
            )
            .foregroundColor(Theme.primaryAccent)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.error)
            .foregroundColor(.white)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
