import XCTest
import SQLite3
@testable import DragonShield

final class InstrumentThemeLinkTests: XCTestCase {
    var manager: DatabaseManager!
    var db: OpaquePointer?

    override func setUp() {
        super.setUp()
        manager = DatabaseManager()
        sqlite3_open(":memory:", &db)
        manager.db = db
        sqlite3_exec(db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
        sqlite3_exec(db, "CREATE TABLE PortfolioTheme(id INTEGER PRIMARY KEY, name TEXT NOT NULL, archived_at TEXT);", nil, nil, nil)
        sqlite3_exec(db, "CREATE TABLE Instruments(instrument_id INTEGER PRIMARY KEY, name TEXT);", nil, nil, nil)
        sqlite3_exec(db, "CREATE TABLE PortfolioThemeAsset(theme_id INTEGER NOT NULL, instrument_id INTEGER NOT NULL, PRIMARY KEY(theme_id, instrument_id));", nil, nil, nil)
        manager.ensurePortfolioThemeAssetUpdateTable()
        sqlite3_exec(db, "INSERT INTO PortfolioTheme(id, name, archived_at) VALUES (1,'Core',NULL),(2,'Archived','2024-01-01');", nil, nil, nil)
        sqlite3_exec(db, "INSERT INTO Instruments(instrument_id, name) VALUES (42,'ALAB');", nil, nil, nil)
        sqlite3_exec(db, "INSERT INTO PortfolioThemeAsset(theme_id, instrument_id) VALUES (1,42),(2,42);", nil, nil, nil)
        _ = manager.createInstrumentUpdate(themeId: 1, instrumentId: 42, title: "A", bodyMarkdown: "B", type: .General, pinned: false, author: "u", breadcrumb: nil)
        _ = manager.createInstrumentUpdate(themeId: 1, instrumentId: 42, title: "C", bodyMarkdown: "D", type: .General, pinned: false, author: "u", breadcrumb: nil)
    }

    override func tearDown() {
        sqlite3_close(db)
        db = nil
        manager = nil
        super.tearDown()
    }

    func testListThemesForInstrumentWithUpdateCounts() {
        let rows = manager.listThemesForInstrumentWithUpdateCounts(instrumentId: 42)
        XCTAssertEqual(rows.count, 2)
        let sorted = rows.sorted { $0.themeId < $1.themeId }
        XCTAssertEqual(sorted[0].updatesCount, 2)
        XCTAssertFalse(sorted[0].isArchived)
        XCTAssertEqual(sorted[1].updatesCount, 0)
        XCTAssertTrue(sorted[1].isArchived)
    }
}
