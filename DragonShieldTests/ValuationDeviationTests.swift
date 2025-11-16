@testable import DragonShield
import SQLite3
import XCTest

final class ValuationDeviationTests: XCTestCase {
    private func setupDb(includeExcluded: Bool) -> DatabaseManager {
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
        CREATE TABLE PortfolioThemeAsset (theme_id INTEGER, instrument_id INTEGER, research_target_pct REAL, user_target_pct REAL, rwk_set_target_chf REAL, notes TEXT, PRIMARY KEY(theme_id,instrument_id));
        INSERT INTO PortfolioThemeAsset VALUES (1,1,30,35,NULL);
        INSERT INTO PortfolioThemeAsset VALUES (1,2,70,65,NULL);
        """
        sqlite3_exec(db, sql, nil, nil, nil)
        if includeExcluded {
            let more = "INSERT INTO PortfolioThemeAsset VALUES (1,3,5,5,NULL);"
            sqlite3_exec(db, more, nil, nil, nil)
        }
        let moreSql = """
        CREATE TABLE Instruments (instrument_id INTEGER PRIMARY KEY, instrument_name TEXT, currency TEXT);
        INSERT INTO Instruments VALUES (1,'A','CHF');
        INSERT INTO Instruments VALUES (2,'B','CHF');
        """
        sqlite3_exec(db, moreSql, nil, nil, nil)
        if includeExcluded {
            let ins3 = "INSERT INTO Instruments VALUES (3,'C','USD');"
            sqlite3_exec(db, ins3, nil, nil, nil)
        }
        let posSql = """
        CREATE TABLE PositionReports (position_id INTEGER PRIMARY KEY AUTOINCREMENT, import_session_id INTEGER, instrument_id INTEGER, quantity REAL, current_price REAL, report_date TEXT);
        INSERT INTO PositionReports VALUES (1,1,1,45,1,'2025-08-20T14:05:00Z');
        INSERT INTO PositionReports VALUES (2,1,2,55,1,'2025-08-20T14:05:00Z');
        """
        sqlite3_exec(db, posSql, nil, nil, nil)
        if includeExcluded {
            let pos3 = "INSERT INTO PositionReports VALUES (3,1,3,10,1,'2025-08-20T14:05:00Z');"
            sqlite3_exec(db, pos3, nil, nil, nil)
        }
        let fxSql = "CREATE TABLE ExchangeRates (currency_code TEXT, rate_date TEXT, rate_to_chf REAL, is_latest INTEGER);"
        sqlite3_exec(db, fxSql, nil, nil, nil)
        return manager
    }

    func testDeltaCalculations() {
        let manager = setupDb(includeExcluded: false)
        let fxService = FXConversionService(dbManager: manager)
        let service = PortfolioValuationService(dbManager: manager, fxService: fxService)
        let snap = service.snapshot(themeId: 1)
        guard let row = snap.rows.first(where: { $0.instrumentId == 1 }) else {
            XCTFail("Row not found")
            return
        }
        XCTAssertEqual(row.actualPct, 45, accuracy: 0.001)
        XCTAssertEqual(row.deltaResearchPct, row.actualPct - row.researchTargetPct, accuracy: 0.001)
        XCTAssertEqual(row.deltaUserPct, row.actualPct - row.userTargetPct, accuracy: 0.001)
        sqlite3_close(manager.db)
    }

    func testFilteringSkipsExcludedRows() {
        let manager = setupDb(includeExcluded: true)
        let fxService = FXConversionService(dbManager: manager)
        let service = PortfolioValuationService(dbManager: manager, fxService: fxService)
        let snap = service.snapshot(themeId: 1)
        let filtered = filter(rows: snap.rows, tolerance: 2.0, showResearch: true, showUser: true)
        XCTAssertEqual(filtered.count, 1)
        XCTAssertNil(snap.rows.first(where: { $0.status != .ok })?.deltaResearchPct)
        sqlite3_close(manager.db)
    }

    func testFilterRespectsVisibleColumns() {
        let manager = setupDb(includeExcluded: false)
        let fxService = FXConversionService(dbManager: manager)
        let service = PortfolioValuationService(dbManager: manager, fxService: fxService)
        let snap = service.snapshot(themeId: 1)
        let rows = snap.rows
        let onlyResearch = filter(rows: rows, tolerance: 12.0, showResearch: true, showUser: false)
        XCTAssertEqual(onlyResearch.count, 1)
        let onlyUser = filter(rows: rows, tolerance: 12.0, showResearch: false, showUser: true)
        XCTAssertEqual(onlyUser.count, 0)
        sqlite3_close(manager.db)
    }

    private func filter(rows: [ValuationRow], tolerance: Double, showResearch: Bool, showUser: Bool) -> [ValuationRow] {
        rows.filter { row in
            var out = false
            if showResearch, let d = row.deltaResearchPct, abs(d) > tolerance { out = true }
            if showUser, let d = row.deltaUserPct, abs(d) > tolerance { out = true }
            return out
        }
    }
}
