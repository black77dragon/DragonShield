import SwiftUI

struct ResizeHandle: View {
    let tileName: String
    var enabled: Bool = true
    @State private var hovering = false

    private var handleOpacity: Double {
        if enabled {
            return hovering ? 1 : 0.4
        } else {
            return 0.2
        }
    }

    var body: some View {
        Image(systemName: "square.and.arrow.up.right")
            .resizable()
            .scaledToFit()
            .frame(width: 12, height: 12)
            .rotationEffect(.degrees(45))
            .foregroundColor(.secondary)
            .opacity(handleOpacity)
            .padding(16)
            .frame(width: 44, height: 44, alignment: .bottomTrailing)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .cursor(.resizeUpDown)
            .animation(.easeInOut(duration: 0.15), value: hovering)
            .accessibilityLabel("Resize handle for \(tileName)")
    }
}
