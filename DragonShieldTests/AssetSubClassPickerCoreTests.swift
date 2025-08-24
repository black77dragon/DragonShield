import XCTest
@testable import DragonShield

final class AssetSubClassPickerCoreTests: XCTestCase {
    func testSortAssetSubClasses() {
        let items: [AssetSubClassItem] = [
            (id: 1, name: "Cryptocurrency"),
            (id: 2, name: "Équity ETF"),
            (id: 3, name: "corporate bond")
        ]
        let sorted = sortAssetSubClasses(items)
        XCTAssertEqual(sorted.map { $0.name }, ["corporate bond", "Cryptocurrency", "Équity ETF"])
    }

    func testFilterAssetSubClasses() {
        let items: [AssetSubClassItem] = [
            (id: 1, name: "Equity ETF"),
            (id: 2, name: "Equity Fund"),
            (id: 3, name: "Équity REIT"),
            (id: 4, name: "Corporate Bond")
        ]
        let filtered = filterAssetSubClasses(items, query: "equity")
        XCTAssertEqual(filtered.map { $0.name }, ["Equity ETF", "Equity Fund", "Équity REIT"])
    }
}
