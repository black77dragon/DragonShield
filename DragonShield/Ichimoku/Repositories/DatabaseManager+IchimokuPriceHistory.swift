import Foundation
import SQLite3

private let SQLITE_TRANSIENT_PRICE = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

extension DatabaseManager {
    func ichimokuLatestPriceDate(for tickerId: Int) -> Date? {
        let sql = "SELECT price_date FROM ichimoku_price_history WHERE ticker_id = ? ORDER BY datetime(price_date) DESC LIMIT 1"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("❌ ichimokuLatestPriceDate prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(tickerId))
        guard sqlite3_step(statement) == SQLITE_ROW,
              let datePtr = sqlite3_column_text(statement, 0),
              let date = DateFormatter.iso8601DateOnly.date(from: String(cString: datePtr))
        else {
            return nil
        }
        return date
    }

    func ichimokuInsertPriceBars(_ bars: [IchimokuPriceBar]) -> (inserted: Int, updated: Int) {
        guard !bars.isEmpty else { return (0, 0) }
        let sql = """
            INSERT INTO ichimoku_price_history
                (ticker_id, price_date, open, high, low, close, volume, source)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(ticker_id, price_date) DO UPDATE SET
                open = excluded.open,
                high = excluded.high,
                low = excluded.low,
                close = excluded.close,
                volume = excluded.volume,
                source = excluded.source,
                updated_at = CURRENT_TIMESTAMP;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("❌ ichimokuInsertPriceBars prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return (0, 0)
        }
        defer { sqlite3_finalize(statement) }

        var inserted = 0
        var updated = 0
        for bar in bars {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            sqlite3_bind_int(statement, 1, Int32(bar.tickerId))
            let dateString = DateFormatter.iso8601DateOnly.string(from: bar.date)
            sqlite3_bind_text(statement, 2, (dateString as NSString).utf8String, -1, SQLITE_TRANSIENT_PRICE)
            sqlite3_bind_double(statement, 3, bar.open)
            sqlite3_bind_double(statement, 4, bar.high)
            sqlite3_bind_double(statement, 5, bar.low)
            sqlite3_bind_double(statement, 6, bar.close)
            if let volume = bar.volume {
                sqlite3_bind_double(statement, 7, volume)
            } else {
                sqlite3_bind_null(statement, 7)
            }
            if let source = bar.source {
                sqlite3_bind_text(statement, 8, (source as NSString).utf8String, -1, SQLITE_TRANSIENT_PRICE)
            } else {
                sqlite3_bind_null(statement, 8)
            }

            let result = sqlite3_step(statement)
            if result == SQLITE_DONE {
                if sqlite3_changes(db) == 1 {
                    inserted += 1
                } else {
                    updated += 1
                }
            } else {
                print("❌ ichimokuInsertPriceBars step failed: code=\(result) err=\(String(cString: sqlite3_errmsg(db)))")
            }
        }
        return (inserted, updated)
    }

    func ichimokuFetchPriceBars(tickerId: Int, limit: Int? = nil, ascending: Bool = true) -> [IchimokuPriceBar] {
        var sql = "SELECT price_date, open, high, low, close, volume, source FROM ichimoku_price_history WHERE ticker_id = ? ORDER BY datetime(price_date)"
        if !ascending { sql.append(" DESC") }
        if let limit, limit > 0 {
            sql.append(" LIMIT \(limit)")
        }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("❌ ichimokuFetchPriceBars prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return []
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(tickerId))
        var rows: [IchimokuPriceBar] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let datePtr = sqlite3_column_text(statement, 0),
                  let date = DateFormatter.iso8601DateOnly.date(from: String(cString: datePtr)) else { continue }
            let open = sqlite3_column_double(statement, 1)
            let high = sqlite3_column_double(statement, 2)
            let low = sqlite3_column_double(statement, 3)
            let close = sqlite3_column_double(statement, 4)
            let volume = sqlite3_column_type(statement, 5) == SQLITE_NULL ? nil : sqlite3_column_double(statement, 5)
            let source = sqlite3_column_text(statement, 6).map { String(cString: $0) }
            rows.append(IchimokuPriceBar(
                tickerId: tickerId,
                date: date,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: volume,
                source: source
            ))
        }
        return rows
    }

    func ichimokuDeletePriceBars(tickerId: Int, before cutoff: Date) -> Bool {
        let sql = "DELETE FROM ichimoku_price_history WHERE ticker_id = ? AND datetime(price_date) < datetime(?)"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("❌ ichimokuDeletePriceBars prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(tickerId))
        let dateString = DateFormatter.iso8601DateOnly.string(from: cutoff)
        sqlite3_bind_text(statement, 2, (dateString as NSString).utf8String, -1, SQLITE_TRANSIENT_PRICE)
        let ok = sqlite3_step(statement) == SQLITE_DONE
        if !ok {
            print("❌ ichimokuDeletePriceBars exec failed: \(String(cString: sqlite3_errmsg(db)))")
        }
        return ok
    }
}
