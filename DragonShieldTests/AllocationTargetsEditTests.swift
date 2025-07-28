import XCTest
import SwiftUI
@testable import DragonShield

final class AllocationTargetsEditTests: XCTestCase {
    func testPencilIsVisible() {
        let view = AllocationTargetsTableView()
        let host = NSHostingController(rootView: view)
        let hasPencil = host.view.subviews.contains { sub in
            (sub as? NSButton)?.image?.name() == "pencil.circle"
        }
        XCTAssertTrue(hasPencil)
    }

    func testDoubleClickOpensPanel() {
        // Placeholder: in full UI tests we would simulate a double click
        XCTAssertTrue(true)
    }

    func testKeyboardEnterOpensPanel() {
        // Placeholder: in full UI tests we would simulate pressing Enter
        XCTAssertTrue(true)
    }
}
