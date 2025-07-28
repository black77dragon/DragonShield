import SwiftUI

struct KeyDownModifier: ViewModifier {
    let key: KeyEquivalent
    let action: () -> Void

    func body(content: Content) -> some View {
        content.background(KeyDownRepresentable(key: key, action: action))
    }

    private struct KeyDownRepresentable: NSViewRepresentable {
        let key: KeyEquivalent
        let action: () -> Void

        func makeNSView(context: Context) -> KeyView {
            let view = KeyView()
            view.key = key
            view.action = action
            return view
        }

        func updateNSView(_ nsView: KeyView, context: Context) {}
    }

    private class KeyView: NSView {
        var key: KeyEquivalent = .return
        var action: () -> Void = {}
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with event: NSEvent) {
            if event.charactersIgnoringModifiers == String(key.character ?? "") {
                action()
            } else {
                super.keyDown(with: event)
            }
        }
    }
}

extension View {
    func onKeyDown(_ key: KeyEquivalent, perform action: @escaping () -> Void) -> some View {
        modifier(KeyDownModifier(key: key, action: action))
    }
}
