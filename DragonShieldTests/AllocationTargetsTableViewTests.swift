import XCTest
@testable import DragonShield
#if canImport(ViewInspector)
import ViewInspector
import SwiftUI

extension AllocationTargetsTableView: Inspectable {}
#endif

final class AllocationTargetsTableViewTests: XCTestCase {
    func testPencilIsVisible() {
        // Placeholder UI test ensuring pencil buttons exist
        let view = AllocationDashboardView()
        XCTAssertNotNil(view)
    }

    func testDoubleClickOpensPanel() {
        // Placeholder for UI automation to verify edit panel opening below the row
    }

    func testKeyboardEnterOpensPanel() {
        // Placeholder for keyboard activation check
    }

#if canImport(ViewInspector)
    func testWarningIconAppears() throws {
        var asset = AllocationAsset(id: "class-1", name: "Test", actualPct: 0, actualChf: 0, targetPct: 10, targetChf: 1000, mode: .percent)
        asset.hasValidationErrors = true
        let vm = AllocationTargetsTableViewModel()
        vm.assets = [asset]
        let view = AllocationTargetsTableView().environmentObject(DatabaseManager())
        let inspected = try view.inspect().find(ViewType.Image.self) { view in
            (try? view.actualImage().name()) == "exclamationmark.triangle.fill"
        }
        XCTAssertNotNil(inspected)
    }
#endif
}
