import XCTest
import SQLite3
@testable import DragonShield

final class PortfolioThemeTests: XCTestCase {
    func testCodeValidation() {
        XCTAssertTrue(PortfolioTheme.isValidCode("THEME_1"))
        XCTAssertFalse(PortfolioTheme.isValidCode("theme"))
        XCTAssertFalse(PortfolioTheme.isValidCode(""))
    }

    func testNameValidation() {
        XCTAssertTrue(PortfolioTheme.isValidName("Core Growth"))
        XCTAssertFalse(PortfolioTheme.isValidName(""))
    }

    func testCreateThemePersists() {
        let manager = DatabaseManager()
        var memdb: OpaquePointer?
        sqlite3_open(":memory:", &memdb)
        manager.db = memdb
        sqlite3_exec(manager.db, "CREATE TABLE PortfolioThemeStatus(id INTEGER PRIMARY KEY, code TEXT, name TEXT, is_default INTEGER);", nil, nil, nil)
        sqlite3_exec(manager.db, "INSERT INTO PortfolioThemeStatus(id, code, name, is_default) VALUES(1,'DRAFT','Draft',1);", nil, nil, nil)
        sqlite3_exec(manager.db, "CREATE TABLE PortfolioTheme(id INTEGER PRIMARY KEY, name TEXT, code TEXT, status_id INTEGER, created_at TEXT, updated_at TEXT, archived_at TEXT, soft_delete INTEGER);", nil, nil, nil)
        let theme = manager.createPortfolioTheme(name: "Growth", code: "GROWTH", statusId: 1)
        XCTAssertNotNil(theme)
        let fetched = manager.fetchPortfolioThemes()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Growth")
        sqlite3_close(memdb)
    }
}
