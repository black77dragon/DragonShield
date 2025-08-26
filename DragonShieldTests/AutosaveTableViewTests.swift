import XCTest
@testable import DragonShield
import AppKit

final class AutosaveTableViewTests: XCTestCase {
    func testConfigureSetsAutosaveAndIdentifiers() {
        let table = NSTableView()
        table.addTableColumn(NSTableColumn())
        table.addTableColumn(NSTableColumn())
        AutosaveTableView.configure(table, name: "TestTable")
        XCTAssertEqual(table.autosaveName?.rawValue, "TestTable")
        XCTAssertEqual(table.tableColumns[0].identifier.rawValue, "col0")
        XCTAssertEqual(table.tableColumns[1].identifier.rawValue, "col1")
    }
}
