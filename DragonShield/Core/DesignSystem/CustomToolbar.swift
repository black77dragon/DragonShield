import SwiftUI

/// Custom toolbar component with reliable tooltip support
struct CustomToolbar: View {
    let actions: [ToolbarAction]
    
    var body: some View {
        HStack(spacing: 12) {
            Spacer()
            ForEach(actions) { action in
                CustomToolbarButton(
                    icon: action.icon,
                    tooltip: action.tooltip,
                    isDisabled: action.isDisabled,
                    action: action.action
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

struct ToolbarAction: Identifiable {
    let id = UUID()
    let icon: String
    let tooltip: String
    let isDisabled: Bool
    let action: () -> Void
    
    init(icon: String, tooltip: String, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.tooltip = tooltip
        self.isDisabled = isDisabled
        self.action = action
    }
}

/// Custom toolbar button with manual tooltip rendering
struct CustomToolbarButton: View {
    let icon: String
    let tooltip: String
    let isDisabled: Bool
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isDisabled ? .secondary.opacity(0.5) : .primary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isHovering && !isDisabled ? Color.secondary.opacity(0.15) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { hovering in
            isHovering = hovering
        }
        .overlay(alignment: .bottom) {
            if isHovering && !isDisabled {
                TooltipView(text: tooltip)
                    .offset(y: 40)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }
}

/// Tooltip view that appears on hover
struct TooltipView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.black.opacity(0.85))
            )
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            .zIndex(1000)
    }
}

#if DEBUG
#Preview {
    VStack {
        CustomToolbar(actions: [
            ToolbarAction(icon: "arrow.triangle.2.circlepath", tooltip: "FX Update") {},
            ToolbarAction(icon: "chart.line.uptrend.xyaxis", tooltip: "Price Update") {},
            ToolbarAction(icon: "square.dashed.inset.filled", tooltip: "Customize Dashboard") {}
        ])
        Spacer()
    }
}
#endif
