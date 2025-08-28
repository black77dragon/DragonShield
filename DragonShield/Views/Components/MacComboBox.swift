import SwiftUI
import AppKit

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
        if let tcb = cb as? TrackingComboBox {
            tcb.onHover = { [weak coord = context.coordinator] in
                coord?.openPopupIfNeeded()
            }
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
            self.allItems = items
            filter(with: parent.text)
        }

        func filter(with query: String) {
            let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if q.isEmpty {
                filtered = allItems
                indexMap = Array(0..<allItems.count)
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
                    cb.performClick(nil)
                }
            }
        }

        // MARK: - NSComboBoxDataSource
        func numberOfItems(in comboBox: NSComboBox) -> Int { filtered.count }
        func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
            guard index >= 0 && index < filtered.count else { return nil }
            return filtered[index]
        }

        // MARK: - Delegate
        func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            let value = tf.stringValue
            parent.text = value
            filter(with: value)
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            openPopupIfNeeded()
        }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let cb = notification.object as? NSComboBox else { return }
            let idx = cb.indexOfSelectedItem
            guard idx >= 0 && idx < indexMap.count else { return }
            let original = indexMap[idx]
            parent.text = filtered[idx]
            parent.onSelectIndex(original)
        }

        func comboBoxWillPopUp(_ notification: Notification) {
            popupVisible = true
        }

        func comboBoxWillDismiss(_ notification: Notification) {
            popupVisible = false
        }

        func openPopupIfNeeded() {
            if popupVisible { return }
            combo?.reloadData()
            combo?.noteNumberOfItemsChanged()
            combo?.performClick(nil)
        }
    }
}

private final class TrackingComboBox: NSComboBox {
    var onHover: (() -> Void)?
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
}
