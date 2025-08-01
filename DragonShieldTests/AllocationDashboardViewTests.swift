import XCTest
@testable import DragonShield

final class AllocationDashboardViewTests: XCTestCase {
    func testColumnWidthsPersistence() {
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.assetAllocationColumnWidths)
        let loaded = AllocationTreeCard.loadWidths()
        XCTAssertEqual(loaded.target, 110, accuracy: 0.1)
        XCTAssertEqual(loaded.actual, 110, accuracy: 0.1)
        XCTAssertEqual(loaded.bar, 110, accuracy: 0.1)
    }
}
