import Foundation
import SQLite3

private let SQLITE_TRANSIENT_INDICATOR = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

extension DatabaseManager {
    func ichimokuUpsertIndicators(_ rows: [IchimokuIndicatorRow]) {
        guard !rows.isEmpty else { return }
        let sql = """
            INSERT INTO ichimoku_indicators
                (ticker_id, calc_date, tenkan, kijun, senkou_a, senkou_b, chikou,
                 tenkan_slope, kijun_slope, price_to_kijun_ratio, tenkan_kijun_distance, momentum_score)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(ticker_id, calc_date) DO UPDATE SET
                tenkan = excluded.tenkan,
                kijun = excluded.kijun,
                senkou_a = excluded.senkou_a,
                senkou_b = excluded.senkou_b,
                chikou = excluded.chikou,
                tenkan_slope = excluded.tenkan_slope,
                kijun_slope = excluded.kijun_slope,
                price_to_kijun_ratio = excluded.price_to_kijun_ratio,
                tenkan_kijun_distance = excluded.tenkan_kijun_distance,
                momentum_score = excluded.momentum_score,
                updated_at = CURRENT_TIMESTAMP;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("❌ ichimokuUpsertIndicators prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return
        }
        defer { sqlite3_finalize(statement) }

        for row in rows {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            sqlite3_bind_int(statement, 1, Int32(row.tickerId))
            let dateString = DateFormatter.iso8601DateOnly.string(from: row.date)
            sqlite3_bind_text(statement, 2, (dateString as NSString).utf8String, -1, SQLITE_TRANSIENT_INDICATOR)

            func bindDouble(_ value: Double?, index: Int32) {
                if let value {
                    sqlite3_bind_double(statement, index, value)
                } else {
                    sqlite3_bind_null(statement, index)
                }
            }

            bindDouble(row.tenkan, index: 3)
            bindDouble(row.kijun, index: 4)
            bindDouble(row.senkouA, index: 5)
            bindDouble(row.senkouB, index: 6)
            bindDouble(row.chikou, index: 7)
            bindDouble(row.tenkanSlope, index: 8)
            bindDouble(row.kijunSlope, index: 9)
            bindDouble(row.priceToKijunRatio, index: 10)
            bindDouble(row.tenkanKijunDistance, index: 11)
            bindDouble(row.momentumScore, index: 12)

            if sqlite3_step(statement) != SQLITE_DONE {
                print("❌ ichimokuUpsertIndicators step failed: \(String(cString: sqlite3_errmsg(db)))")
            }
        }
    }

    func ichimokuFetchIndicators(tickerId: Int, limit: Int? = nil) -> [IchimokuIndicatorRow] {
        var sql = "SELECT calc_date, tenkan, kijun, senkou_a, senkou_b, chikou, tenkan_slope, kijun_slope, price_to_kijun_ratio, tenkan_kijun_distance, momentum_score FROM ichimoku_indicators WHERE ticker_id = ? ORDER BY datetime(calc_date) DESC"
        if let limit, limit > 0 {
            sql.append(" LIMIT \(limit)")
        }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("❌ ichimokuFetchIndicators prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return []
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(tickerId))
        var rows: [IchimokuIndicatorRow] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let datePtr = sqlite3_column_text(statement, 0),
                  let date = DateFormatter.iso8601DateOnly.date(from: String(cString: datePtr)) else { continue }
            func value(_ idx: Int32) -> Double? {
                sqlite3_column_type(statement, idx) == SQLITE_NULL ? nil : sqlite3_column_double(statement, idx)
            }
            rows.append(IchimokuIndicatorRow(
                tickerId: tickerId,
                date: date,
                tenkan: value(1),
                kijun: value(2),
                senkouA: value(3),
                senkouB: value(4),
                chikou: value(5),
                tenkanSlope: value(6),
                kijunSlope: value(7),
                priceToKijunRatio: value(8),
                tenkanKijunDistance: value(9),
                momentumScore: value(10)
            ))
        }
        return rows
    }

    func ichimokuFetchLatestIndicator(tickerId: Int) -> IchimokuIndicatorRow? {
        ichimokuFetchIndicators(tickerId: tickerId, limit: 1).first
    }
}
