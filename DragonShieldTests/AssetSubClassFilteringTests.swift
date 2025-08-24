import XCTest
@testable import DragonShield

final class AssetSubClassFilteringTests: XCTestCase {
    func testSortingAndFiltering() {
        let items = [
            AssetSubClassItem(id: 1, name: "Équity ETF"),
            AssetSubClassItem(id: 2, name: "corporate bond"),
            AssetSubClassItem(id: 3, name: "Crypto Fund")
        ]
        let sorted = AssetSubClassFilter.sort(items)
        XCTAssertEqual(sorted.map(\.$name), ["corporate bond", "Crypto Fund", "Équity ETF"])

        let filtered = AssetSubClassFilter.filter(items, query: "equity")
        XCTAssertEqual(filtered.map(\.$name), ["Équity ETF"])
    }
}
