import XCTest
import SQLite3
@testable import DragonShield

final class PortfolioThemeInstrumentCountTests: XCTestCase {
    private func setup(_ manager: DatabaseManager) {
        var mem: OpaquePointer?
        sqlite3_open(":memory:", &mem)
        manager.db = mem
        let sql = """
        CREATE TABLE PortfolioThemeStatus (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL,
            name TEXT NOT NULL,
            color_hex TEXT NOT NULL,
            is_default INTEGER NOT NULL
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
        """
        sqlite3_exec(manager.db, sql, nil, nil, nil)
        manager.ensurePortfolioThemeAssetTable()
    }

    func testFetchThemesReturnsInstrumentCount() {
        let manager = DatabaseManager()
        setup(manager)
        _ = manager.createPortfolioTheme(name: "Growth", code: "GROWTH", statusId: 1)
        sqlite3_exec(manager.db, "INSERT INTO Instruments (instrument_name, sub_class_id, currency) VALUES ('Apple',1,'USD');", nil, nil, nil)
        sqlite3_exec(manager.db, "INSERT INTO Instruments (instrument_name, sub_class_id, currency) VALUES ('Tesla',1,'USD');", nil, nil, nil)
        guard let theme = manager.fetchPortfolioThemes().first else { XCTFail(); return }
        _ = manager.createThemeAsset(themeId: theme.id, instrumentId: 1, researchPct: 50.0)
        _ = manager.createThemeAsset(themeId: theme.id, instrumentId: 2, researchPct: 50.0)
        let fetched = manager.fetchPortfolioThemes()
        XCTAssertEqual(fetched.first?.instrumentCount, 2)
        sqlite3_close(manager.db)
    }

    func testGetThemeReturnsInstrumentCount() {
        let manager = DatabaseManager()
        setup(manager)
        guard let theme = manager.createPortfolioTheme(name: "Income", code: "INCOME", statusId: 1) else { XCTFail(); return }
        sqlite3_exec(manager.db, "INSERT INTO Instruments (instrument_name, sub_class_id, currency) VALUES ('BondA',1,'USD');", nil, nil, nil)
        sqlite3_exec(manager.db, "INSERT INTO Instruments (instrument_name, sub_class_id, currency) VALUES ('BondB',1,'USD');", nil, nil, nil)
        _ = manager.createThemeAsset(themeId: theme.id, instrumentId: 1, researchPct: 50.0)
        _ = manager.createThemeAsset(themeId: theme.id, instrumentId: 2, researchPct: 50.0)
        let fetched = manager.getPortfolioTheme(id: theme.id)
        XCTAssertEqual(fetched?.instrumentCount, 2)
        sqlite3_close(manager.db)
    }
}
