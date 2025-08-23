import XCTest
import SwiftUI
import SQLite3
@testable import DragonShield

final class PortfolioThemeOverviewViewTests: XCTestCase {
    func testViewInitializes() {
        let manager = DatabaseManager()
        var mem: OpaquePointer?
        sqlite3_open(":memory:", &mem)
        manager.db = mem
        let sql = """
        CREATE TABLE PortfolioThemeStatus (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT,
            name TEXT,
            color_hex TEXT,
            is_default INTEGER
        );
        INSERT INTO PortfolioThemeStatus (code,name,color_hex,is_default) VALUES ('ACTIVE','Active','#FFFFFF',1);
        CREATE TABLE PortfolioTheme (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            code TEXT NOT NULL,
            status_id INTEGER NOT NULL
        );
        """
        sqlite3_exec(manager.db, sql, nil, nil, nil)
        _ = manager.createPortfolioTheme(name: "Growth", code: "GROWTH", description: nil, institutionId: nil, statusId: 1)
        let view = PortfolioThemeOverviewView(themeId: 1, selectedTab: .constant(.overview)).environmentObject(manager)
        XCTAssertNotNil(view.body)
        sqlite3_close(mem)
    }
}

