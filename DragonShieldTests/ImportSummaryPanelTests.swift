import XCTest
import SwiftUI
@testable import DragonShield
#if canImport(AppKit)
import AppKit
#endif

final class ImportSummaryPanelTests: XCTestCase {
    func testTextSelectionEnabled() {
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
        let textFields = hosting.allTextFields()
        XCTAssertTrue(textFields.contains { $0.stringValue.contains("Total Rows: 1") })
        XCTAssertTrue(textFields.contains { $0.stringValue.contains("Sample log") })
        XCTAssertTrue(textFields.allSatisfy(\.isSelectable))
#else
        _ = view.body
#endif
    }
}

#if canImport(AppKit)
private extension NSView {
    func allTextFields() -> [NSTextField] {
        var result: [NSTextField] = []
        func visit(_ view: NSView) {
            if let field = view as? NSTextField {
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
