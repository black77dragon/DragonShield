import XCTest
@testable import DragonShield

final class AssetSubClassSearchTests: XCTestCase {
    func testSortAndFilter() {
        let items: [(id: Int, name: String)] = [
            (1, "Crypto Fund"),
            (2, "Équity Fund"),
            (3, "Corporate Bond"),
            (4, "Equity ETF")
        ]

        let sortedPairs = AssetSubClassSearch.sort(items)
        XCTAssertEqual(sortedPairs.map { $0.name }, [
            "Corporate Bond",
            "Crypto Fund",
            "Equity ETF",
            "Équity Fund"
        ])

        let filtered = AssetSubClassSearch.filter(sortedPairs, query: "equity").map { $0.name }
        XCTAssertEqual(filtered, ["Equity ETF", "Équity Fund"])
    }
}
