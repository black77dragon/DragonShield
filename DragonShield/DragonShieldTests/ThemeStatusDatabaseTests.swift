import XCTest
import SQLite3
@testable import DragonShield

final class ThemeStatusDatabaseTests: XCTestCase {
    var manager: DatabaseManager!
    var memdb: OpaquePointer?

    override func setUp() {
        super.setUp()
        manager = DatabaseManager()
        sqlite3_open(":memory:", &memdb)
        manager.db = memdb
        sqlite3_exec(manager.db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
        sqlite3_exec(manager.db, """
            CREATE TABLE PortfolioThemeStatus(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                code TEXT UNIQUE CHECK(code GLOB '[A-Z][A-Z0-9_]*'),
                name TEXT UNIQUE,
                color_hex TEXT,
                is_default INTEGER NOT NULL DEFAULT 0
            );
        """, nil, nil, nil)
        sqlite3_exec(manager.db, "CREATE UNIQUE INDEX idx_portfolio_theme_status_default ON PortfolioThemeStatus(is_default) WHERE is_default = 1;", nil, nil, nil)
        sqlite3_exec(manager.db, """
            CREATE TABLE PortfolioTheme(
                id INTEGER PRIMARY KEY,
                status_id INTEGER NOT NULL REFERENCES PortfolioThemeStatus(id)
            );
        """, nil, nil, nil)
    }

    override func tearDown() {
        sqlite3_close(memdb)
        memdb = nil
        manager = nil
        super.tearDown()
    }

    func testInsertInvalidCodeReturnsError() {
        let result = manager.insertPortfolioThemeStatus(code: "bad", name: "Test", colorHex: "#FFFFFF", isDefault: false)
        switch result {
        case .failure(let err):
            XCTAssertEqual(err, .invalidCode)
        default:
            XCTFail("Expected invalid code error")
        }
    }

    func testInsertDuplicateNameReturnsError() {
        _ = manager.insertPortfolioThemeStatus(code: "AA", name: "One", colorHex: "#FFFFFF", isDefault: false)
        let result = manager.insertPortfolioThemeStatus(code: "BB", name: "One", colorHex: "#000000", isDefault: false)
        switch result {
        case .failure(let err):
            XCTAssertEqual(err, .duplicateName)
        default:
            XCTFail("Expected duplicate name error")
        }
    }

    func testDeleteInUseReturnsError() {
        _ = manager.insertPortfolioThemeStatus(code: "AA", name: "One", colorHex: "#FFFFFF", isDefault: false)
        let statusId = Int(sqlite3_last_insert_rowid(manager.db))
        sqlite3_exec(manager.db, "INSERT INTO PortfolioTheme(id,status_id) VALUES (1,\(statusId));", nil, nil, nil)
        let result = manager.deletePortfolioThemeStatus(id: statusId)
        switch result {
        case .failure(let err):
            if case .inUse(let count) = err {
                XCTAssertEqual(count, 1)
            } else {
                XCTFail("Expected inUse error")
            }
        default:
            XCTFail("Expected failure")
        }
    }

    func testDeleteDefaultReturnsError() {
        _ = manager.insertPortfolioThemeStatus(code: "AA", name: "One", colorHex: "#FFFFFF", isDefault: true)
        let statusId = Int(sqlite3_last_insert_rowid(manager.db))
        let result = manager.deletePortfolioThemeStatus(id: statusId)
        switch result {
        case .failure(let err):
            XCTAssertEqual(err, .isDefault)
        default:
            XCTFail("Expected default error")
        }
    }

    func testDeleteUnusedSucceeds() {
        _ = manager.insertPortfolioThemeStatus(code: "AA", name: "One", colorHex: "#FFFFFF", isDefault: false)
        let statusId = Int(sqlite3_last_insert_rowid(manager.db))
        let result = manager.deletePortfolioThemeStatus(id: statusId)
        if case .failure(let err) = result {
            XCTFail("Expected success got \(err)")
        }
    }
}
