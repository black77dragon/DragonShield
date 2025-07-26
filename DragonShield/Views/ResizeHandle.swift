import SwiftUI

struct ResizeHandle: View {
    let title: String
    @State private var hovering = false

    var body: some View {
        Image(systemName: "square.and.arrow.up.right")
            .rotationEffect(.degrees(45))
            .frame(width: 12, height: 12)
            .padding(16) // ensures 44x44 hit area
            .contentShape(Rectangle())
            .foregroundColor(.secondary)
            .opacity(hovering ? 1.0 : 0.4)
            .animation(.easeInOut(duration: 0.15), value: hovering)
            .onHover { hovering = $0 }
            .cursor(.resizeUpDown)
            .accessibilityLabel("Resize handle for \(title)")
    }
}
