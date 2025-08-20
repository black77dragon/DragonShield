import XCTest
import SQLite3
@testable import DragonShield

final class PortfolioValuationServiceTests: XCTestCase {
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
        CREATE TABLE PositionReports (
            report_id INTEGER PRIMARY KEY AUTOINCREMENT,
            instrument_id INTEGER NOT NULL,
            import_session_id INTEGER NOT NULL,
            quantity REAL NOT NULL,
            current_price REAL NOT NULL
        );
        """
        sqlite3_exec(manager.db, sql, nil, nil, nil)
        manager.ensurePortfolioThemeAssetTable()
        _ = manager.createPortfolioTheme(name: "Growth", code: "GROWTH", statusId: 1)
        sqlite3_exec(manager.db, "INSERT INTO Instruments (instrument_name, sub_class_id, currency) VALUES ('Apple',1,'USD');", nil, nil, nil)
    }

    func testValuationIncludesNotes() {
        let manager = DatabaseManager()
        setupDb(manager)
        guard let theme = manager.fetchPortfolioThemes().first else { XCTFail(); return }
        _ = manager.createThemeAsset(themeId: theme.id, instrumentId: 1, researchPct: 50.0, userPct: 50.0, notes: "Important")
        sqlite3_exec(manager.db, "INSERT INTO PositionReports (instrument_id, import_session_id, quantity, current_price) VALUES (1,1,2,100);", nil, nil, nil)
        let service = PortfolioValuationService(db: manager.db)
        let valuations = service.fetchValuations(importSessionId: 1, themeId: theme.id)
        XCTAssertEqual(valuations.count, 1)
        let valuation = valuations[0]
        XCTAssertEqual(valuation.notes, "Important")
        XCTAssertEqual(valuation.value, 200.0, accuracy: 0.001)
        sqlite3_close(manager.db)
    }
}

