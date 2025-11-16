import SwiftUI

private struct DashboardTileBackgroundModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.tileBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.tileBorder, lineWidth: 1)
            )
            .shadow(color: Theme.tileShadow, radius: 3, x: 0, y: 2)
    }
}

extension View {
    func dashboardTileBackground(cornerRadius: CGFloat = 12) -> some View {
        modifier(DashboardTileBackgroundModifier(cornerRadius: cornerRadius))
    }
}
