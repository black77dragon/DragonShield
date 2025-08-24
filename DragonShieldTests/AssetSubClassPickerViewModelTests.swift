import XCTest
@testable import DragonShield

final class AssetSubClassPickerViewModelTests: XCTestCase {
    @MainActor
    func testSortingAndFiltering() async throws {
        let items = [
            AssetSubClassItem(id: 1, name: "Équity ETF"),
            AssetSubClassItem(id: 2, name: "corporate bond"),
            AssetSubClassItem(id: 3, name: "Crypto Fund")
        ]
        let viewModel = AssetSubClassPickerViewModel(items: items)
        XCTAssertEqual(viewModel.items.map { $0.name }, ["corporate bond", "Crypto Fund", "Équity ETF"])

        viewModel.updateSearch("equity")
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(viewModel.filteredItems.map { $0.name }, ["Équity ETF"])
    }
}
