import XCTest
import SQLite3
@testable import DragonShield

final class PortfolioThemeAssetUpdateTests: XCTestCase {
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
        sqlite3_exec(manager.db, "CREATE TABLE Instruments(instrument_id INTEGER PRIMARY KEY);", nil, nil, nil)
        sqlite3_exec(manager.db, "INSERT INTO Instruments(instrument_id) VALUES (42);", nil, nil, nil)
        manager.ensurePortfolioThemeAssetUpdateTable()
    }

    override func tearDown() {
        sqlite3_close(memdb)
        memdb = nil
        manager = nil
        super.tearDown()
    }

    func testCreateEditDeleteFlow() {
        let first = manager.createInstrumentUpdate(themeId: 1, instrumentId: 42, title: "Init", bodyText: "Start", type: .General, author: "Alice", breadcrumb: nil)
        XCTAssertNotNil(first)
        let second = manager.createInstrumentUpdate(themeId: 1, instrumentId: 42, title: "Second", bodyText: "More", type: .Research, author: "Bob", breadcrumb: nil)
        XCTAssertNotNil(second)
        var list = manager.listInstrumentUpdates(themeId: 1, instrumentId: 42)
        XCTAssertEqual(list.count, 2)
        XCTAssertEqual(list.first?.id, second!.id)
        let updated = manager.updateInstrumentUpdate(id: first!.id, title: "Changed", bodyText: nil, type: .Risk, actor: "Alice", expectedUpdatedAt: first!.updatedAt)
        XCTAssertEqual(updated?.title, "Changed")
        XCTAssertEqual(updated?.type, .Risk)
        let conflict = manager.updateInstrumentUpdate(id: first!.id, title: "Bad", bodyText: nil, type: nil, actor: "Bob", expectedUpdatedAt: "bogus")
        XCTAssertNil(conflict)
        XCTAssertTrue(manager.deleteInstrumentUpdate(id: first!.id, actor: "Alice"))
        XCTAssertEqual(manager.countInstrumentUpdates(themeId: 1, instrumentId: 42), 1)
        XCTAssertTrue(manager.deleteInstrumentUpdate(id: second!.id, actor: "Bob"))
        XCTAssertEqual(manager.countInstrumentUpdates(themeId: 1, instrumentId: 42), 0)
        list = manager.listInstrumentUpdates(themeId: 1, instrumentId: 42)
        XCTAssertEqual(list.count, 0)
    }
}

