import XCTest
import SQLite3
@testable import DragonShield

final class DeviationTests: XCTestCase {
    func testDeviationState() {
        XCTAssertEqual(Deviation.state(for: 0.5, tolerance: 2.0), .within)
        XCTAssertEqual(Deviation.state(for: 3.0, tolerance: 2.0), .overweight)
        XCTAssertEqual(Deviation.state(for: -3.0, tolerance: 2.0), .underweight)
    }

    func testOutOfTolerance() {
        XCTAssertTrue(Deviation.isOutOfTolerance(delta: 3.0, tolerance: 2.0))
        XCTAssertFalse(Deviation.isOutOfTolerance(delta: 1.0, tolerance: 2.0))
        XCTAssertFalse(Deviation.isOutOfTolerance(delta: nil, tolerance: 2.0))
    }

    func testSnapshotDeltaCalculations() {
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
        INSERT INTO PortfolioThemeAsset VALUES (1,1,30,35,NULL);
        INSERT INTO PortfolioThemeAsset VALUES (1,2,70,65,NULL);
        CREATE TABLE Instruments (instrument_id INTEGER PRIMARY KEY, instrument_name TEXT, currency TEXT);
        INSERT INTO Instruments VALUES (1,'A','CHF');
        INSERT INTO Instruments VALUES (2,'B','CHF');
        CREATE TABLE PositionReports (position_id INTEGER PRIMARY KEY AUTOINCREMENT, import_session_id INTEGER, instrument_id INTEGER, quantity REAL, current_price REAL, report_date TEXT);
        INSERT INTO PositionReports (import_session_id,instrument_id,quantity,current_price,report_date) VALUES (1,1,1,45,'2025-08-20T14:05:00Z');
        INSERT INTO PositionReports (import_session_id,instrument_id,quantity,current_price,report_date) VALUES (1,2,1,55,'2025-08-20T14:05:00Z');
        """
        sqlite3_exec(db, sql, nil, nil, nil)
        let fxService = FXConversionService(dbManager: manager)
        let service = PortfolioValuationService(dbManager: manager, fxService: fxService)
        let snap = service.snapshot(themeId: 1)
        guard let row = snap.rows.first(where: { $0.instrumentId == 1 }) else {
            XCTFail("Row missing")
            return
        }
        XCTAssertEqual(round(row.actualPct * 10) / 10, 45.0)
        XCTAssertEqual(round((row.deltaResearchPct ?? 0) * 10) / 10, 15.0)
        XCTAssertEqual(round((row.deltaUserPct ?? 0) * 10) / 10, 10.0)
        sqlite3_close(db)
    }
}
