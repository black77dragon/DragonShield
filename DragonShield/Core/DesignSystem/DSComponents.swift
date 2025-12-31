import SwiftUI

// MARK: - Cards

/// Standard card container with subtle background and border
struct DSCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = DSLayout.spaceM
    
    init(padding: CGFloat = DSLayout.spaceM, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(DSColor.surface)
            .cornerRadius(DSLayout.radiusL)
            .overlay(
                RoundedRectangle(cornerRadius: DSLayout.radiusL)
                    .stroke(DSColor.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Buttons

enum DSButtonStyleType {
    case primary
    case secondary
    case ghost
    case destructive
}

struct DSButtonStyle: ButtonStyle {
    let type: DSButtonStyleType
    let size: ControlSize
    @Environment(\.isEnabled) private var isEnabled
    
    init(type: DSButtonStyleType = .primary, size: ControlSize = .regular) {
        self.type = type
        self.size = size
    }
    
    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed && isEnabled

        configuration.label
            .font(.ds.body.weight(.medium))
            .padding(.horizontal, size == .large ? 24 : 16)
            .frame(height: size == .large ? DSLayout.buttonHeightLarge : DSLayout.buttonHeight)
            .background(background(isPressed: isPressed, isEnabled: isEnabled))
            .foregroundColor(foreground(isPressed: isPressed, isEnabled: isEnabled))
            .cornerRadius(DSLayout.radiusM)
            .overlay(border(isPressed: isPressed, isEnabled: isEnabled))
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
    
    private func background(isPressed: Bool, isEnabled: Bool) -> Color {
        if !isEnabled {
            switch type {
            case .ghost:
                return Color.clear
            case .secondary, .primary, .destructive:
                return DSColor.surfaceSecondary
            }
        }
        switch type {
        case .primary:
            return isPressed ? DSColor.accentMain.opacity(0.9) : DSColor.accentMain
        case .secondary:
            return isPressed ? DSColor.surfaceHighlight : DSColor.surface
        case .ghost:
            return isPressed ? DSColor.surfaceHighlight : Color.clear
        case .destructive:
            return isPressed ? DSColor.accentError.opacity(0.9) : DSColor.accentError
        }
    }
    
    private func foreground(isPressed: Bool, isEnabled: Bool) -> Color {
        if !isEnabled {
            return DSColor.textTertiary
        }
        switch type {
        case .primary, .destructive:
            return DSColor.textOnAccent
        case .secondary, .ghost:
            return DSColor.textPrimary
        }
    }
    
    @ViewBuilder
    private func border(isPressed: Bool, isEnabled: Bool) -> some View {
        if type == .secondary {
            RoundedRectangle(cornerRadius: DSLayout.radiusM)
                .stroke(isEnabled ? DSColor.borderStrong : DSColor.border, lineWidth: 1)
        } else if !isEnabled, type != .ghost {
            RoundedRectangle(cornerRadius: DSLayout.radiusM)
                .stroke(DSColor.border, lineWidth: 1)
        }
    }
}

// MARK: - Badges

struct DSBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.ds.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(DSLayout.radiusS)
    }
}
