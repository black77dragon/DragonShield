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
        sqlite3_exec(manager.db, "CREATE TABLE PortfolioTheme(id INTEGER PRIMARY KEY, name TEXT, archived_at TEXT);", nil, nil, nil)
        sqlite3_exec(manager.db, "INSERT INTO PortfolioTheme(id, name, archived_at) VALUES (1,'Alpha',NULL);", nil, nil, nil)
        sqlite3_exec(manager.db, "INSERT INTO PortfolioTheme(id, name, archived_at) VALUES (2,'Beta','2023-01-01T00:00:00Z');", nil, nil, nil)
        sqlite3_exec(manager.db, "CREATE TABLE Instruments(instrument_id INTEGER PRIMARY KEY, instrument_name TEXT);", nil, nil, nil)
        sqlite3_exec(manager.db, "INSERT INTO Instruments(instrument_id, instrument_name) VALUES (42,'Inst');", nil, nil, nil)
        sqlite3_exec(manager.db, "CREATE TABLE PortfolioThemeAsset(theme_id INTEGER, instrument_id INTEGER, research_target_pct REAL, user_target_pct REAL, notes TEXT, created_at TEXT, updated_at TEXT, PRIMARY KEY(theme_id, instrument_id));", nil, nil, nil)
        manager.ensurePortfolioThemeAssetUpdateTable()
        manager.ensurePortfolioThemeUpdateTable()
    }

    override func tearDown() {
        sqlite3_close(memdb)
        memdb = nil
        manager = nil
        super.tearDown()
    }

    func testCreateEditDeleteFlow() {
        let first = manager.createInstrumentUpdate(themeId: 1, instrumentId: 42, title: "Init", bodyMarkdown: "Start", type: .General, pinned: false, author: "Alice", breadcrumb: nil)
        XCTAssertNotNil(first)
        let second = manager.createInstrumentUpdate(themeId: 1, instrumentId: 42, title: "Second", bodyMarkdown: "More", type: .Research, pinned: false, author: "Bob", breadcrumb: nil)
        XCTAssertNotNil(second)
        var list = manager.listInstrumentUpdates(themeId: 1, instrumentId: 42)
        XCTAssertEqual(list.count, 2)
        XCTAssertEqual(list.first?.id, second!.id)
        // Pin first update and ensure it bubbles to top
        let pinned = manager.updateInstrumentUpdate(id: first!.id, title: nil, bodyMarkdown: nil, type: nil, pinned: true, actor: "Alice", expectedUpdatedAt: first!.updatedAt)
        XCTAssertTrue(pinned?.pinned == true)
        list = manager.listInstrumentUpdates(themeId: 1, instrumentId: 42)
        XCTAssertEqual(list.first?.id, first!.id)
        // Unpin and update title
        let updated = manager.updateInstrumentUpdate(id: first!.id, title: "Changed", bodyMarkdown: nil, type: .Risk, pinned: false, actor: "Alice", expectedUpdatedAt: pinned!.updatedAt)
        XCTAssertEqual(updated?.title, "Changed")
        XCTAssertEqual(updated?.type, .Risk)
        XCTAssertTrue(updated?.pinned == false)
        let conflict = manager.updateInstrumentUpdate(id: first!.id, title: "Bad", bodyMarkdown: nil, type: nil, pinned: nil, actor: "Bob", expectedUpdatedAt: "bogus")
        XCTAssertNil(conflict)
        XCTAssertTrue(manager.deleteInstrumentUpdate(id: first!.id, actor: "Alice"))
        XCTAssertEqual(manager.countInstrumentUpdates(themeId: 1, instrumentId: 42), 1)
        XCTAssertTrue(manager.deleteInstrumentUpdate(id: second!.id, actor: "Bob"))
        XCTAssertEqual(manager.countInstrumentUpdates(themeId: 1, instrumentId: 42), 0)
        list = manager.listInstrumentUpdates(themeId: 1, instrumentId: 42)
        XCTAssertEqual(list.count, 0)
    }

    func testListThemesForInstrumentWithCountsAndMentions() {
        sqlite3_exec(manager.db, "INSERT INTO PortfolioThemeAsset(theme_id, instrument_id, research_target_pct, user_target_pct, notes, created_at, updated_at) VALUES (1,42,0,0,NULL,datetime('now'),datetime('now'));", nil, nil, nil)
        sqlite3_exec(manager.db, "INSERT INTO PortfolioThemeAsset(theme_id, instrument_id, research_target_pct, user_target_pct, notes, created_at, updated_at) VALUES (2,42,0,0,NULL,datetime('now'),datetime('now'));", nil, nil, nil)
        _ = manager.createInstrumentUpdate(themeId: 1, instrumentId: 42, title: "One", bodyMarkdown: "Body", type: .General, pinned: false, author: "Ann", breadcrumb: nil)
        _ = manager.createInstrumentUpdate(themeId: 1, instrumentId: 42, title: "Two", bodyMarkdown: "Body", type: .General, pinned: false, author: "Ben", breadcrumb: nil)
        sqlite3_exec(manager.db, "INSERT INTO PortfolioThemeUpdate(theme_id, title, body_text, body_markdown, type, author, pinned, positions_asof, total_value_chf, soft_delete) VALUES (1,'Note','ALAB is rising','ALAB is rising','General','Amy',0,NULL,NULL,0);", nil, nil, nil)
        sqlite3_exec(manager.db, "INSERT INTO PortfolioThemeUpdate(theme_id, title, body_text, body_markdown, type, author, pinned, positions_asof, total_value_chf, soft_delete) VALUES (1,'Other','Astera Labs Inc outlook','Astera Labs Inc outlook','General','Amy',0,NULL,NULL,0);", nil, nil, nil)
        sqlite3_exec(manager.db, "INSERT INTO PortfolioThemeUpdate(theme_id, title, body_text, body_markdown, type, author, pinned, positions_asof, total_value_chf, soft_delete) VALUES (1,'Irrelevant','No match here','No match here','General','Amy',0,NULL,NULL,0);", nil, nil, nil)
        sqlite3_exec(manager.db, "INSERT INTO PortfolioThemeUpdate(theme_id, title, body_text, body_markdown, type, author, pinned, positions_asof, total_value_chf, soft_delete) VALUES (2,'None','Nothing about it','Nothing about it','General','Amy',0,NULL,NULL,0);", nil, nil, nil)
        let list = manager.listThemesForInstrumentWithUpdateCounts(instrumentId: 42, instrumentCode: "ALAB", instrumentName: "Astera Labs Inc")
        XCTAssertEqual(list.count, 2)
        let first = list.first { $0.themeId == 1 }
        XCTAssertEqual(first?.updatesCount, 2)
        XCTAssertEqual(first?.mentionsCount, 2)
        let second = list.first { $0.themeId == 2 }
        XCTAssertEqual(second?.updatesCount, 0)
        XCTAssertEqual(second?.mentionsCount, 0)
        XCTAssertEqual(second?.isArchived, true)
    }
}



    func testListInstrumentUpdatesAcrossThemes() {
        sqlite3_exec(manager.db, "INSERT INTO PortfolioThemeAsset(theme_id, instrument_id, research_target_pct, user_target_pct, notes, created_at, updated_at) VALUES (1,42,0,0,NULL,datetime('now'),datetime('now'));", nil, nil, nil)
        sqlite3_exec(manager.db, "INSERT INTO PortfolioThemeAsset(theme_id, instrument_id, research_target_pct, user_target_pct, notes, created_at, updated_at) VALUES (2,42,0,0,NULL,datetime('now'),datetime('now'));", nil, nil, nil)
        _ = manager.createInstrumentUpdate(themeId: 1, instrumentId: 42, title: "One", bodyMarkdown: "Body", type: .General, pinned: false, author: "Ann", breadcrumb: nil)
        _ = manager.createInstrumentUpdate(themeId: 2, instrumentId: 42, title: "Two", bodyMarkdown: "Body", type: .General, pinned: false, author: "Ben", breadcrumb: nil)
        let all = manager.listInstrumentUpdatesForInstrument(instrumentId: 42, themeId: nil)
        XCTAssertEqual(all.count, 2)
    }

    func testListThemeMentions() {
        sqlite3_exec(manager.db, "INSERT INTO PortfolioThemeAsset(theme_id, instrument_id, research_target_pct, user_target_pct, notes, created_at, updated_at) VALUES (1,42,0,0,NULL,datetime('now'),datetime('now'));", nil, nil, nil)
        sqlite3_exec(manager.db, "INSERT INTO PortfolioThemeUpdate(theme_id, title, body_text, body_markdown, type, author, pinned, positions_asof, total_value_chf, soft_delete) VALUES (1,'Note','ALAB is rising','ALAB is rising','General','Amy',0,NULL,NULL,0);", nil, nil, nil)
        sqlite3_exec(manager.db, "INSERT INTO PortfolioThemeUpdate(theme_id, title, body_text, body_markdown, type, author, pinned, positions_asof, total_value_chf, soft_delete) VALUES (1,'Other','Astera Labs Inc outlook','Astera Labs Inc outlook','General','Amy',0,NULL,NULL,0);", nil, nil, nil)
        let list = manager.listThemeMentions(themeId: 1, instrumentCode: "ALAB", instrumentName: "Astera Labs Inc")
        XCTAssertEqual(list.count, 2)
    }
