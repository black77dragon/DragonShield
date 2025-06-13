// DragonShield/Views/Helpers/ViewModifiers.swift (or your chosen shared file)
// MARK: - Version 1.0
// MARK: - History
// - Initial creation: Common ViewModifiers for forms and buttons.

import SwiftUI

struct ModernFormSection: ViewModifier {
    let color: Color
    func body(content: Content) -> some View {
        content
            .padding(24)
            .background(glassMorphismBackground(color: color)) // Assuming glassMorphismBackground is also made accessible or defined here
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.2), lineWidth: 1))
            .shadow(color: color.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

// This helper function should also be accessible, e.g., in the same shared file or globally.
private func glassMorphismBackground(color: Color) -> some View {
    ZStack {
        RoundedRectangle(cornerRadius: 16).fill(.regularMaterial)
            .background(LinearGradient(colors: [.white.opacity(0.85), .white.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing))
        RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [color.opacity(0.05), color.opacity(0.03), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}

struct ModernPrimaryButton: ViewModifier {
    let color: Color
    let isDisabled: Bool
    func body(content: Content) -> some View {
        content
            .foregroundColor(.white)
            .frame(height: 32)
            .padding(.horizontal, 16)
            .background(Group {
                if isDisabled { Color.gray.opacity(0.4) } else { color }
            })
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
            .shadow(color: isDisabled ? .clear : color.opacity(0.3), radius: 8, x: 0, y: 2)
            .disabled(isDisabled)
            .buttonStyle(ScaleButtonStyle()) // Assumes ScaleButtonStyle is globally available
    }
}

struct ModernSubtleButton: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.gray)
            .frame(width: 32, height: 32)
            .background(Color.gray.opacity(0.1))
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
            .buttonStyle(ScaleButtonStyle()) // Assumes ScaleButtonStyle is globally available
    }
}

struct ModernToggleStyle: ViewModifier {
    let tint: Color
    func body(content: Content) -> some View {
        content
            .toggleStyle(SwitchToggleStyle(tint: tint))
            .padding(.horizontal, 16).padding(.vertical, 12)
            // Removed background and overlay to simplify and let section background apply
            // .background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10))
            // .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1)).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// Ensure ScaleButtonStyle is also in a shared file (e.g., ViewHelpers.swift)
// struct ScaleButtonStyle: ButtonStyle { ... }
