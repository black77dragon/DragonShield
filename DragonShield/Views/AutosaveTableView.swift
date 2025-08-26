import SwiftUI
import AppKit

struct AutosaveTableView: NSViewRepresentable {
    let name: String

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let table = findTableView(from: nsView) else { return }
            if table.autosaveName != name {
                Self.configure(table, name: name)
            }
        }
    }

    static func configure(_ table: NSTableView, name: String) {
        table.autosaveName = NSTableView.AutosaveName(name)
        for (index, column) in table.tableColumns.enumerated() {
            column.identifier = NSUserInterfaceItemIdentifier("col\(index)")
        }
        table.sizeToFit()
    }

    private func findTableView(from view: NSView) -> NSTableView? {
        if let table = view as? NSTableView { return table }
        for sub in view.subviews {
            if let table = findTableView(from: sub) { return table }
        }
        if let superview = view.superview {
            return findTableView(from: superview)
        }
        return nil
    }
}
