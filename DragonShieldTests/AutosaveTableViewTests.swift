import AppKit
@testable import DragonShield
import XCTest

final class AutosaveTableViewTests: XCTestCase {
    func testConfigureSetsAutosaveAndIdentifiers() {
        let table = NSTableView()
        table.addTableColumn(NSTableColumn())
        table.addTableColumn(NSTableColumn())
        AutosaveTableView.configure(table, name: "TestTable")
        XCTAssertEqual(table.autosaveName, "TestTable")
        XCTAssertEqual(table.tableColumns[0].identifier.rawValue, "col0")
        XCTAssertEqual(table.tableColumns[1].identifier.rawValue, "col1")
    }
}
