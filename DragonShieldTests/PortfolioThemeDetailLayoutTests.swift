import XCTest
import SwiftUI
import SQLite3
@testable import DragonShield

final class PortfolioThemeDetailLayoutTests: XCTestCase {
    func testViewInitializes() {
        let manager = DatabaseManager()
        var mem: OpaquePointer?
        sqlite3_open(":memory:", &mem)
        manager.db = mem
        let sql = """
        CREATE TABLE PortfolioThemeStatus (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL,
            name TEXT NOT NULL,
            color_hex TEXT NOT NULL,
            is_default INTEGER NOT NULL,
            created_at TEXT DEFAULT '',
            updated_at TEXT DEFAULT ''
        );
        INSERT INTO PortfolioThemeStatus (code,name,color_hex,is_default) VALUES ('ACTIVE','Active','#FFFFFF',1);
        CREATE TABLE PortfolioTheme (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            code TEXT NOT NULL,
            status_id INTEGER NOT NULL,
            created_at TEXT DEFAULT '',
            updated_at TEXT DEFAULT '',
            archived_at TEXT,
            soft_delete INTEGER DEFAULT 0
        );
        """
        sqlite3_exec(manager.db, sql, nil, nil, nil)
        _ = manager.createPortfolioTheme(name: "Growth", code: "GROWTH", description: nil, institutionId: nil, statusId: 1)
        let view = PortfolioThemeDetailView(themeId: 1, origin: "test").environmentObject(manager)
        XCTAssertNotNil(view.body)
        sqlite3_close(mem)
    }
}

