import XCTest
@testable import DragonShield

final class AssetSubClassPickerModelTests: XCTestCase {
    func testSortAndFilter() {
        let items = [
            AssetSubClassPicker.Item(id: 1, name: "Équity ETF"),
            AssetSubClassPicker.Item(id: 2, name: "crypto fund"),
            AssetSubClassPicker.Item(id: 3, name: "Corporate Bond")
        ]

        let sorted = AssetSubClassPickerModel.sort(items)
        XCTAssertEqual(sorted.map(\.name), ["Corporate Bond", "crypto fund", "Équity ETF"])

        let filtered = AssetSubClassPickerModel.filter(items, query: "equity")
        XCTAssertEqual(filtered.map(\.name), ["Équity ETF"])
    }
}
