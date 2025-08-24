import SwiftUI

struct SelectableLabel: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Representable(text: text)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#if os(macOS)
import AppKit
private struct Representable: NSViewRepresentable {
    let text: String
    @Environment(\.font) private var font

    func makeNSView(context: Context) -> NSTextView {
        let view = NSTextView()
        view.isEditable = false
        view.isSelectable = true
        view.drawsBackground = false
        view.isRichText = false
        view.importsGraphics = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        return view
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {
        nsView.string = text
        if let font = font {
            nsView.font = NSFont(font)
        }
    }
}
#else
import UIKit
private struct Representable: UIViewRepresentable {
    let text: String
    @Environment(\.font) private var font

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
        if let font = font {
            uiView.font = UIFont(font)
        }
    }
}
#endif
