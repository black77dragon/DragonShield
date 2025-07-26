import SwiftUI

struct ResizeHandle: View {
    let title: String
    var enabled: Bool = true
    @State private var hovering = false

    var body: some View {
        let baseOpacity = enabled ? 0.4 : 0.2
        Image(systemName: "square.and.arrow.up.right")
            .resizable()
            .rotationEffect(.degrees(45))
            .frame(width: 12, height: 12)
            .foregroundColor(.secondary)
            .opacity(hovering ? 1.0 : baseOpacity)
            .padding(16)
            .contentShape(Rectangle())
            .frame(width: 44, height: 44, alignment: .bottomTrailing)
            .onHover { hovering = $0 }
            .accessibilityLabel("Resize handle for \(title)")
            .cursor(.resizeUpDown)
    }
}
