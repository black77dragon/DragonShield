import XCTest
import SQLite3
@testable import DragonShield

final class ValuationParityTests: XCTestCase {
    private func setupManager() -> DatabaseManager {
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
        INSERT INTO PortfolioThemeAsset VALUES (1,1,50,50,NULL);
        INSERT INTO PortfolioThemeAsset VALUES (1,2,50,50,NULL);
        CREATE TABLE Instruments (instrument_id INTEGER PRIMARY KEY, instrument_name TEXT, currency TEXT);
        INSERT INTO Instruments VALUES (1,'AAPL','CHF');
        INSERT INTO Instruments VALUES (2,'MSFT','USD');
        CREATE TABLE PositionReports (position_id INTEGER PRIMARY KEY AUTOINCREMENT, import_session_id INTEGER, instrument_id INTEGER, quantity REAL, current_price REAL, report_date TEXT);
        INSERT INTO PositionReports (import_session_id,instrument_id,quantity,current_price,report_date) VALUES (10,1,10,100,'2025-08-20T14:05:00Z');
        INSERT INTO PositionReports (import_session_id,instrument_id,quantity,current_price,report_date) VALUES (10,2,5,10,'2025-08-20T14:05:00Z');
        CREATE TABLE ExchangeRates (currency_code TEXT, rate_date TEXT, rate_to_chf REAL);
        INSERT INTO ExchangeRates VALUES ('USD','2025-08-20T14:00:00Z',0.9);
        """
        sqlite3_exec(db, sql, nil, nil, nil)
        return manager
    }

    func testParityBetweenPositionsAndValuation() {
        let manager = setupManager()
        let positions = manager.fetchPositionReports()
        let model = PositionsViewModel()
        let exp = expectation(description: "values")
        model.calculateValues(positions: positions, db: manager)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)
        let service = PortfolioValuationService(dbManager: manager)
        let snap = service.snapshot(themeId: 1)
        for row in snap.rows where row.status == "OK" {
            if let valOpt = model.positionValueCHF[row.instrumentId], let vmVal = valOpt, let v = row.currentValueBase {
                XCTAssertEqual(vmVal, v, accuracy: 0.01)
            }
        }
        sqlite3_close(manager.db)
    }
}
