import SwiftUI

#if os(macOS)
private struct KeyDownModifier: ViewModifier {
    let key: KeyEquivalent
    let action: () -> Void

    func body(content: Content) -> some View {
        content.background(KeyCapture(key: key, action: action))
    }

    private struct KeyCapture: NSViewRepresentable {
        let key: KeyEquivalent
        let action: () -> Void

        func makeNSView(context: Context) -> KeyView {
            let v = KeyView()
            v.key = key
            v.action = action
            return v
        }

        func updateNSView(_ nsView: KeyView, context: Context) {
            nsView.key = key
            nsView.action = action
        }

        class KeyView: NSView {
            var key: KeyEquivalent = .return
            var action: () -> Void = {}
            override var acceptsFirstResponder: Bool { true }
            override func keyDown(with event: NSEvent) {
                if event.charactersIgnoringModifiers == String(Character(key)) {
                    action()
                } else {
                    super.keyDown(with: event)
                }
            }
        }
    }
}

extension View {
    func onKeyDown(_ key: KeyEquivalent, perform action: @escaping () -> Void) -> some View {
        modifier(KeyDownModifier(key: key, action: action))
    }
}
#endif
