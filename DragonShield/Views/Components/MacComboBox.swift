import AppKit
import SwiftUI

struct MacComboBox: NSViewRepresentable {
    var items: [String]
    @Binding var text: String
    var onSelectIndex: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSComboBox {
        let cb = TrackingComboBox()
        cb.usesDataSource = true
        cb.isEditable = true
        cb.completes = false
        cb.delegate = context.coordinator
        cb.dataSource = context.coordinator
        cb.numberOfVisibleItems = 12
        cb.intercellSpacing = NSSize(width: 4, height: 2)
        cb.isButtonBordered = true
        cb.stringValue = text
        cb.onHover = { [weak coord = context.coordinator] in
            coord?.openPopupSoon()
        }
        cb.onFocus = { [weak coord = context.coordinator] in
            coord?.openPopupSoon()
        }
        context.coordinator.combo = cb
        context.coordinator.setItems(items)
        return cb
    }

    func updateNSView(_ nsView: NSComboBox, context: Context) {
        context.coordinator.parent = self
        context.coordinator.setItems(items)
        if nsView.stringValue != text {
            nsView.stringValue = text
            context.coordinator.filter(with: text)
            nsView.reloadData()
            nsView.noteNumberOfItemsChanged()
        } else {
            // If items were just loaded while the field is being edited, ensure the popup shows
            if nsView.currentEditor() != nil {
                context.coordinator.openPopupSoon()
            }
        }
    }

    final class Coordinator: NSObject, NSComboBoxDataSource, NSComboBoxDelegate, NSTextFieldDelegate {
        var parent: MacComboBox
        private var allItems: [String] = []
        private var filtered: [String] = []
        private var indexMap: [Int] = [] // filtered index -> original index
        weak var combo: NSComboBox?
        private var popupVisible = false

        init(_ parent: MacComboBox) {
            self.parent = parent
            super.init()
        }

        func setItems(_ items: [String]) {
            allItems = items
            filter(with: parent.text)
        }

        func filter(with query: String) {
            let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if q.isEmpty {
                filtered = allItems
                indexMap = Array(0 ..< allItems.count)
            } else {
                var f: [String] = []
                var map: [Int] = []
                for (i, s) in allItems.enumerated() {
                    if s.lowercased().contains(q) {
                        f.append(s)
                        map.append(i)
                    }
                }
                filtered = f
                indexMap = map
            }
            // Keep popup visible and up-to-date while typing
            if let cb = combo {
                cb.reloadData()
                cb.noteNumberOfItemsChanged()
                if !popupVisible {
                    DispatchQueue.main.async { self.openDropdown(cb) }
                }
            }
        }

        // MARK: - NSComboBoxDataSource

        func numberOfItems(in _: NSComboBox) -> Int { filtered.count }
        func comboBox(_: NSComboBox, objectValueForItemAt index: Int) -> Any? {
            guard index >= 0, index < filtered.count else { return nil }
            return filtered[index]
        }

        // MARK: - Delegate

        func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            let value = tf.stringValue
            parent.text = value
            filter(with: value)
            // Ensure the popup appears while typing to show filtered matches
            openPopupSoon()
        }

        func controlTextDidBeginEditing(_: Notification) {
            openPopupSoon()
        }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let cb = notification.object as? NSComboBox else { return }
            let idx = cb.indexOfSelectedItem
            guard idx >= 0, idx < indexMap.count else { return }
            let original = indexMap[idx]
            parent.text = filtered[idx]
            parent.onSelectIndex(original)
        }

        func comboBoxWillPopUp(_: Notification) {
            popupVisible = true
        }

        func comboBoxWillDismiss(_: Notification) {
            popupVisible = false
        }

        func openPopupIfNeeded() {
            if popupVisible { return }
            guard let cb = combo else { return }
            cb.reloadData()
            cb.noteNumberOfItemsChanged()
            openDropdown(cb)
        }

        func openPopupSoon() {
            guard let cb = combo else { return }
            if popupVisible { return }
            // Defer to next runloop so focus/first-responder changes settle
            DispatchQueue.main.async {
                cb.reloadData()
                cb.noteNumberOfItemsChanged()
                self.openDropdown(cb)
            }
        }

        // More robust way to open the popup across macOS versions
        private func openDropdown(_ cb: NSComboBox) {
            if cb.responds(to: Selector(("togglePopup:"))) {
                cb.perform(Selector(("togglePopup:")), with: nil)
            } else {
                cb.performClick(nil)
            }
        }
    }
}

private final class TrackingComboBox: NSComboBox {
    var onHover: (() -> Void)?
    var onFocus: (() -> Void)?
    private var tracking: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = tracking { removeTrackingArea(t) }
        let opts: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        tracking = NSTrackingArea(rect: .zero, options: opts, owner: self, userInfo: nil)
        addTrackingArea(tracking!)
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onHover?()
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        onFocus?()
    }

    override func becomeFirstResponder() -> Bool {
        let res = super.becomeFirstResponder()
        onFocus?()
        return res
    }
}
