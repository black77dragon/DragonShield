import XCTest
@testable import DragonShield

final class AssetSubClassLookupTests: XCTestCase {
    func testSortingIsCaseAndDiacriticInsensitive() {
        let groups = [(1, "Équity"), (2, "corporate bond"), (3, "equity ETF")]
        let sorted = AssetSubClassLookup.sort(groups)
        XCTAssertEqual(sorted.map { $0.name }, ["corporate bond", "equity ETF", "Équity"])
    }

    func testFilterContainsCaseAndDiacriticInsensitive() {
        let groups = [(1, "Corporate Bond"), (2, "Equity ETF"), (3, "Equity Fund")]
        let filtered = AssetSubClassLookup.filter(groups, query: "equité")
        XCTAssertEqual(filtered.map { $0.name }, ["Equity ETF", "Equity Fund"])
    }
}
