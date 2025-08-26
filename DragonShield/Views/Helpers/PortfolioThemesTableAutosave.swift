import SwiftUI
import AppKit

struct PortfolioThemesTableAutosave: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let table = view.enclosingScrollView?.documentView as? NSTableView {
                table.autosaveName = "PortfolioThemesTable"
                table.autosaveTableColumns = true
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

