import XCTest
import SQLite3
@testable import DragonShield

final class PortfolioThemeUpdateTests: XCTestCase {
    var manager: DatabaseManager!
    var memdb: OpaquePointer?

    override func setUp() {
        super.setUp()
        manager = DatabaseManager()
        sqlite3_open(":memory:", &memdb)
        manager.db = memdb
        sqlite3_exec(manager.db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
        sqlite3_exec(manager.db, "CREATE TABLE PortfolioTheme(id INTEGER PRIMARY KEY);", nil, nil, nil)
        sqlite3_exec(manager.db, "INSERT INTO PortfolioTheme(id) VALUES (1);", nil, nil, nil)
        manager.ensurePortfolioThemeUpdateTable()
    }

    override func tearDown() {
        sqlite3_close(memdb)
        memdb = nil
        manager = nil
        super.tearDown()
    }

    func testCreateUpdateDeleteFlow() {
        let created = manager.createThemeUpdate(themeId: 1, title: "Raised cash", bodyText: "Trimmed VOO", type: .Rebalance, author: "Alice", positionsAsOf: "2025-09-02T09:30:00Z", totalValueChf: 2104500)
        XCTAssertNotNil(created)
        var list = manager.listThemeUpdates(themeId: 1)
        XCTAssertEqual(list.count, 1)
        let first = list[0]
        XCTAssertEqual(first.author, "Alice")

        let updated = manager.updateThemeUpdate(id: first.id, title: "Raise cash to 15%", bodyText: "Adjust further", type: .Rebalance, expectedUpdatedAt: first.updatedAt)
        XCTAssertNotNil(updated)
        let stale = manager.updateThemeUpdate(id: first.id, title: "Stale", bodyText: "Stale", type: .General, expectedUpdatedAt: first.updatedAt)
        XCTAssertNil(stale)

        let deleteOk = manager.deleteThemeUpdate(id: first.id)
        XCTAssertTrue(deleteOk)
        list = manager.listThemeUpdates(themeId: 1)
        XCTAssertTrue(list.isEmpty)
    }
}
