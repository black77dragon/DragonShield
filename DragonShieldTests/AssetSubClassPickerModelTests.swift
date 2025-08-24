import XCTest
@testable import DragonShield

final class AssetSubClassPickerModelTests: XCTestCase {
    func testSortAndFilter() {
        let options: [AssetSubClassOption] = [
            .init(id: 1, name: "Éclair"),
            .init(id: 2, name: "beta"),
            .init(id: 3, name: "Alpha")
        ]
        let sorted = AssetSubClassPickerModel.sort(options)
        XCTAssertEqual(sorted.map { $0.name }, ["Alpha", "beta", "Éclair"])

        let filtered = AssetSubClassPickerModel.filter(options, query: "écl")
        XCTAssertEqual(filtered.map { $0.name }, ["Éclair"])

        let all = AssetSubClassPickerModel.filter(options, query: "")
        XCTAssertEqual(all.map { $0.name }, ["Alpha", "beta", "Éclair"])
    }
}
