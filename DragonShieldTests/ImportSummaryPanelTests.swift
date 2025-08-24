import XCTest
import SwiftUI
@testable import DragonShield
#if canImport(AppKit)
import AppKit
#endif

/// Test strategy
/// 1. Host the view and retrieve `NSTextView` instances from `SelectableLabel`.
/// 2. Positive case: select text, simulate Command-C, and verify pasteboard contents.
/// 3. Negative case: copy without selection and ensure pasteboard remains empty.
final class ImportSummaryPanelTests: XCTestCase {
    func testCopyCopiesSelectedText() {
        let summary = PositionImportSummary(totalRows: 1,
                                           parsedRows: 1,
                                           cashAccounts: 1,
                                           securityRecords: 0,
                                           unmatchedInstruments: 0,
                                           percentValuationRecords: 0)
        let log = "Sample log"
        let view = ImportSummaryPanel(summary: summary,
                                      logs: [log],
                                      isPresented: .constant(true))
#if canImport(AppKit)
        let hosting = NSHostingView(rootView: view)
        hosting.layoutSubtreeIfNeeded()
        let textViews = hosting.allTextViews()
        guard let summaryView = textViews.first(where: { $0.string.contains("Total Rows: 1") }),
              let logView = textViews.first(where: { $0.string.contains(log) }) else {
            XCTFail("Missing text views")
            return
        }
        let cmdC = NSEvent.keyEvent(with: .keyDown,
                                    location: .zero,
                                    modifierFlags: [.command],
                                    timestamp: 0,
                                    windowNumber: 0,
                                    context: nil,
                                    characters: "c",
                                    charactersIgnoringModifiers: "c",
                                    isARepeat: false,
                                    keyCode: 8)!
        NSPasteboard.general.clearContents()
        summaryView.selectAll(nil)
        _ = summaryView.performKeyEquivalent(cmdC)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "Total Rows: 1")
        NSPasteboard.general.clearContents()
        logView.selectAll(nil)
        _ = logView.performKeyEquivalent(cmdC)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), log)
#else
        _ = view.body
#endif
    }

    func testCopyWithoutSelectionIsEmpty() {
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
        guard let anyView = textViews.first else {
            XCTFail("No text view found")
            return
        }
        NSPasteboard.general.clearContents()
        let cmdC = NSEvent.keyEvent(with: .keyDown,
                                    location: .zero,
                                    modifierFlags: [.command],
                                    timestamp: 0,
                                    windowNumber: 0,
                                    context: nil,
                                    characters: "c",
                                    charactersIgnoringModifiers: "c",
                                    isARepeat: false,
                                    keyCode: 8)!
        _ = anyView.performKeyEquivalent(cmdC)
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
            if let textView = view as? NSTextView {
                result.append(textView)
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
