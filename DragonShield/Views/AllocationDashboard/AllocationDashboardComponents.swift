import SwiftUI

struct Card<Content: View>: View {
    let title: String?
    let content: Content
    let paddingValue: CGFloat
    @Environment(\.colorScheme) private var scheme

    init(_ title: String? = nil, padding: CGFloat = 24, @ViewBuilder content: () -> Content) {
        self.title = title
        self.paddingValue = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = title {
                Text(title)
                    .font(.headline)
            }
            content
        }
        .padding(paddingValue)
        .background(
            Group {
                if scheme == .dark {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.tertiary, lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.quaternary, lineWidth: 1)
                        )
                }
            }
        )
    }
}
