import XCTest
import SQLite3
@testable import DragonShield

final class PortfolioThemeAssetCountTests: XCTestCase {
    private func setupDb(_ manager: DatabaseManager) {
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
        CREATE TABLE Instruments (
            instrument_id INTEGER PRIMARY KEY AUTOINCREMENT,
            instrument_name TEXT NOT NULL,
            sub_class_id INTEGER NOT NULL,
            currency TEXT NOT NULL
        );
        INSERT INTO Instruments (instrument_name, sub_class_id, currency) VALUES ('A',1,'CHF');
        INSERT INTO Instruments (instrument_name, sub_class_id, currency) VALUES ('B',1,'CHF');
        """
        sqlite3_exec(manager.db, sql, nil, nil, nil)
        manager.ensurePortfolioThemeAssetTable()
        _ = manager.createPortfolioTheme(name: "Growth", code: "GROWTH", statusId: 1)
    }

    func testCountThemeAssets() {
        let manager = DatabaseManager()
        setupDb(manager)
        guard let theme = manager.fetchPortfolioThemes().first else { XCTFail(); return }
        _ = manager.createThemeAsset(themeId: theme.id, instrumentId: 1, researchPct: 10.0)
        _ = manager.createThemeAsset(themeId: theme.id, instrumentId: 2, researchPct: 15.0)
        let count = manager.countThemeAssets(themeId: theme.id)
        XCTAssertEqual(count, 2)
        sqlite3_close(manager.db)
    }
}
