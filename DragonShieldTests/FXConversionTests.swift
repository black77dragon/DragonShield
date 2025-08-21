import XCTest
import SQLite3
@testable import DragonShield

final class FXConversionTests: XCTestCase {
    private func setupManager() -> DatabaseManager {
        let manager = DatabaseManager()
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        manager.db = db
        let sql = """
        CREATE TABLE ExchangeRates (currency_code TEXT, rate_date TEXT, rate_to_chf REAL);
        INSERT INTO ExchangeRates VALUES ('USD','2025-08-20T14:00:00Z',0.9);
        INSERT INTO ExchangeRates VALUES ('CHF','2025-08-20T14:00:00Z',1.0);
        """
        sqlite3_exec(db, sql, nil, nil, nil)
        return manager
    }

    func testConvertReturnsCHFValue() {
        let manager = setupManager()
        if let result = manager.convert(amount: 10, from: "USD", to: "CHF", asOf: nil) {
            XCTAssertEqual(result.value, 9, accuracy: 0.0001)
        } else {
            XCTFail("Conversion failed")
        }
        sqlite3_close(manager.db)
    }

    func testConvertNilWhenRateMissing() {
        let manager = setupManager()
        let res = manager.convert(amount: 10, from: "EUR", to: "CHF", asOf: nil)
        XCTAssertNil(res)
        sqlite3_close(manager.db)
    }
}
