import SwiftUI

struct ResizeHandle: View {
    let tileName: String
    var disabled: Bool = false
    @State private var hovering = false

    private var idleOpacity: Double { disabled ? 0.2 : 0.4 }
    private var hoverOpacity: Double { disabled ? 0.2 : 1.0 }

    var body: some View {
        Image(systemName: "square.and.arrow.up.right")
            .rotationEffect(.degrees(45))
            .font(.system(size: 12, weight: .semibold))
            .frame(width: 12, height: 12)
            .padding(16)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .foregroundColor(.secondary)
            .opacity(hovering ? hoverOpacity : idleOpacity)
            .animation(.easeInOut(duration: 0.15), value: hovering)
            .onHover { hovering = $0 }
            .cursor(.resizeUpDown)
            .accessibilityLabel("Resize handle for \(tileName)")
    }
}
