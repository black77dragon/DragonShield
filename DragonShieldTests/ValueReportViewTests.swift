@testable import DragonShield
import XCTest

final class ValueReportViewTests: XCTestCase {
    func testExportStringProducesHeaderItemsAndTotal() {
        let items = [
            DatabaseManager.ImportSessionValueItem(id: 1, instrument: "InstA", currency: "USD", valueOrig: 1.23, valueChf: 1.11),
            DatabaseManager.ImportSessionValueItem(id: 2, instrument: "InstB", currency: "EUR", valueOrig: 2.34, valueChf: 2.22),
        ]
        let csv = ValueReportView.exportString(items: items, totalValue: 3.33)
        let lines = csv.split(separator: "\n")
        XCTAssertEqual(lines.count, 1 + items.count + 1)
        XCTAssertTrue(lines.first?.contains("Instrument") == true)
        XCTAssertTrue(lines.last?.contains("3.33") == true)
    }
}
