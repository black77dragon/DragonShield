import SwiftUI

struct DashboardResizeHandle: View {
    let title: String
    @State private var hovering = false

    var body: some View {
        Image(systemName: "square.and.arrow.up.right")
            .resizable()
            .frame(width: 12, height: 12)
            .rotationEffect(.degrees(45))
            .foregroundColor(.secondary)
            .opacity(hovering ? 1 : 0.4)
            .padding(8)
            .frame(width: 44, height: 44, alignment: .bottomTrailing)
            .contentShape(Rectangle())
            .cursor(.resizeUpDown)
            .onHover { hovering = $0 }
            .animation(.easeInOut(duration: 0.15), value: hovering)
            .accessibilityLabel("Resize handle for \(title)")
    }
}

struct DashboardResizeHandleModifier: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottomTrailing) {
            DashboardResizeHandle(title: title)
        }
    }
}

extension View {
    func dashboardResizeHandle(title: String) -> some View {
        modifier(DashboardResizeHandleModifier(title: title))
    }
}

