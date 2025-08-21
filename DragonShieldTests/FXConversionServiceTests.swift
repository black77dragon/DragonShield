import XCTest
import SQLite3
@testable import DragonShield

final class FXConversionServiceTests: XCTestCase {
    private func setupDB() -> DatabaseManager {
        let manager = DatabaseManager()
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        manager.db = db
        let sql = """
        CREATE TABLE ExchangeRates (currency_code TEXT, rate_date TEXT, rate_to_chf REAL);
        INSERT INTO ExchangeRates VALUES ('USD','2025-08-20T14:00:00Z',0.9);
        INSERT INTO ExchangeRates VALUES ('CHF','2025-08-20T14:00:00Z',1.0);
        INSERT INTO ExchangeRates VALUES ('EUR','2025-08-20T14:00:00Z',1.1);
        """
        sqlite3_exec(db, sql, nil, nil, nil)
        return manager
    }

    func testDirectConversion() {
        let manager = setupDB()
        let asOf = ISO8601DateFormatter().date(from: "2025-08-20T15:00:00Z")!
        let result = FXConversionService.convert(amount: 100, from: "USD", to: "CHF", asOf: asOf, db: manager)
        switch result {
        case let .converted(value, rate, date):
            XCTAssertEqual(rate, 0.9, accuracy: 0.0001)
            XCTAssertEqual(value, 90, accuracy: 0.01)
            XCTAssertEqual(ISO8601DateFormatter().string(from: date), "2025-08-20T14:00:00Z")
        default:
            XCTFail("Expected conversion")
        }
        sqlite3_close(manager.db)
    }

    func testReverseConversion() {
        let manager = setupDB()
        let asOf = ISO8601DateFormatter().date(from: "2025-08-20T15:00:00Z")!
        let result = FXConversionService.convert(amount: 100, from: "CHF", to: "USD", asOf: asOf, db: manager)
        switch result {
        case let .converted(value, _, _):
            XCTAssertEqual(value, 111.111, accuracy: 0.001)
        default:
            XCTFail("Expected conversion")
        }
        sqlite3_close(manager.db)
    }

    func testIdentityConversion() {
        let manager = setupDB()
        let asOf = ISO8601DateFormatter().date(from: "2025-08-20T15:00:00Z")!
        let result = FXConversionService.convert(amount: 50, from: "CHF", to: "CHF", asOf: asOf, db: manager)
        switch result {
        case let .converted(value, rate, date):
            XCTAssertEqual(rate, 1.0, accuracy: 0.0001)
            XCTAssertEqual(value, 50, accuracy: 0.0001)
            XCTAssertEqual(date, asOf)
        default:
            XCTFail("Expected conversion")
        }
        sqlite3_close(manager.db)
    }

    func testMissingRate() {
        let manager = setupDB()
        let asOf = ISO8601DateFormatter().date(from: "2025-08-20T15:00:00Z")!
        let result = FXConversionService.convert(amount: 10, from: "JPY", to: "CHF", asOf: asOf, db: manager)
        switch result {
        case .missing:
            XCTAssertTrue(true)
        default:
            XCTFail("Expected missing")
        }
        sqlite3_close(manager.db)
    }
}
