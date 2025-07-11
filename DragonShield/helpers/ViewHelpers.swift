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

extension View {
    /// Convenience wrapper around `frame` for specifying a column width.
    func width(_ value: CGFloat) -> some View {
        frame(width: value)
    }

    /// Convenience wrapper around `frame` for resizable column widths.
    func width(min: CGFloat? = nil, ideal: CGFloat? = nil, max: CGFloat? = nil) -> some View {
        frame(minWidth: min, idealWidth: ideal, maxWidth: max)
    }
}
