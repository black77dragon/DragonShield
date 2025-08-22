import XCTest
import SQLite3
@testable import DragonShield

final class ThemeValuationFxParityTests: XCTestCase {
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
        INSERT INTO PortfolioThemeAsset VALUES (1,1,20,20,NULL);
        INSERT INTO PortfolioThemeAsset VALUES (1,2,20,20,NULL);
        INSERT INTO PortfolioThemeAsset VALUES (1,3,20,20,NULL);
        INSERT INTO PortfolioThemeAsset VALUES (1,4,20,20,NULL);
        INSERT INTO PortfolioThemeAsset VALUES (1,5,20,20,NULL);
        CREATE TABLE Instruments (instrument_id INTEGER PRIMARY KEY, instrument_name TEXT, currency TEXT);
        INSERT INTO Instruments VALUES (1,'AAPL','CHF');
        INSERT INTO Instruments VALUES (2,'MSFT','USD');
        INSERT INTO Instruments VALUES (3,'VOO','EUR');
        INSERT INTO Instruments VALUES (4,'SONY','JPY');
        INSERT INTO Instruments VALUES (5,'BABA','SGD');
        CREATE TABLE PositionReports (position_id INTEGER PRIMARY KEY AUTOINCREMENT, import_session_id INTEGER, instrument_id INTEGER, quantity REAL, current_price REAL, report_date TEXT);
        INSERT INTO PositionReports (import_session_id,instrument_id,quantity,current_price,report_date) VALUES (10,1,15,100,'2025-08-20T14:05:00Z');
        INSERT INTO PositionReports (import_session_id,instrument_id,quantity,current_price,report_date) VALUES (10,2,50,10,'2025-08-20T14:05:00Z');
        INSERT INTO PositionReports (import_session_id,instrument_id,quantity,current_price,report_date) VALUES (10,3,7,100,'2025-08-20T14:05:00Z');
        INSERT INTO PositionReports (import_session_id,instrument_id,quantity,current_price,report_date) VALUES (10,4,1000,1,'2025-08-20T14:05:00Z');
        INSERT INTO PositionReports (import_session_id,instrument_id,quantity,current_price,report_date) VALUES (10,5,100,1,'2025-08-20T14:05:00Z');
        CREATE TABLE ExchangeRates (currency_code TEXT, rate_date TEXT, rate_to_chf REAL, is_latest INTEGER);
        INSERT INTO ExchangeRates VALUES ('USD','2025-08-20T14:00:00Z',0.9,1);
        INSERT INTO ExchangeRates VALUES ('EUR','2025-08-20T14:00:00Z',1.1,1);
        """
        sqlite3_exec(db, sql, nil, nil, nil)
        return manager
    }

    func testValuationMatchesFxConversionServiceAndExclusions() {
        let manager = setupManager()
        let fxService = FXConversionService(dbManager: manager)
        let service = PortfolioValuationService(dbManager: manager, fxService: fxService)
        let snap = service.snapshot(themeId: 1)
        XCTAssertEqual(snap.totalValueBase, 2720, accuracy: 0.01)
        XCTAssertEqual(snap.excludedFxCount, 2)
        XCTAssertEqual(snap.rows.count, 5)
        let rows = Dictionary(uniqueKeysWithValues: snap.rows.map { ($0.instrumentId, $0) })
        let usdExpected = fxService.convertToChf(amount: 500, currency: "USD")!.valueChf
        XCTAssertEqual(rows[2]?.currentValueBase, usdExpected, accuracy: 0.01)
        let eurExpected = fxService.convertToChf(amount: 700, currency: "EUR")!.valueChf
        XCTAssertEqual(rows[3]?.currentValueBase, eurExpected, accuracy: 0.01)
        XCTAssertEqual(rows[4]?.status, "FX missing — excluded")
        XCTAssertEqual(rows[5]?.status, "FX missing — excluded")
        sqlite3_close(manager.db)
    }
}

