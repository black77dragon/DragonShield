import XCTest
import SQLite3
@testable import DragonShield

final class PortfolioValuationServiceTests: XCTestCase {
    private func setupDb(_ manager: DatabaseManager) -> (themeId: Int, sessionId: Int) {
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
            position_id INTEGER PRIMARY KEY AUTOINCREMENT,
            import_session_id INTEGER,
            instrument_id INTEGER,
            quantity REAL,
            current_price REAL
        );
        """
        sqlite3_exec(manager.db, sql, nil, nil, nil)
        manager.ensurePortfolioThemeAssetTable()
        _ = manager.createPortfolioTheme(name: "Growth", code: "GROW", statusId: 1)
        sqlite3_exec(manager.db, "INSERT INTO Instruments (instrument_name, sub_class_id, currency) VALUES ('Apple',1,'USD');", nil, nil, nil)
        sqlite3_exec(manager.db, "INSERT INTO PositionReports (import_session_id, instrument_id, quantity, current_price) VALUES (1,1,10,5);", nil, nil, nil)
        _ = manager.createThemeAsset(themeId: 1, instrumentId: 1, researchPct: 50.0, userPct: 60.0, notes: "Note A")
        return (themeId: 1, sessionId: 1)
    }

    func testValuationIncludesNotes() {
        let manager = DatabaseManager()
        let setup = setupDb(manager)
        let service = PortfolioValuationService(db: manager.db)
        let items = service.fetchThemeValuations(themeId: setup.themeId, importSessionId: setup.sessionId)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.notes, "Note A")
        sqlite3_close(manager.db)
    }
}
