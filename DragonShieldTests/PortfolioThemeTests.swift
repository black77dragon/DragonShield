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
        XCTAssertFalse(PortfolioTheme.isValidName("   "))
    }

    func testCreateThemePersists() {
        let manager = DatabaseManager()
        var memdb: OpaquePointer?
        sqlite3_open(":memory:", &memdb)
        manager.db = memdb
        let statusSQL = """
        CREATE TABLE IF NOT EXISTS PortfolioThemeStatus (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL UNIQUE CHECK (code GLOB '[A-Z][A-Z0-9_]*'),
            name TEXT NOT NULL UNIQUE,
            color_hex TEXT NOT NULL CHECK (color_hex GLOB '#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]'),
            is_default BOOLEAN NOT NULL DEFAULT 0,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
        CREATE UNIQUE INDEX IF NOT EXISTS idx_portfolio_theme_status_default ON PortfolioThemeStatus(is_default) WHERE is_default = 1;
        INSERT INTO PortfolioThemeStatus (code, name, color_hex, is_default) VALUES
            ('DRAFT','Draft','#9AA0A6',1),
            ('ACTIVE','Active','#34A853',0),
            ('\(PortfolioThemeStatus.archivedCode)','Archived','#B0BEC5',0);
        """
        sqlite3_exec(manager.db, statusSQL, nil, nil, nil)
        manager.ensurePortfolioThemeTable()
        let theme = manager.createPortfolioTheme(name: "Growth", code: "GROWTH", statusId: 1)
        XCTAssertNotNil(theme)
        let fetched = manager.fetchPortfolioThemes()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Growth")
        sqlite3_close(memdb)
    }
}
