import XCTest
import SwiftUI
import SQLite3
@testable import DragonShield

final class PortfolioThemesListPresentationTests: XCTestCase {
    func testListViewInitializes() {
        let manager = DatabaseManager()
        var mem: OpaquePointer?
        sqlite3_open(":memory:", &mem)
        manager.db = mem
        let sql = """
        CREATE TABLE PortfolioThemeStatus (id INTEGER PRIMARY KEY, code TEXT, name TEXT, color_hex TEXT, is_default INTEGER);
        INSERT INTO PortfolioThemeStatus VALUES (1,'ACTIVE','Active','#fff',1);
        CREATE TABLE PortfolioTheme (id INTEGER PRIMARY KEY, name TEXT, code TEXT, status_id INTEGER, created_at TEXT DEFAULT '', updated_at TEXT DEFAULT '', archived_at TEXT, soft_delete INTEGER DEFAULT 0);
        """
        sqlite3_exec(manager.db, sql, nil, nil, nil)
        let view = PortfolioThemesListView().environmentObject(manager)
        XCTAssertNotNil(view.body)
        sqlite3_close(mem)
    }
}
