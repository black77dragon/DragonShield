// DragonShield/Views/Helpers/ViewHelpers.swift

// MARK: - Version 1.0

// MARK: - History

// - Initial creation: Centralized common UI helper ScaleButtonStyle.

import SwiftUI

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// You can add other common ButtonStyles, ViewModifiers, etc., here in the future.
