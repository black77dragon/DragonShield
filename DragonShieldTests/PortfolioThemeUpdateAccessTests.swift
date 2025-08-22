import XCTest
import SQLite3
@testable import DragonShield

final class PortfolioThemeUpdateAccessTests: XCTestCase {
    var manager: DatabaseManager!
    var memdb: OpaquePointer?

    override func setUp() {
        super.setUp()
        manager = DatabaseManager()
        sqlite3_open(":memory:", &memdb)
        manager.db = memdb
        sqlite3_exec(manager.db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
        let sql = """
        CREATE TABLE PortfolioThemeStatus(id INTEGER PRIMARY KEY, code TEXT, name TEXT, color_hex TEXT, is_default INTEGER);
        INSERT INTO PortfolioThemeStatus VALUES (1,'ACTIVE','Active','#fff',1);
        CREATE TABLE PortfolioTheme(id INTEGER PRIMARY KEY, name TEXT, code TEXT, status_id INTEGER, archived_at TEXT, soft_delete INTEGER DEFAULT 0);
        INSERT INTO PortfolioTheme(id,name,code,status_id,archived_at,soft_delete) VALUES (1,'Core','CORE',1,NULL,0);
        """
        sqlite3_exec(manager.db, sql, nil, nil, nil)
    }

    override func tearDown() {
        sqlite3_close(memdb)
        memdb = nil
        manager = nil
        super.tearDown()
    }

    func testInvokeNewUpdate() {
        var view = PortfolioThemesListView()
        view.themes = manager.fetchPortfolioThemes()
        view.selectedThemeId = 1
        view.invokeNewUpdate(source: "shortcut")
        XCTAssertNotNil(view.themeForUpdate)
    }

    func testInvokeWithoutSelection() {
        var view = PortfolioThemesListView()
        view.themes = manager.fetchPortfolioThemes()
        view.invokeNewUpdate(source: "shortcut")
        XCTAssertNil(view.themeForUpdate)
    }
}
