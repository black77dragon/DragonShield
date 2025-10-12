import XCTest
import SQLite3
@testable import DragonShield

final class PortfolioThemeNavigationTests: XCTestCase {
    func testSoftDeletedThemeNotFetchable() {
        let manager = DatabaseManager()
        var mem: OpaquePointer?
        sqlite3_open(":memory:", &mem)
        manager.db = mem
        let sql = """
        CREATE TABLE PortfolioThemeStatus (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            color_hex TEXT NOT NULL,
            is_default INTEGER NOT NULL,
            created_at TEXT DEFAULT '',
            updated_at TEXT DEFAULT ''
        );
        INSERT INTO PortfolioThemeStatus (code,name,color_hex,is_default) VALUES
            ('ACTIVE','Active','#FFFFFF',1),
            ('ARCH','Archived','#CCCCCC',0);
        """
        sqlite3_exec(manager.db, sql, nil, nil, nil)
        manager.ensurePortfolioThemeTable()
        guard let theme = manager.createPortfolioTheme(name: "Growth", code: "GROWTH", description: nil, institutionId: nil, statusId: 1) else { XCTFail(); return }
        XCTAssertTrue(manager.archivePortfolioTheme(id: theme.id))
        XCTAssertTrue(manager.softDeletePortfolioTheme(id: theme.id))
        XCTAssertNil(manager.getPortfolioTheme(id: theme.id))
        sqlite3_close(mem)
    }
}
