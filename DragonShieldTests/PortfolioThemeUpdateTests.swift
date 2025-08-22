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

    func testCreateUpdateDeleteFlowAndPinning() {
        let created = manager.createThemeUpdate(themeId: 1, title: "Raised cash", bodyMarkdown: "Trimmed VOO", type: .Rebalance, pinned: true, author: "Alice", positionsAsOf: "2025-09-02T09:30:00Z", totalValueChf: 2104500)
        XCTAssertNotNil(created)
        var list = manager.listThemeUpdates(themeId: 1)
        XCTAssertEqual(list.count, 1)
        let first = list[0]
        XCTAssertTrue(first.pinned)

        let second = manager.createThemeUpdate(themeId: 1, title: "Unpinned", bodyMarkdown: "body", type: .General, pinned: false, author: "Bob", positionsAsOf: nil, totalValueChf: nil)
        XCTAssertNotNil(second)

        list = manager.listThemeUpdates(themeId: 1)
        XCTAssertEqual(list.first?.title, "Raised cash")

        list = manager.listThemeUpdates(themeId: 1, pinnedFirst: false)
        XCTAssertEqual(list.first?.title, "Unpinned")

        let updated = manager.updateThemeUpdate(id: first.id, title: "Raise cash to 15%", bodyMarkdown: "Adjust further", type: .Rebalance, pinned: false, actor: "Alice", expectedUpdatedAt: first.updatedAt)
        XCTAssertNotNil(updated)
        let stale = manager.updateThemeUpdate(id: first.id, title: "Stale", bodyMarkdown: nil, type: nil, pinned: nil, actor: "Alice", expectedUpdatedAt: first.updatedAt)
        XCTAssertNil(stale)

        let deleteOk = manager.deleteThemeUpdate(id: first.id, themeId: 1, actor: "Alice")
        XCTAssertTrue(deleteOk)
        list = manager.listThemeUpdates(themeId: 1)
        XCTAssertEqual(list.count, 1)
    }

    func testUpdateValidationFails() {
        guard let item = manager.createThemeUpdate(themeId: 1, title: "Valid", bodyMarkdown: "body", type: .General, pinned: false, author: "Bob", positionsAsOf: nil, totalValueChf: nil) else {
            XCTFail("creation failed")
            return
        }
        let result = manager.updateThemeUpdate(id: item.id, title: "", bodyMarkdown: nil, type: nil, pinned: nil, actor: "Bob", expectedUpdatedAt: item.updatedAt)
        XCTAssertNil(result)
    }
}
