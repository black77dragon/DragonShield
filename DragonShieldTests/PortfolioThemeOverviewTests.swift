import XCTest
import SwiftUI
import SQLite3
@testable import DragonShield

final class PortfolioThemeOverviewTests: XCTestCase {
    func testViewInitializes() {
        let manager = DatabaseManager()
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        manager.db = db
        sqlite3_exec(manager.db, "CREATE TABLE PortfolioTheme(id INTEGER PRIMARY KEY);", nil, nil, nil)
        sqlite3_exec(manager.db, "CREATE TABLE PortfolioThemeUpdate(id INTEGER PRIMARY KEY, theme_id INTEGER, title TEXT, body_markdown TEXT, type TEXT, author TEXT, pinned INTEGER, created_at TEXT, updated_at TEXT, soft_delete INTEGER, deleted_at TEXT, deleted_by TEXT);", nil, nil, nil)
        sqlite3_exec(manager.db, "INSERT INTO PortfolioTheme(id) VALUES (1);", nil, nil, nil)
        let view = PortfolioThemeOverviewView(themeId: 1, themeName: "Test", totalValueChf: 0, instrumentCount: 0).environmentObject(manager)
        XCTAssertNotNil(view.body)
        sqlite3_close(db)
    }
}
