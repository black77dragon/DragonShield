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
        let cb = NSComboBox()
        cb.usesDataSource = true
        cb.isEditable = true
        cb.completes = false
        cb.delegate = context.coordinator
        cb.dataSource = context.coordinator
        cb.numberOfVisibleItems = 12
        cb.intercellSpacing = NSSize(width: 4, height: 2)
        cb.isButtonBordered = true
        cb.stringValue = text
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
        }
    }

    final class Coordinator: NSObject, NSComboBoxDataSource, NSComboBoxDelegate, NSTextFieldDelegate {
        var parent: MacComboBox
        private var allItems: [String] = []
        private var filtered: [String] = []
        private var indexMap: [Int] = [] // filtered index -> original index

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
            if let cb = tf.superview as? NSComboBox {
                cb.reloadData()
                cb.noteNumberOfItemsChanged()
            }
        }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let cb = notification.object as? NSComboBox else { return }
            let idx = cb.indexOfSelectedItem
            guard idx >= 0 && idx < indexMap.count else { return }
            let original = indexMap[idx]
            parent.text = filtered[idx]
            parent.onSelectIndex(original)
        }
    }
}

