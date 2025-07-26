import SwiftUI

struct Card<Content: View>: View {
    let title: String
    let content: Content
    @State private var isHovering = false
    private var dragGesture: some Gesture { DragGesture() }

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.headline)
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.quaternary, lineWidth: 1))
            .overlay(
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .resizable()
                    .frame(width: 12, height: 12)
                    .opacity(isHovering ? 1 : 0.4)
                    .padding(8)
                    .background(.thinMaterial, in: Circle())
                    .position(x: geometry.size.width - 10, y: geometry.size.height - 10)
                    .gesture(dragGesture)
                    .onHover { isHovering = $0 }
            )
        }
        .frame(minHeight: 100)
    }
}
