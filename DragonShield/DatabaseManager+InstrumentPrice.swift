import Foundation
import SQLite3

extension DatabaseManager {
    func getLatestPrice(instrumentId: Int) -> (price: Double, currency: String, asOf: String)? {
        let sql = "SELECT price, currency, as_of FROM InstrumentPriceLatest WHERE instrument_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(instrumentId))
        if sqlite3_step(stmt) == SQLITE_ROW {
            let price = sqlite3_column_double(stmt, 0)
            let curr = String(cString: sqlite3_column_text(stmt, 1))
            let asof = String(cString: sqlite3_column_text(stmt, 2))
            return (price, curr, asof)
        }
        return nil
    }

    func upsertPrice(instrumentId: Int, price: Double, currency: String, asOf: String, source: String? = nil) -> Bool {
        let sql = "INSERT OR REPLACE INTO InstrumentPrice(instrument_id, price, currency, source, as_of) VALUES (?,?,?,?,?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_int(stmt, 1, Int32(instrumentId))
        sqlite3_bind_double(stmt, 2, price)
        sqlite3_bind_text(stmt, 3, currency, -1, SQLITE_TRANSIENT)
        if let s = source { sqlite3_bind_text(stmt, 4, s, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 4) }
        sqlite3_bind_text(stmt, 5, asOf, -1, SQLITE_TRANSIENT)
        return sqlite3_step(stmt) == SQLITE_DONE
    }
}

