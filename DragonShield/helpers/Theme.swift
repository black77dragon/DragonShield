import SwiftUI

enum Theme {
    static let primaryAccent = Color(red: 42/255, green: 125/255, blue: 225/255)
    static let surface = Color(red: 248/255, green: 249/255, blue: 250/255)
    static let textPrimary = Color(red: 33/255, green: 33/255, blue: 33/255)
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
