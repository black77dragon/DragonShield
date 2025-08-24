import SwiftUI

struct SelectableLabel: View {
    let text: String
    var textStyle: Font.TextStyle

    init(_ text: String, textStyle: Font.TextStyle = .body) {
        self.text = text
        self.textStyle = textStyle
    }

    var body: some View {
        SelectableLabelRepresentable(text: text, textStyle: textStyle)
    }
}

#if os(macOS)
import AppKit

private struct SelectableLabelRepresentable: NSViewRepresentable {
    let text: String
    var textStyle: Font.TextStyle

    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.string = text
        textView.font = NSFont.preferredFont(forTextStyle: NSFont.TextStyle(textStyle))
        return textView
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {
        nsView.string = text
        nsView.font = NSFont.preferredFont(forTextStyle: NSFont.TextStyle(textStyle))
    }
}

private extension NSFont.TextStyle {
    init(_ style: Font.TextStyle) {
        self.init(rawValue: style.rawValue)
    }
}
#elseif os(iOS)
import UIKit

private struct SelectableLabelRepresentable: UIViewRepresentable {
    let text: String
    var textStyle: Font.TextStyle

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.text = text
        textView.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle(textStyle))
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
        uiView.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle(textStyle))
    }
}

private extension UIFont.TextStyle {
    init(_ style: Font.TextStyle) {
        self.init(rawValue: style.rawValue)
    }
}
#endif
