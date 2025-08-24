import XCTest
import SwiftUI
@testable import DragonShield
#if canImport(AppKit)
import AppKit
#endif

/// These tests ensure that text within ImportSummaryPanel is truly copyable.
/// We programmatically select text in underlying NSTextView instances,
/// issue Command-C via `performKeyEquivalent`, and validate the pasteboard.
/// A negative test verifies that invoking copy with no selection leaves the
/// pasteboard empty, preventing false positives.
final class ImportSummaryPanelTests: XCTestCase {
    func testCopyingSummaryAndLogText() {
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
        hosting.frame = NSRect(x: 0, y: 0, width: 300, height: 300)
        let window = NSWindow(contentRect: hosting.bounds, styleMask: [], backing: .buffered, defer: false)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        let textViews = hosting.allTextViews()
        guard let summaryView = textViews.first(where: { $0.string.contains("Total Rows: 1") }) else {
            return XCTFail("Missing summary text view")
        }
        let event = NSEvent.keyEvent(with: .keyDown,
                                     location: .zero,
                                     modifierFlags: .command,
                                     timestamp: 0,
                                     windowNumber: window.windowNumber,
                                     context: nil,
                                     characters: "c",
                                     charactersIgnoringModifiers: "c",
                                     isARepeat: false,
                                     keyCode: 8)!
        window.makeFirstResponder(summaryView)
        summaryView.setSelectedRange(NSRange(location: 0, length: summaryView.string.count))
        NSPasteboard.general.clearContents()
        summaryView.performKeyEquivalent(with: event)
        let summaryPaste = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(summaryPaste, summaryView.string)
        guard let logView = textViews.first(where: { $0.string.contains("Sample log") }) else {
            return XCTFail("Missing log text view")
        }
        window.makeFirstResponder(logView)
        logView.setSelectedRange(NSRange(location: 0, length: logView.string.count))
        NSPasteboard.general.clearContents()
        logView.performKeyEquivalent(with: event)
        let logPaste = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(logPaste, logView.string)
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
        hosting.frame = NSRect(x: 0, y: 0, width: 300, height: 300)
        let window = NSWindow(contentRect: hosting.bounds, styleMask: [], backing: .buffered, defer: false)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        let textViews = hosting.allTextViews()
        guard let summaryView = textViews.first(where: { $0.string.contains("Total Rows: 1") }) else {
            return XCTFail("Missing summary text view")
        }
        let event = NSEvent.keyEvent(with: .keyDown,
                                     location: .zero,
                                     modifierFlags: .command,
                                     timestamp: 0,
                                     windowNumber: window.windowNumber,
                                     context: nil,
                                     characters: "c",
                                     charactersIgnoringModifiers: "c",
                                     isARepeat: false,
                                     keyCode: 8)!
        window.makeFirstResponder(summaryView)
        NSPasteboard.general.clearContents()
        summaryView.performKeyEquivalent(with: event)
        let paste = NSPasteboard.general.string(forType: .string)
        XCTAssertNil(paste)
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
