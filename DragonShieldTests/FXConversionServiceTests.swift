import XCTest
import SQLite3
@testable import DragonShield

final class FXConversionServiceTests: XCTestCase {
    private func manager() -> DatabaseManager {
        let m = DatabaseManager()
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        m.db = db
        let sql = """
        CREATE TABLE ExchangeRates (currency_code TEXT, rate_date TEXT, rate_to_chf REAL);
        INSERT INTO ExchangeRates VALUES ('USD','2025-08-20T14:00:00Z',0.8);
        INSERT INTO ExchangeRates VALUES ('CHF','2025-08-20T14:00:00Z',1.0);
        INSERT INTO ExchangeRates VALUES ('EUR','2025-08-20T14:00:00Z',0.9);
        """
        sqlite3_exec(db, sql, nil, nil, nil)
        return m
    }

    func testIdentity() {
        let m = manager()
        let svc = FXConversionService(dbManager: m)
        let df = ISO8601DateFormatter()
        let date = df.date(from: "2025-08-20T14:00:00Z")!
        guard let res = svc.convert(amount: 100, from: "CHF", to: "CHF", asOf: date) else {
            XCTFail("Missing")
            return
        }
        XCTAssertEqual(res.value, 100, accuracy: 0.001)
        XCTAssertEqual(res.rate, 1.0, accuracy: 0.001)
        XCTAssertEqual(df.string(from: res.rateAsOf), "2025-08-20T14:00:00Z")
        sqlite3_close(m.db)
    }

    func testDirect() {
        let m = manager()
        let svc = FXConversionService(dbManager: m)
        let df = ISO8601DateFormatter()
        let date = df.date(from: "2025-08-20T14:00:00Z")!
        guard let res = svc.convert(amount: 100, from: "USD", to: "CHF", asOf: date) else {
            XCTFail("Missing")
            return
        }
        XCTAssertEqual(res.value, 80, accuracy: 0.001)
        XCTAssertEqual(res.rate, 0.8, accuracy: 0.001)
        sqlite3_close(m.db)
    }

    func testReverse() {
        let m = manager()
        let svc = FXConversionService(dbManager: m)
        let df = ISO8601DateFormatter()
        let date = df.date(from: "2025-08-20T14:00:00Z")!
        guard let res = svc.convert(amount: 100, from: "CHF", to: "USD", asOf: date) else {
            XCTFail("Missing")
            return
        }
        XCTAssertEqual(res.value, 125, accuracy: 0.001)
        XCTAssertEqual(res.rate, 1.25, accuracy: 0.001)
        sqlite3_close(m.db)
    }

    func testMissing() {
        let m = manager()
        let svc = FXConversionService(dbManager: m)
        let df = ISO8601DateFormatter()
        let date = df.date(from: "2025-08-20T14:00:00Z")!
        let res = svc.convert(amount: 100, from: "JPY", to: "CHF", asOf: date)
        XCTAssertNil(res)
        sqlite3_close(m.db)
    }
}
