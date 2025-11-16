@testable import DragonShield
import SQLite3
import XCTest

final class FXConversionServiceTests: XCTestCase {
    private func makeManager() -> DatabaseManager {
        let manager = DatabaseManager()
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        manager.db = db
        let sql = """
        CREATE TABLE ExchangeRates (currency_code TEXT, rate_date TEXT, rate_to_chf REAL, is_latest INTEGER);
        INSERT INTO ExchangeRates VALUES ('USD','2025-01-01',0.9,1);
        INSERT INTO ExchangeRates VALUES ('EUR','2025-01-01',1.1,1);
        """
        sqlite3_exec(db, sql, nil, nil, nil)
        return manager
    }

    func testConvertsUsingLatestRate() {
        let manager = makeManager()
        let svc = FXConversionService(dbManager: manager)
        let result = svc.convertToChf(amount: 100, currency: "USD")
        XCTAssertEqual(result?.valueChf, 90, accuracy: 0.001)
        sqlite3_close(manager.db)
    }

    func testIdentityForChf() {
        let manager = makeManager()
        let svc = FXConversionService(dbManager: manager)
        let result = svc.convertToChf(amount: 50, currency: "CHF")
        XCTAssertEqual(result?.valueChf, 50, accuracy: 0.001)
        XCTAssertEqual(result?.rate, 1.0)
        sqlite3_close(manager.db)
    }

    func testReturnsNilWhenMissing() {
        let manager = makeManager()
        let svc = FXConversionService(dbManager: manager)
        let result = svc.convertToChf(amount: 100, currency: "JPY")
        XCTAssertNil(result)
        sqlite3_close(manager.db)
    }
}
