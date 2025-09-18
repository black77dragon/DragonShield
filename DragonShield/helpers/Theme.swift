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
        .liquidity: .blue,
        .equity: .green,
        .fixedIncome: .orange,
        .realAssets: .purple,
        .alternatives: .red,
        .derivatives: .teal,
        .other: .gray
    ]

    static let currencyColors: [String: Color] = [
        "CHF": .blue,
        "USD": .green,
        "EUR": .purple,
        "BTC": .orange
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
