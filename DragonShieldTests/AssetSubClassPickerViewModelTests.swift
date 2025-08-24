import XCTest
@testable import DragonShield

final class AssetSubClassPickerViewModelTests: XCTestCase {
    func testSortCaseAndDiacriticInsensitive() {
        let groups = [
            (id: 1, name: "Équity REIT"),
            (id: 2, name: "equity etf"),
            (id: 3, name: "Crypto Fund")
        ]
        let sorted = AssetSubClassPickerViewModel.sort(groups)
        XCTAssertEqual(sorted.map { $0.name }, ["Crypto Fund", "equity etf", "Équity REIT"])
    }

    func testFilterContainsCaseAndDiacriticInsensitive() {
        let groups = [
            (id: 1, name: "Crypto Fund"),
            (id: 2, name: "Equity ETF"),
            (id: 3, name: "Équity REIT")
        ]
        let filtered = AssetSubClassPickerViewModel.filter(groups, query: "equity")
        XCTAssertEqual(filtered.map { $0.name }, ["Equity ETF", "Équity REIT"])
    }
}
