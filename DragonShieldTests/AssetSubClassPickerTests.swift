import XCTest
@testable import DragonShield

final class AssetSubClassPickerTests: XCTestCase {
    func testSortingIsCaseAndDiacriticInsensitive() {
        let options = [
            AssetSubClassOption(id: 1, name: "Crypto Fund"),
            AssetSubClassOption(id: 2, name: "Équity ETF"),
            AssetSubClassOption(id: 3, name: "corporate bond")
        ]
        let result = AssetSubClassPickerLogic.filteredOptions(from: options, query: "")
        XCTAssertEqual(result.map { $0.name }, ["corporate bond", "Crypto Fund", "Équity ETF"])
    }

    func testFilteringIsCaseAndDiacriticInsensitive() {
        let options = [
            AssetSubClassOption(id: 1, name: "Crypto Fund"),
            AssetSubClassOption(id: 2, name: "Équity ETF"),
            AssetSubClassOption(id: 3, name: "Equity Fund"),
            AssetSubClassOption(id: 4, name: "Infrastructure")
        ]
        let result = AssetSubClassPickerLogic.filteredOptions(from: options, query: "equity")
        XCTAssertEqual(result.map { $0.name }, ["Équity ETF", "Equity Fund"])
    }
}
