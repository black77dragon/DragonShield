import XCTest
import SQLite3
@testable import DragonShield

final class FXConverterTests: XCTestCase {
    private func makeManager(sql: String) -> DatabaseManager {
        let m = DatabaseManager()
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        m.db = db
        sqlite3_exec(db, sql, nil, nil, nil)
        return m
    }

    func testConvertToChfUsesLatestRate() {
        let sql = """
        CREATE TABLE ExchangeRates (currency_code TEXT, rate_date TEXT, rate_to_chf REAL);
        INSERT INTO ExchangeRates VALUES ('USD','2024-01-01T00:00:00Z',0.9);
        INSERT INTO ExchangeRates VALUES ('USD','2024-01-02T00:00:00Z',0.95);
        """
        let manager = makeManager(sql: sql)
        let converter = FXConverter(dbManager: manager)
        var fxDate: Date? = nil
        let result = converter.chfValue(value: 100, currency: "USD", asOf: nil, fxAsOf: &fxDate)
        XCTAssertEqual(result, 95, accuracy: 0.001)
        let df = ISO8601DateFormatter()
        XCTAssertEqual(df.string(from: fxDate!), "2024-01-02T00:00:00Z")
        sqlite3_close(manager.db)
    }

    func testConvertCrossCurrency() {
        let sql = """
        CREATE TABLE ExchangeRates (currency_code TEXT, rate_date TEXT, rate_to_chf REAL);
        INSERT INTO ExchangeRates VALUES ('USD','2024-01-02T00:00:00Z',0.9);
        INSERT INTO ExchangeRates VALUES ('EUR','2024-01-02T00:00:00Z',1.1);
        """
        let manager = makeManager(sql: sql)
        let converter = FXConverter(dbManager: manager)
        var fxDate: Date? = nil
        let value = converter.convert(value: 100, from: "USD", to: "EUR", asOf: nil, fxAsOf: &fxDate)
        XCTAssertEqual(value, 100 * 0.9 / 1.1, accuracy: 0.001)
        sqlite3_close(manager.db)
    }
}
