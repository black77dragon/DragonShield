import XCTest
@testable import DragonShield

final class ValueReportViewTests: XCTestCase {
    func testViewInitializes() {
        let item = DatabaseManager.ImportSessionValueItem(id: 1, instrument: "Test", currency: "CHF", valueOrig: 1.0, valueChf: 1.0)
        let view = ValueReportView(items: [item], totalValue: 1.0) {}
        XCTAssertNotNil(view.body)
    }
}
