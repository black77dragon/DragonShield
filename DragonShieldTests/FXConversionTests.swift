import XCTest
import SQLite3
@testable import DragonShield

final class FXConversionTests: XCTestCase {
    func testConvertToChfUsesExchangeRate() {
        let manager = DatabaseManager()
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        manager.db = db
        let sql = """
        CREATE TABLE ExchangeRates (
            rate_id INTEGER PRIMARY KEY AUTOINCREMENT,
            currency_code TEXT,
            rate_date TEXT,
            rate_to_chf REAL,
            rate_source TEXT,
            api_provider TEXT,
            is_latest INTEGER,
            created_at TEXT
        );
        INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, api_provider, is_latest, created_at)
        VALUES ('USD','2025-01-01',0.9,'manual',NULL,1,'2025-01-01 00:00:00');
        """
        sqlite3_exec(db, sql, nil, nil, nil)
        let result = manager.convertToChf(amount: 100, currency: "USD", asOf: nil)
        XCTAssertEqual(result?.valueChf, 90, accuracy: 0.0001)
        sqlite3_close(db)
    }

    func testConvertToChfIdentityForChf() {
        let manager = DatabaseManager()
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        manager.db = db
        let result = manager.convertToChf(amount: 50, currency: "CHF", asOf: nil)
        XCTAssertEqual(result?.valueChf, 50, accuracy: 0.0001)
        sqlite3_close(db)
    }

    func testConvertToChfMissingRateReturnsNil() {
        let manager = DatabaseManager()
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        manager.db = db
        let sql = """
        CREATE TABLE ExchangeRates (
            rate_id INTEGER PRIMARY KEY AUTOINCREMENT,
            currency_code TEXT,
            rate_date TEXT,
            rate_to_chf REAL,
            rate_source TEXT,
            api_provider TEXT,
            is_latest INTEGER,
            created_at TEXT
        );
        """
        sqlite3_exec(db, sql, nil, nil, nil)
        let result = manager.convertToChf(amount: 10, currency: "JPY", asOf: nil)
        XCTAssertNil(result)
        sqlite3_close(db)
    }
}

