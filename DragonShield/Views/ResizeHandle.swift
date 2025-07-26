import SwiftUI

struct ResizeHandle: View {
    let title: String
    var disabled: Bool = false
    @State private var hovered = false

    private var baseOpacity: Double { disabled ? 0.2 : 0.4 }

    var body: some View {
        ZStack {
            TriangleDots()
                .foregroundColor(.secondary)
                .frame(width: 12, height: 12)
                .opacity(hovered ? 1 : baseOpacity)
                .animation(.easeInOut(duration: 0.15), value: hovered)
                .padding(6)
                .onHover { hovered = $0 }
                .accessibilityLabel("Resize handle for \(title)")
        }
        .frame(width: 44, height: 44, alignment: .bottomTrailing)
        .contentShape(Rectangle())
        .cursor(.resizeUpDown)
    }
}

struct TriangleDots: View {
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let dotSize = size.width / 4
            Circle()
                .frame(width: dotSize, height: dotSize)
                .position(x: size.width - dotSize / 2, y: size.height - dotSize / 2)
            Circle()
                .frame(width: dotSize, height: dotSize)
                .position(x: size.width - 1.8 * dotSize, y: size.height - 1.8 * dotSize)
            Circle()
                .frame(width: dotSize, height: dotSize)
                .position(x: size.width - 3.1 * dotSize, y: size.height - 3.1 * dotSize)
        }
    }
}

# Preview provider for debugging
struct ResizeHandle_Previews: PreviewProvider {
    static var previews: some View {
        ResizeHandle(title: "Sample")
    }
}
