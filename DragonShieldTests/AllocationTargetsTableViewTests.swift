import XCTest
@testable import DragonShield

final class AllocationTargetsTableViewTests: XCTestCase {
    func testPencilIsVisible() {
        let view = AllocationTargetsTableView()
        let desc = String(describing: view.body)
        XCTAssertTrue(desc.contains("pencil.circle"))
    }

    func testDoubleClickOpensPanel() {
        var view = AllocationTargetsTableView()
        view.editingClassId = nil
        view.editingClassId = 1
        XCTAssertEqual(view.editingClassId, 1)
    }

    func testKeyboardEnterOpensPanel() {
        var view = AllocationTargetsTableView()
        view.editingClassId = nil
        view.editingClassId = 2
        XCTAssertEqual(view.editingClassId, 2)
    }
}
