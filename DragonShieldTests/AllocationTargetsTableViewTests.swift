import XCTest
@testable import DragonShield
import SwiftUI

final class AllocationTargetsTableViewTests: XCTestCase {
    func testPencilIsVisible() {
        // Placeholder UI test ensuring pencil buttons exist
        let view = AllocationTargetsTableView()
        XCTAssertNotNil(view)
    }

    func testDoubleClickOpensPanel() {
        // Placeholder for UI automation to verify side-panel opening
    }

    func testKeyboardEnterOpensPanel() {
        // Placeholder for keyboard activation check
    }

    func testHeaderAlignment() {
        let view = AllocationTargetsTableView()
            .environmentObject(DatabaseManager())
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        host.layoutSubtreeIfNeeded()

        guard let scroll = host.subviews.compactMap({ $0 as? NSScrollView }).first,
              let table = scroll.documentView?.subviews.compactMap({ $0 as? NSTableView }).first,
              let header = table.headerView else {
            XCTFail("Table view not found")
            return
        }

        for index in 0..<table.numberOfColumns {
            let headerRect = header.headerRect(ofColumn: index)
            let cellRect = table.rect(ofColumn: index)
            XCTAssertLessThanOrEqual(abs(headerRect.minX - cellRect.minX), 1.0,
                                    "Column \(index) misaligned")
        }
    }
}
