import XCTest
import SQLite3
@testable import DragonShield

final class FXConversionServiceTests: XCTestCase {
    private func setupDB(_ rates: [(String,String)]) -> DatabaseManager {
        let manager = DatabaseManager()
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        manager.db = db
        let sql = "CREATE TABLE ExchangeRates (currency_code TEXT, rate_date TEXT, rate_to_chf REAL);" + rates.map { "INSERT INTO ExchangeRates VALUES ('\($0.0)', '2025-08-20T14:00:00Z', \($0.1));" }.joined()
        sqlite3_exec(db, sql, nil, nil, nil)
        return manager
    }

    func testDirectConversion() {
        let manager = setupDB([("USD","0.8")])
        let asOf = ISO8601DateFormatter().date(from: "2025-08-20T15:00:00Z")!
        let conv = FXConversionService.convert(amount: 100, from: "USD", to: "CHF", asOf: asOf, db: manager.db)
        XCTAssertEqual(conv?.value, 80, accuracy: 0.001)
        sqlite3_close(manager.db)
    }

    func testReverseConversion() {
        let manager = setupDB([("USD","0.8"),("CHF","1.0")])
        let asOf = ISO8601DateFormatter().date(from: "2025-08-20T15:00:00Z")!
        let conv = FXConversionService.convert(amount: 100, from: "CHF", to: "USD", asOf: asOf, db: manager.db)
        XCTAssertEqual(conv?.value, 125, accuracy: 0.001)
        sqlite3_close(manager.db)
    }

    func testIdentityConversion() {
        let manager = setupDB([("USD","0.8")])
        let asOf = ISO8601DateFormatter().date(from: "2025-08-20T15:00:00Z")!
        let conv = FXConversionService.convert(amount: 50, from: "CHF", to: "CHF", asOf: asOf, db: manager.db)
        XCTAssertEqual(conv?.value, 50)
        sqlite3_close(manager.db)
    }

    func testMissingRateReturnsNil() {
        let manager = setupDB([("USD","0.8")])
        let asOf = ISO8601DateFormatter().date(from: "2025-08-20T15:00:00Z")!
        let conv = FXConversionService.convert(amount: 10, from: "JPY", to: "CHF", asOf: asOf, db: manager.db)
        XCTAssertNil(conv)
        sqlite3_close(manager.db)
    }
}
