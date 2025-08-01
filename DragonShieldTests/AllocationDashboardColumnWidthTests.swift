import XCTest
@testable import DragonShield

final class AllocationDashboardColumnWidthTests: XCTestCase {
    func testDefaultWidths() {
        // Ensure default widths load when no user defaults stored
        UserDefaults.standard.removeObject(forKey: "ui.assetAllocation.columnWidths")
        let card = AllocationTreeCard(viewModel: AllocationDashboardViewModel())
        XCTAssertEqual(card.widths.target, 110, accuracy: 0.1)
        XCTAssertEqual(card.widths.actual, 110, accuracy: 0.1)
        XCTAssertEqual(card.widths.bar, 110, accuracy: 0.1)
    }

    func testCustomWidthsPersist() {
        let data: [String: Double] = ["targetCol": 160, "actualCol": 120, "deviationCol": 140]
        UserDefaults.standard.set(data, forKey: "ui.assetAllocation.columnWidths")
        var card = AllocationTreeCard(viewModel: AllocationDashboardViewModel())
        XCTAssertEqual(card.widths.target, 160, accuracy: 0.1)
        XCTAssertEqual(card.widths.actual, 120, accuracy: 0.1)
        XCTAssertEqual(card.widths.bar, 140, accuracy: 0.1)
        UserDefaults.standard.removeObject(forKey: "ui.assetAllocation.columnWidths")
    }
}
