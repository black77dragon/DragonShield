@testable import DragonShield
import XCTest

final class AssetSubClassPickerTests: XCTestCase {
    func testSortAlphabeticalCaseDiacriticInsensitive() {
        let groups: [(id: Int, name: String)] = [
            (1, "Équity"),
            (2, "crypto Fund"),
            (3, "Corporate Bond"),
        ]
        let sorted = AssetSubClassPickerModel.sort(groups)
        XCTAssertEqual(sorted.map { $0.name }, ["Corporate Bond", "crypto Fund", "Équity"])
    }

    func testFilterContainsCaseDiacriticInsensitive() {
        let groups: [(id: Int, name: String)] = [
            (1, "Équity ETF"),
            (2, "Corporate Bond"),
            (3, "Crypto Fund"),
        ]
        let filtered = AssetSubClassPickerModel.filter(groups, query: "equity")
        XCTAssertEqual(filtered.map { $0.name }, ["Équity ETF"])
    }
}
