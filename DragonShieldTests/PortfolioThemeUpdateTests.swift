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
        manager.ensureUpdateTypeTable()
        sqlite3_exec(manager.db, "INSERT INTO UpdateType(code,name) VALUES ('General','General'),('Research','Research'),('Rebalance','Rebalance'),('Risk','Risk');", nil, nil, nil)
        manager.ensurePortfolioThemeUpdateTable()
    }

    override func tearDown() {
        sqlite3_close(memdb)
        memdb = nil
        manager = nil
        super.tearDown()
    }

    func testSearchTypeSoftDeleteAndRestore() {
        let types = manager.fetchUpdateTypes()
        let rebalance = types.first { $0.code == "Rebalance" }!
        let general = types.first { $0.code == "General" }!
        let first = manager.createThemeUpdate(themeId: 1, title: "Raised cash", bodyMarkdown: "Trimmed VOO", type: rebalance, pinned: true, author: "Alice", positionsAsOf: nil, totalValueChf: nil)
        XCTAssertNotNil(first)
        let second = manager.createThemeUpdate(themeId: 1, title: "Monthly review", bodyMarkdown: "General outlook", type: general, pinned: false, author: "Bob", positionsAsOf: nil, totalValueChf: nil)
        XCTAssertNotNil(second)

        var list = manager.listThemeUpdates(themeId: 1, view: .active, type: nil, searchQuery: nil, pinnedFirst: true)
        XCTAssertEqual(list.count, 2)

        list = manager.listThemeUpdates(themeId: 1, view: .active, type: general, searchQuery: nil, pinnedFirst: true)
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list.first?.title, "Monthly review")

        list = manager.listThemeUpdates(themeId: 1, view: .active, type: nil, searchQuery: "cash", pinnedFirst: true)
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list.first?.title, "Raised cash")

        XCTAssertTrue(manager.softDeleteThemeUpdate(id: first!.id, actor: "Alice"))
        list = manager.listThemeUpdates(themeId: 1, view: .active, type: nil, searchQuery: nil, pinnedFirst: true)
        XCTAssertEqual(list.count, 1)
        list = manager.listThemeUpdates(themeId: 1, view: .deleted, type: nil, searchQuery: nil, pinnedFirst: true)
        XCTAssertEqual(list.count, 1)

        XCTAssertTrue(manager.restoreThemeUpdate(id: first!.id, actor: "Alice"))
        list = manager.listThemeUpdates(themeId: 1, view: .active, type: nil, searchQuery: nil, pinnedFirst: true)
        XCTAssertEqual(list.count, 2)

        XCTAssertTrue(manager.softDeleteThemeUpdate(id: second!.id, actor: "Bob"))
        XCTAssertTrue(manager.deleteThemeUpdatePermanently(id: second!.id, actor: "Bob"))
        list = manager.listThemeUpdates(themeId: 1, view: .deleted, type: nil, searchQuery: nil, pinnedFirst: true)
        XCTAssertEqual(list.count, 0)
    }
}
