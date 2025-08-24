import XCTest
@testable import DragonShield

final class AssetSubClassPickerViewModelTests: XCTestCase {
    func testSortedAlphabeticallyCaseAndDiacriticInsensitive() throws {
        let data: [AssetSubClassPickerViewModel.SubClass] = [
            .init(id: 1, name: "crypto Fund"),
            .init(id: 2, name: "Équity ETF"),
            .init(id: 3, name: "Corporate Bond")
        ]
        let vm = AssetSubClassPickerViewModel(subClasses: data)
        XCTAssertEqual(vm.filtered.map(\.name), ["Corporate Bond", "crypto Fund", "Équity ETF"])
    }

    func testFilteringIsCaseAndDiacriticInsensitive() {
        let data: [AssetSubClassPickerViewModel.SubClass] = [
            .init(id: 1, name: "Equity ETF"),
            .init(id: 2, name: "Equity Fund"),
            .init(id: 3, name: "Hedge Fund")
        ]
        let vm = AssetSubClassPickerViewModel(subClasses: data)
        vm.searchText = "equité"
        let expectation = XCTestExpectation(description: "debounce")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertEqual(vm.filtered.map(\.name), ["Equity ETF", "Equity Fund"])
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}

