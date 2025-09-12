import Foundation
import SQLite3

extension DatabaseManager {
    struct HoldingRow: Identifiable, Equatable {
        var id: String // composite key: instrument_id-account_id
        var portfolioName: String?
        var instrumentId: Int
        var instrumentName: String
        var accountId: Int
        var accountName: String
        var currency: String
        var totalQuantity: Double
        var avgCostChfPerUnit: Double
        var totalInvestedChf: Double
        var totalSoldChf: Double
        var totalDividendsChf: Double
        var transactionCount: Int
        var firstDate: Date?
        var lastDate: Date?
    }

    func fetchHoldingsFromTransactions() -> [HoldingRow] {
        var rows: [HoldingRow] = []
        let sql = """
            SELECT portfolio_id, portfolio_name, instrument_id, instrument_name, account_id, account_name,
                   instrument_currency, total_quantity, avg_cost_chf_per_unit, total_invested_chf,
                   total_sold_chf, total_dividends_chf, transaction_count, first_transaction_date, last_transaction_date
              FROM Positions
             ORDER BY account_name COLLATE NOCASE, instrument_name COLLATE NOCASE;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            let portfolioIdType = sqlite3_column_type(stmt, 0)
            let portfolioName: String? = sqlite3_column_type(stmt, 1) != SQLITE_NULL ? String(cString: sqlite3_column_text(stmt, 1)) : nil
            let instrumentId = Int(sqlite3_column_int(stmt, 2))
            let instrumentName = String(cString: sqlite3_column_text(stmt, 3))
            let accountId = Int(sqlite3_column_int(stmt, 4))
            let accountName = String(cString: sqlite3_column_text(stmt, 5))
            let currency = String(cString: sqlite3_column_text(stmt, 6))
            let qty = sqlite3_column_double(stmt, 7)
            let avgCost = sqlite3_column_double(stmt, 8)
            let invested = sqlite3_column_double(stmt, 9)
            let sold = sqlite3_column_double(stmt, 10)
            let dividends = sqlite3_column_double(stmt, 11)
            let tcount = Int(sqlite3_column_int(stmt, 12))
            let firstStr = sqlite3_column_text(stmt, 13).map { String(cString: $0) }
            let lastStr = sqlite3_column_text(stmt, 14).map { String(cString: $0) }
            let firstDate = firstStr.flatMap { DateFormatter.iso8601DateOnly.date(from: $0) }
            let lastDate = lastStr.flatMap { DateFormatter.iso8601DateOnly.date(from: $0) }
            let id = "\(instrumentId)-\(accountId)"
            rows.append(HoldingRow(id: id, portfolioName: portfolioName, instrumentId: instrumentId, instrumentName: instrumentName, accountId: accountId, accountName: accountName, currency: currency, totalQuantity: qty, avgCostChfPerUnit: avgCost, totalInvestedChf: invested, totalSoldChf: sold, totalDividendsChf: dividends, transactionCount: tcount, firstDate: firstDate, lastDate: lastDate))
        }
        return rows
    }
}

