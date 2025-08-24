import XCTest
@testable import DragonShield

final class AssetSubClassFilterTests: XCTestCase {
    func testSortCaseAndDiacriticInsensitive() {
        let items = [(id: 1, name: "éclair"), (id: 2, name: "Banana"), (id: 3, name: "apple")]
        let sorted = AssetSubClassFilter.sort(items)
        XCTAssertEqual(sorted.map { $0.name }, ["apple", "Banana", "éclair"])
    }

    func testFilterContainsCaseAndDiacriticInsensitive() {
        let items = [(id: 1, name: "Équity ETF"), (id: 2, name: "Crypto Fund"), (id: 3, name: "Government Bond")]
        let filtered = AssetSubClassFilter.filter(items, query: "equity")
        XCTAssertEqual(filtered.map { $0.name }, ["Équity ETF"])
        let filteredAccent = AssetSubClassFilter.filter(items, query: "éQuItY")
        XCTAssertEqual(filteredAccent.map { $0.name }, ["Équity ETF"])
    }
}
