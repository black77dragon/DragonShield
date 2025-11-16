import Foundation
import SQLite3

private let SQLITE_TRANSIENT_CANDIDATE = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

extension DatabaseManager {
    func ichimokuReplaceDailyCandidates(scanDate: Date,
                                        rows: [IchimokuCandidateStoreRow])
    {
        let dateString = DateFormatter.iso8601DateOnly.string(from: scanDate)
        var deleteStmt: OpaquePointer?
        let deleteSQL = "DELETE FROM ichimoku_daily_candidates WHERE scan_date = ?"
        guard sqlite3_prepare_v2(db, deleteSQL, -1, &deleteStmt, nil) == SQLITE_OK else {
            print("❌ ichimokuReplaceDailyCandidates delete prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return
        }
        sqlite3_bind_text(deleteStmt, 1, (dateString as NSString).utf8String, -1, SQLITE_TRANSIENT_CANDIDATE)
        if sqlite3_step(deleteStmt) != SQLITE_DONE {
            print("❌ ichimokuReplaceDailyCandidates delete failed: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(deleteStmt)
        guard !rows.isEmpty else { return }

        let insertSQL = """
            INSERT INTO ichimoku_daily_candidates
                (scan_date, ticker_id, rank, momentum_score, close_price, tenkan, kijun,
                 tenkan_slope, kijun_slope, price_to_kijun_ratio, tenkan_kijun_distance, notes)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var insertStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &insertStmt, nil) == SQLITE_OK else {
            print("❌ ichimokuReplaceDailyCandidates insert prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return
        }
        defer { sqlite3_finalize(insertStmt) }

        for row in rows {
            sqlite3_reset(insertStmt)
            sqlite3_clear_bindings(insertStmt)
            sqlite3_bind_text(insertStmt, 1, (DateFormatter.iso8601DateOnly.string(from: row.scanDate) as NSString).utf8String, -1, SQLITE_TRANSIENT_CANDIDATE)
            sqlite3_bind_int(insertStmt, 2, Int32(row.tickerId))
            sqlite3_bind_int(insertStmt, 3, Int32(row.rank))
            sqlite3_bind_double(insertStmt, 4, row.momentumScore)
            sqlite3_bind_double(insertStmt, 5, row.closePrice)

            func bindOptionalDouble(_ value: Double?, index: Int32) {
                if let value {
                    sqlite3_bind_double(insertStmt, index, value)
                } else {
                    sqlite3_bind_null(insertStmt, index)
                }
            }

            bindOptionalDouble(row.tenkan, index: 6)
            bindOptionalDouble(row.kijun, index: 7)
            bindOptionalDouble(row.tenkanSlope, index: 8)
            bindOptionalDouble(row.kijunSlope, index: 9)
            bindOptionalDouble(row.priceToKijunRatio, index: 10)
            bindOptionalDouble(row.tenkanKijunDistance, index: 11)
            if let notes = row.notes {
                sqlite3_bind_text(insertStmt, 12, (notes as NSString).utf8String, -1, SQLITE_TRANSIENT_CANDIDATE)
            } else {
                sqlite3_bind_null(insertStmt, 12)
            }

            let result = sqlite3_step(insertStmt)
            if result != SQLITE_DONE {
                print("❌ ichimokuReplaceDailyCandidates insert step failed: code=\(result) err=\(String(cString: sqlite3_errmsg(db)))")
            }
        }
    }

    func ichimokuFetchCandidates(for scanDate: Date) -> [IchimokuCandidateRow] {
        let sql = """
            SELECT c.ticker_id, c.rank, c.momentum_score, c.close_price, c.tenkan, c.kijun,
                   c.tenkan_slope, c.kijun_slope, c.price_to_kijun_ratio, c.tenkan_kijun_distance, c.notes,
                   t.ticker_id, t.symbol, COALESCE(t.name,''), t.index_source, t.is_active, t.notes
              FROM ichimoku_daily_candidates c
              JOIN ichimoku_tickers t ON t.ticker_id = c.ticker_id
             WHERE c.scan_date = ?
             ORDER BY c.rank ASC;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("❌ ichimokuFetchCandidates prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return []
        }
        defer { sqlite3_finalize(statement) }
        let dateString = DateFormatter.iso8601DateOnly.string(from: scanDate)
        sqlite3_bind_text(statement, 1, (dateString as NSString).utf8String, -1, SQLITE_TRANSIENT_CANDIDATE)

        var rows: [IchimokuCandidateRow] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let tickerId = Int(sqlite3_column_int(statement, 0))
            let rank = Int(sqlite3_column_int(statement, 1))
            let momentumScore = sqlite3_column_double(statement, 2)
            let closePrice = sqlite3_column_double(statement, 3)

            func value(_ index: Int32) -> Double? {
                sqlite3_column_type(statement, index) == SQLITE_NULL ? nil : sqlite3_column_double(statement, index)
            }

            let tenkan = value(4)
            let kijun = value(5)
            let tenkanSlope = value(6)
            let kijunSlope = value(7)
            let priceToKijun = value(8)
            let tenkanKijunDistance = value(9)
            let notes = sqlite3_column_text(statement, 10).map { String(cString: $0) }

            let tickerSymbol = sqlite3_column_text(statement, 12).map { String(cString: $0) } ?? ""
            let tickerName = sqlite3_column_text(statement, 13).map { String(cString: $0) } ?? ""
            guard let indexSourcePtr = sqlite3_column_text(statement, 14),
                  let indexSource = IchimokuIndexSource(rawValue: String(cString: indexSourcePtr)) else { continue }
            let isActive = sqlite3_column_int(statement, 15) == 1
            let tickerNotes = sqlite3_column_text(statement, 16).map { String(cString: $0) }
            let ticker = IchimokuTicker(id: tickerId,
                                        symbol: tickerSymbol,
                                        name: tickerName,
                                        indexSource: indexSource,
                                        isActive: isActive,
                                        notes: tickerNotes)
            rows.append(IchimokuCandidateRow(
                scanDate: scanDate,
                ticker: ticker,
                rank: rank,
                momentumScore: momentumScore,
                closePrice: closePrice,
                tenkan: tenkan,
                kijun: kijun,
                tenkanSlope: tenkanSlope,
                kijunSlope: kijunSlope,
                priceToKijunRatio: priceToKijun,
                tenkanKijunDistance: tenkanKijunDistance,
                notes: notes
            ))
        }
        return rows
    }

    func ichimokuFetchRecentCandidateDates(limit: Int) -> [Date] {
        let sql = "SELECT DISTINCT scan_date FROM ichimoku_daily_candidates ORDER BY datetime(scan_date) DESC LIMIT ?"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("❌ ichimokuFetchRecentCandidateDates prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return []
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(limit))
        var dates: [Date] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let ptr = sqlite3_column_text(statement, 0),
               let date = DateFormatter.iso8601DateOnly.date(from: String(cString: ptr))
            {
                dates.append(date)
            }
        }
        return dates
    }
}
