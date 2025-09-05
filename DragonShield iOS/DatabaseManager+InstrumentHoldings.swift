// iOS-specific helpers: Instrument holdings by account and positions as-of
// This keeps iOS screens lightweight by providing focused read-only queries.
#if os(iOS)
import Foundation
import SQLite3

extension DatabaseManager {
    struct InstrumentAccountHolding: Identifiable, Equatable {
        var accountId: Int
        var accountName: String
        var institutionName: String
        var quantity: Double
        var id: Int { accountId }
    }

    /// Aggregates positions for a given instrument across accounts.
    /// Returns one row per account with summed quantity and account/institution labels.
    func fetchInstrumentHoldingsByAccount(instrumentId: Int) -> [InstrumentAccountHolding] {
        var rows: [InstrumentAccountHolding] = []
        let sql = """
            SELECT a.account_id,
                   a.account_name,
                   ins.institution_name,
                   SUM(pr.quantity) AS qty
              FROM PositionReports pr
              JOIN Accounts a ON pr.account_id = a.account_id
              JOIN Institutions ins ON pr.institution_id = ins.institution_id
             WHERE pr.instrument_id = ?
             GROUP BY a.account_id, a.account_name, ins.institution_name
             ORDER BY a.account_name COLLATE NOCASE
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(instrumentId))
        while sqlite3_step(stmt) == SQLITE_ROW {
            let accountId = Int(sqlite3_column_int(stmt, 0))
            let accountName = String(cString: sqlite3_column_text(stmt, 1))
            let institutionName = String(cString: sqlite3_column_text(stmt, 2))
            let qty = sqlite3_column_double(stmt, 3)
            rows.append(InstrumentAccountHolding(accountId: accountId, accountName: accountName, institutionName: institutionName, quantity: qty))
        }
        return rows
    }

    /// Returns the latest positions snapshot date across all PositionReports (global as-of).
    func positionsAsOfDate() -> Date? {
        var stmt: OpaquePointer?
        let sql = "SELECT MAX(report_date) FROM PositionReports"
        var result: Date? = nil
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW, let cstr = sqlite3_column_text(stmt, 0) {
                let str = String(cString: cstr)
                result = DateFormatter.iso8601DateOnly.date(from: str)
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    /// Fetches the latest FX rate to CHF for a currency using ExchangeRates table.
    /// Uses is_latest=1 if present; otherwise falls back to most recent rate_date.
    /// Returns (rate, rateDate) or nil if no rate exists.
    func latestRateToChf(currencyCode: String) -> (rate: Double, date: Date)? {
        let code = currencyCode.uppercased()
        if code == "CHF" { return (1.0, .distantPast) }
        let sql = """
            SELECT rate_to_chf, rate_date
              FROM ExchangeRates
             WHERE UPPER(currency_code) = ? AND is_latest = 1
             LIMIT 1
        """
        var stmt: OpaquePointer?
        var result: (Double, Date)? = nil
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, code, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                let rate = sqlite3_column_double(stmt, 0)
                let dateStr = String(cString: sqlite3_column_text(stmt, 1))
                let d = DateFormatter.iso8601DateOnly.date(from: dateStr) ?? .distantPast
                result = (rate, d)
            }
        }
        sqlite3_finalize(stmt)
        if result == nil {
            // Fallback: pick the latest by date if no is_latest row
            let fallback = """
                SELECT rate_to_chf, rate_date
                  FROM ExchangeRates
                 WHERE UPPER(currency_code) = ?
                 ORDER BY rate_date DESC
                 LIMIT 1
            """
            var st: OpaquePointer?
            if sqlite3_prepare_v2(db, fallback, -1, &st, nil) == SQLITE_OK {
                let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                sqlite3_bind_text(st, 1, code, -1, SQLITE_TRANSIENT)
                if sqlite3_step(st) == SQLITE_ROW {
                    let rate = sqlite3_column_double(st, 0)
                    let dateStr = String(cString: sqlite3_column_text(st, 1))
                    let d = DateFormatter.iso8601DateOnly.date(from: dateStr) ?? .distantPast
                    result = (rate, d)
                }
            }
            sqlite3_finalize(st)
        }
        return result
    }
}
#endif
