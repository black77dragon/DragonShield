import AppKit
import SwiftUI

struct AutosaveTableView: NSViewRepresentable {
    let name: String

    func makeNSView(context _: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context _: Context) {
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
        var visited = Set<ObjectIdentifier>()
        return findTableView(from: view, visited: &visited)
    }

    private func findTableView(from view: NSView, visited: inout Set<ObjectIdentifier>) -> NSTableView? {
        let identifier = ObjectIdentifier(view)
        guard !visited.contains(identifier) else { return nil }
        visited.insert(identifier)

        if let table = view as? NSTableView {
            return table
        }

        for sub in view.subviews {
            if let table = findTableView(from: sub, visited: &visited) {
                return table
            }
        }

        if let superview = view.superview {
            return findTableView(from: superview, visited: &visited)
        }

        return nil
    }
}
