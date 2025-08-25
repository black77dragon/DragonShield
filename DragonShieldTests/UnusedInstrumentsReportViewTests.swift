import XCTest
@testable import DragonShield

final class UnusedInstrumentsReportViewTests: XCTestCase {
    func testExportStringIncludesTotals() {
        let items = [
            UnusedInstrument(instrumentId: 1, name: "A", type: "Stock", currency: "USD", lastActivity: nil, themesCount: 0, refsCount: 0),
            UnusedInstrument(instrumentId: 2, name: "B", type: "Stock", currency: "EUR", lastActivity: nil, themesCount: 0, refsCount: 0)
        ]
        let csv = UnusedInstrumentsReportView.exportString(items: items)
        let lines = csv.split(separator: "\n")
        XCTAssertEqual(lines.count, 1 + items.count + 1)
        XCTAssertTrue(lines.first?.contains("Instrument") == true)
        XCTAssertTrue(lines.last?.contains("Totals: 2 instruments") == true)
    }
}
