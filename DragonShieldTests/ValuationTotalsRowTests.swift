import XCTest
import SQLite3
@testable import DragonShield

final class ValuationTotalsRowTests: XCTestCase {
    private func setupDb(withPositions: Bool) -> DatabaseManager {
        let manager = DatabaseManager()
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        manager.db = db
        manager.baseCurrency = "CHF"
        let sql = """
        CREATE TABLE PortfolioThemeStatus (id INTEGER PRIMARY KEY, code TEXT, name TEXT, color_hex TEXT, is_default INTEGER);
        INSERT INTO PortfolioThemeStatus VALUES (1,'ACTIVE','Active','#fff',1);
        CREATE TABLE PortfolioTheme (id INTEGER PRIMARY KEY, name TEXT, code TEXT, status_id INTEGER, archived_at TEXT, soft_delete INTEGER DEFAULT 0);
        INSERT INTO PortfolioTheme VALUES (1,'Core','CORE',1,NULL,0);
        CREATE TABLE PortfolioThemeAsset (theme_id INTEGER, instrument_id INTEGER, research_target_pct REAL, user_target_pct REAL, notes TEXT, PRIMARY KEY(theme_id,instrument_id));
        INSERT INTO PortfolioThemeAsset VALUES (1,1,100,100,NULL);
        CREATE TABLE Instruments (instrument_id INTEGER PRIMARY KEY, instrument_name TEXT, currency TEXT);
        INSERT INTO Instruments VALUES (1,'AAPL','CHF');
        CREATE TABLE PositionReports (position_id INTEGER PRIMARY KEY AUTOINCREMENT, import_session_id INTEGER, instrument_id INTEGER, quantity REAL, current_price REAL, report_date TEXT);
        """
        sqlite3_exec(db, sql, nil, nil, nil)
        if withPositions {
            let insert = "INSERT INTO PositionReports (import_session_id,instrument_id,quantity,current_price,report_date) VALUES (1,1,10,50,'2025-08-20T14:05:00Z');"
            sqlite3_exec(db, insert, nil, nil, nil)
        }
        return manager
    }

    func testTotalsPctIs100WhenRowsIncluded() {
        let manager = setupDb(withPositions: true)
        let fxService = FXConversionService(dbManager: manager)
        let service = PortfolioValuationService(dbManager: manager, fxService: fxService)
        let snap = service.snapshot(themeId: 1)
        let totalPct = snap.rows.contains { $0.status == "OK" } ? 100.0 : 0.0
        XCTAssertEqual(totalPct, 100.0)
        sqlite3_close(manager.db)
    }

    func testTotalsPctIsZeroWhenNoIncludedRows() {
        let manager = setupDb(withPositions: false)
        let fxService = FXConversionService(dbManager: manager)
        let service = PortfolioValuationService(dbManager: manager, fxService: fxService)
        let snap = service.snapshot(themeId: 1)
        let totalPct = snap.rows.contains { $0.status == "OK" } ? 100.0 : 0.0
        XCTAssertEqual(totalPct, 0.0)
        sqlite3_close(manager.db)
    }
}
