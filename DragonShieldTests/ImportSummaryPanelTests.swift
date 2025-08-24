import XCTest
import SwiftUI
@testable import DragonShield
#if canImport(AppKit)
import AppKit
#endif

/*
 Test strategy
 ----------------
 These tests render `ImportSummaryPanel`, which uses `SelectableLabel` wrapping
 `NSTextView` for copyable text. We programmatically select text, simulate a
 Command-C key press via `performKeyEquivalent`, and confirm the pasted content
 via `NSPasteboard`. A negative test verifies that copying without an active
 selection leaves the pasteboard empty.
 */
final class ImportSummaryPanelTests: XCTestCase {
    func testCopySelectedText() {
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
        hosting.layoutSubtreeIfNeeded()
        let textViews = hosting.allTextViews()
        let copyEvent = NSEvent.keyEvent(with: .keyDown,
                                         location: .zero,
                                         modifierFlags: .command,
                                         timestamp: 0,
                                         windowNumber: 0,
                                         context: nil,
                                         characters: "c",
                                         charactersIgnoringModifiers: "c",
                                         isARepeat: false,
                                         keyCode: 8)!
        // Summary field
        let summaryView = textViews.first { $0.string.contains("Total Rows: 1") }!
        NSPasteboard.general.clearContents()
        summaryView.selectAll(nil)
        summaryView.performKeyEquivalent(copyEvent)
        let summaryPaste = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(summaryPaste, "Total Rows: 1")
        // Log message
        let logView = textViews.first { $0.string.contains("Sample log") }!
        NSPasteboard.general.clearContents()
        logView.selectAll(nil)
        logView.performKeyEquivalent(copyEvent)
        let logPaste = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(logPaste, "Sample log")
#else
        _ = view.body
#endif
    }

    func testCopyWithoutSelectionProducesEmptyPasteboard() {
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
        hosting.layoutSubtreeIfNeeded()
        let textViews = hosting.allTextViews()
        let copyEvent = NSEvent.keyEvent(with: .keyDown,
                                         location: .zero,
                                         modifierFlags: .command,
                                         timestamp: 0,
                                         windowNumber: 0,
                                         context: nil,
                                         characters: "c",
                                         charactersIgnoringModifiers: "c",
                                         isARepeat: false,
                                         keyCode: 8)!
        NSPasteboard.general.clearContents()
        textViews.first?.performKeyEquivalent(copyEvent)
        XCTAssertNil(NSPasteboard.general.string(forType: .string))
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
            if let tv = view as? NSTextView {
                result.append(tv)
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
