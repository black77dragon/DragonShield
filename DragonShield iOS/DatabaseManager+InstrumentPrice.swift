// iOS: Minimal price lookup for InstrumentPriceLatest view
#if os(iOS)
    import Foundation
    import SQLite3

    extension DatabaseManager {
        /// Returns latest price tuple for an instrument from InstrumentPriceLatest view.
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
    }
#endif
