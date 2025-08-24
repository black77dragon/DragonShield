import SwiftUI

struct SelectableLabel: View {
    let text: String
    @Environment(\.font) private var font

    var body: some View {
#if os(macOS)
        Representable(text: text, font: font)
#else
        Representable(text: text, font: font)
#endif
    }
}

#if os(macOS)
import AppKit

private struct Representable: NSViewRepresentable {
    let text: String
    let font: Font?

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
        nsView.font = NSFont(font ?? .body) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
    }
}
#else
import UIKit

private struct Representable: UIViewRepresentable {
    let text: String
    let font: Font?

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
        uiView.font = UIFont(font ?? .body) ?? UIFont.systemFont(ofSize: UIFont.systemFontSize)
    }
}
#endif
