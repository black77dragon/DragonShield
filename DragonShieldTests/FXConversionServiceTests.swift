import XCTest
import SQLite3
@testable import DragonShield

final class FXConversionServiceTests: XCTestCase {
    private func makeDB() -> DatabaseManager {
        let manager = DatabaseManager()
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        manager.db = db
        let sql = """
        CREATE TABLE ExchangeRates (currency_code TEXT, rate_date TEXT, rate_to_chf REAL);
        INSERT INTO ExchangeRates VALUES ('USD','2025-01-01T00:00:00Z',0.9);
        INSERT INTO ExchangeRates VALUES ('EUR','2025-01-01T00:00:00Z',1.1);
        """
        sqlite3_exec(db, sql, nil, nil, nil)
        return manager
    }

    func testIdentity() {
        let db = makeDB()
        let result = FXConversionService.convert(amount: 100, fromCcy: "CHF", toCcy: "CHF", asOf: Date(), db: db)
        XCTAssertEqual(result?.value, 100, accuracy: 0.01)
        sqlite3_close(db.db)
    }

    func testDirect() {
        let db = makeDB()
        let asOf = ISO8601DateFormatter().date(from: "2025-02-01T00:00:00Z")!
        let result = FXConversionService.convert(amount: 100, fromCcy: "USD", toCcy: "CHF", asOf: asOf, db: db)
        XCTAssertEqual(result?.value, 90, accuracy: 0.01)
        sqlite3_close(db.db)
    }

    func testReverse() {
        let db = makeDB()
        let asOf = ISO8601DateFormatter().date(from: "2025-02-01T00:00:00Z")!
        let result = FXConversionService.convert(amount: 90, fromCcy: "CHF", toCcy: "USD", asOf: asOf, db: db)
        XCTAssertEqual(result?.value, 100, accuracy: 0.01)
        sqlite3_close(db.db)
    }

    func testMissing() {
        let db = makeDB()
        let asOf = ISO8601DateFormatter().date(from: "2025-02-01T00:00:00Z")!
        let result = FXConversionService.convert(amount: 100, fromCcy: "JPY", toCcy: "CHF", asOf: asOf, db: db)
        XCTAssertNil(result)
        sqlite3_close(db.db)
    }
}
