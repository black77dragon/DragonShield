import SwiftUI

enum Theme {
    static let primaryAccent = Color(red: 26/255, green: 115/255, blue: 232/255)
    static let surface = Color(red: 248/255, green: 249/255, blue: 250/255)
    static let textPrimary = Color(red: 33/255, green: 33/255, blue: 33/255)
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
