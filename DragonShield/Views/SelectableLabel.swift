import SwiftUI

/// A text view that allows users to select and copy its contents.
struct SelectableLabel: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Representable(text: text)
    }

    #if os(macOS)
    private struct Representable: NSViewRepresentable {
        let text: String
        @Environment(\.font) private var font

        func makeNSView(context: Context) -> NSTextView {
            let view = NSTextView()
            view.isEditable = false
            view.isSelectable = true
            view.drawsBackground = false
            view.textContainerInset = .zero
            view.textContainer?.lineFragmentPadding = 0
            return view
        }

        func updateNSView(_ nsView: NSTextView, context: Context) {
            nsView.string = text
            if let font {
                nsView.font = NSFont(font)
            }
        }
    }
    #else
    private struct Representable: UIViewRepresentable {
        let text: String
        @Environment(\.font) private var font

        func makeUIView(context: Context) -> UITextView {
            let view = UITextView()
            view.isEditable = false
            view.isSelectable = true
            view.backgroundColor = .clear
            view.textContainerInset = .zero
            view.textContainer.lineFragmentPadding = 0
            return view
        }

        func updateUIView(_ uiView: UITextView, context: Context) {
            uiView.text = text
            if let font {
                uiView.font = UIFont(font)
            }
        }
    }
    #endif
}
