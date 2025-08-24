import XCTest
import SwiftUI
@testable import DragonShield
#if canImport(AppKit)
import AppKit
#endif

/*
 Test strategy:
 1. Render ImportSummaryPanel containing SelectableLabel components.
 2. For a positive case, programmatically select text, send Command-C via performKeyEquivalent, and verify the pasteboard contains the expected string.
 3. For a negative case, invoke copy without selection and assert the pasteboard remains empty.
*/

final class ImportSummaryPanelTests: XCTestCase {
    func testCopyingSelectableLabelCopiesText() {
        let summary = PositionImportSummary(totalRows: 1,
                                           parsedRows: 1,
                                           cashAccounts: 1,
                                           securityRecords: 0,
                                           unmatchedInstruments: 0,
                                           percentValuationRecords: 0)
        let view = ImportSummaryPanel(summary: summary,
                                      logs: ["Sample log"],
                                      isPresented: .constant(true))
#if canImport(AppKit)
        let hosting = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
                              styleMask: [.borderless],
                              backing: .buffered,
                              defer: false)
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        hosting.layoutSubtreeIfNeeded()
        let textViews = hosting.allTextViews()
        guard let totalRowsView = textViews.first(where: { $0.string.contains("Total Rows: 1") }) else {
            return XCTFail("Missing Total Rows view")
        }
        NSPasteboard.general.clearContents()
        totalRowsView.setSelectedRange(NSRange(location: 0, length: totalRowsView.string.count))
        let event = NSEvent.keyEvent(with: .keyDown,
                                     location: .zero,
                                     modifierFlags: [.command],
                                     timestamp: 0,
                                     windowNumber: window.windowNumber,
                                     context: nil,
                                     characters: "c",
                                     charactersIgnoringModifiers: "c",
                                     isARepeat: false,
                                     keyCode: 8)!
        _ = totalRowsView.performKeyEquivalent(event)
        let pbString = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(pbString, totalRowsView.string)
#else
        _ = view.body
#endif
    }

    func testCopyWithoutSelectionProducesEmptyPasteboardEntry() {
        let summary = PositionImportSummary(totalRows: 1,
                                           parsedRows: 1,
                                           cashAccounts: 1,
                                           securityRecords: 0,
                                           unmatchedInstruments: 0,
                                           percentValuationRecords: 0)
        let view = ImportSummaryPanel(summary: summary,
                                      logs: ["Sample log"],
                                      isPresented: .constant(true))
#if canImport(AppKit)
        let hosting = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
                              styleMask: [.borderless],
                              backing: .buffered,
                              defer: false)
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        hosting.layoutSubtreeIfNeeded()
        let textViews = hosting.allTextViews()
        guard let totalRowsView = textViews.first(where: { $0.string.contains("Total Rows: 1") }) else {
            return XCTFail("Missing Total Rows view")
        }
        NSPasteboard.general.clearContents()
        let event = NSEvent.keyEvent(with: .keyDown,
                                     location: .zero,
                                     modifierFlags: [.command],
                                     timestamp: 0,
                                     windowNumber: window.windowNumber,
                                     context: nil,
                                     characters: "c",
                                     charactersIgnoringModifiers: "c",
                                     isARepeat: false,
                                     keyCode: 8)!
        _ = totalRowsView.performKeyEquivalent(event)
        let pbString = NSPasteboard.general.string(forType: .string)
        XCTAssertNil(pbString)
#else
        _ = view.body
#endif
    }
}

#if canImport(AppKit)
private extension NSView {
    func allTextViews() -> [NSTextView] {
        var result: [NSTextView] = []
        func visit(_ view: NSView) {
            if let field = view as? NSTextView {
                result.append(field)
            }
            for sub in view.subviews {
                visit(sub)
            }
        }
        visit(self)
        return result
    }
}
#endif
