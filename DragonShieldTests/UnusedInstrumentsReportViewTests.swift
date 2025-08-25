import XCTest
@testable import DragonShield
import AppKit

final class UnusedInstrumentsReportViewTests: XCTestCase {
    func testExportStringIncludesHeadersAndRows() {
        let items = [
            UnusedInstrument(instrumentId: 1, name: "A", type: "Stock", currency: "USD", lastActivity: nil, themesCount: 0, refsCount: 0),
            UnusedInstrument(instrumentId: 2, name: "B", type: "Bond", currency: "CHF", lastActivity: DateFormatter.iso8601DateOnly.date(from: "2024-11-03"), themesCount: 1, refsCount: 0)
        ]
        let csv = UnusedInstrumentsReportView.exportString(items: items)
        XCTAssertTrue(csv.contains("Instrument,Type,Currency,Last Activity,Themes,Refs"))
        XCTAssertTrue(csv.contains("A,Stock,USD,—,0,0"))
        XCTAssertTrue(csv.contains("B,Bond,CHF,2024-11-03,1,0"))
    }

    func testColumnResizeUpdatesStoredWidth() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "unusedInstrumentInstrumentWidth")
        var view = PersistentUnusedInstrumentsTable(items: [], sortOrder: .constant([]))
        let coordinator = view.makeCoordinator()
        let tableView = NSTableView()
        coordinator.tableView = tableView
        let column = NSTableColumn(identifier: NSTableColumn.Identifier("Instrument"))
        column.width = 222
        let exp = expectation(description: "width updated")
        coordinator.columnDidResize(Notification(name: NSTableView.columnDidResizeNotification, object: tableView, userInfo: ["NSTableViewColumn": column]))
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(defaults.double(forKey: "unusedInstrumentInstrumentWidth"), 222)
        defaults.removeObject(forKey: "unusedInstrumentInstrumentWidth")
    }
}
