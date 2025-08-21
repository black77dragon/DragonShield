import XCTest
import SQLite3
@testable import DragonShield

final class PortfolioValuationServiceTests: XCTestCase {
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
        INSERT INTO PortfolioThemeAsset VALUES (1,1,25,25,NULL);
        INSERT INTO PortfolioThemeAsset VALUES (1,2,25,20,'Tech');
        INSERT INTO PortfolioThemeAsset VALUES (1,3,30,35,NULL);
        INSERT INTO PortfolioThemeAsset VALUES (1,4,20,20,NULL);
        CREATE TABLE Instruments (instrument_id INTEGER PRIMARY KEY, instrument_name TEXT, currency TEXT);
        INSERT INTO Instruments VALUES (1,'AAPL','CHF');
        INSERT INTO Instruments VALUES (2,'MSFT','USD');
        INSERT INTO Instruments VALUES (3,'VOO','EUR');
        INSERT INTO Instruments VALUES (4,'CASH','CHF');
        CREATE TABLE PositionReports (position_id INTEGER PRIMARY KEY AUTOINCREMENT, import_session_id INTEGER, instrument_id INTEGER, quantity REAL, current_price REAL, report_date TEXT);
        INSERT INTO PositionReports (import_session_id,instrument_id,quantity,current_price,report_date) VALUES (10,1,10,100,'2025-08-20T14:05:00Z');
        INSERT INTO PositionReports (import_session_id,instrument_id,quantity,current_price,report_date) VALUES (10,1,5,100,'2025-08-20T14:05:00Z');
        INSERT INTO PositionReports (import_session_id,instrument_id,quantity,current_price,report_date) VALUES (10,2,50,10,'2025-08-20T14:05:00Z');
        INSERT INTO PositionReports (import_session_id,instrument_id,quantity,current_price,report_date) VALUES (10,3,7,100,'2025-08-20T14:05:00Z');
        CREATE TABLE ExchangeRates (currency_code TEXT, rate_date TEXT, rate_to_chf REAL);
        INSERT INTO ExchangeRates VALUES ('USD','2025-08-20T14:00:00Z',0.9);
        """
        sqlite3_exec(db, sql, nil, nil, nil)
        return manager
    }

    func testSnapshotAggregatesAndStatuses() {
        let manager = setupManager()
        let service = PortfolioValuationService(dbManager: manager)
        let snap = service.snapshot(themeId: 1)
        XCTAssertEqual(snap.totalValueBase, 1950, accuracy: 0.01)
        XCTAssertEqual(snap.excludedFxCount, 1)
        let rows = Dictionary(uniqueKeysWithValues: snap.rows.map { ($0.instrumentId, $0) })
        XCTAssertEqual(rows[1]?.currentValueBase, 1500, accuracy: 0.01)
        XCTAssertEqual(rows[1]?.status, "OK")
        XCTAssertEqual(rows[2]?.currentValueBase, 450, accuracy: 0.01)
        XCTAssertEqual(rows[2]?.notes, "Tech")
        XCTAssertEqual(rows[2]?.status, "OK")
        XCTAssertEqual(rows[3]?.status, "FX missing — excluded")
        XCTAssertEqual(rows[4]?.status, "No position")
        if let posAsOf = snap.positionsAsOf {
            let conv = FXConversionService.convert(amount: 50 * 10, from: "USD", to: "CHF", asOf: posAsOf, db: manager.db)
            XCTAssertEqual(conv?.value, rows[2]?.currentValueBase, accuracy: 0.01)
        }
        sqlite3_close(manager.db)
    }

    func testRateInvertsWhenOnlyBaseRatePresent() {
        let manager = DatabaseManager()
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        manager.db = db
        manager.baseCurrency = "USD"
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
        INSERT INTO PositionReports (import_session_id,instrument_id,quantity,current_price,report_date) VALUES (10,1,10,10,'2025-08-20T14:05:00Z');
        CREATE TABLE ExchangeRates (currency_code TEXT, rate_date TEXT, rate_to_chf REAL);
        INSERT INTO ExchangeRates VALUES ('USD','2025-08-20T14:00:00Z',0.8);
        INSERT INTO ExchangeRates VALUES ('CHF','2025-08-20T14:00:00Z',1.0);
        """
        sqlite3_exec(db, sql, nil, nil, nil)
        let service = PortfolioValuationService(dbManager: manager)
        let snap = service.snapshot(themeId: 1)
        XCTAssertEqual(snap.rows.first?.currentValueBase, 125, accuracy: 0.01)
        XCTAssertEqual(snap.rows.first?.status, "OK")
        let df = ISO8601DateFormatter()
        XCTAssertEqual(df.string(from: snap.fxAsOf!), "2025-08-20T14:00:00Z")
        sqlite3_close(manager.db)
    }

    func testLogsWarningWhenRateDateInvalid() {
        LoggingService.shared.clearLog()
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
        INSERT INTO Instruments VALUES (1,'MSFT','USD');
        CREATE TABLE PositionReports (position_id INTEGER PRIMARY KEY AUTOINCREMENT, import_session_id INTEGER, instrument_id INTEGER, quantity REAL, current_price REAL, report_date TEXT);
        INSERT INTO PositionReports (import_session_id,instrument_id,quantity,current_price,report_date) VALUES (10,1,50,10,'2025-08-20T14:05:00Z');
        CREATE TABLE ExchangeRates (currency_code TEXT, rate_date TEXT, rate_to_chf REAL);
        INSERT INTO ExchangeRates VALUES ('USD','invalid',0.9);
        """
        sqlite3_exec(db, sql, nil, nil, nil)
        let service = PortfolioValuationService(dbManager: manager)
        _ = service.snapshot(themeId: 1)
        Thread.sleep(forTimeInterval: 0.1)
        let log = LoggingService.shared.readLog()
        XCTAssertTrue(log.contains("Failed to parse rate_date for currency 'USD'"))
        sqlite3_close(manager.db)
    }

    func testLogsStructuredValuationEvent() {
        LoggingService.shared.clearLog()
        let manager = setupManager()
        let service = PortfolioValuationService(dbManager: manager)
        _ = service.snapshot(themeId: 1)
        Thread.sleep(forTimeInterval: 0.1)
        let log = LoggingService.shared.readLog()
        XCTAssertTrue(log.contains("\"fx_source\":\"PositionsParity\""))
        sqlite3_close(manager.db)
    }
}
