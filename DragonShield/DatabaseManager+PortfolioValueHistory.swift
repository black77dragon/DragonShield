import Foundation
import OSLog
import SQLite3

struct PortfolioValueHistoryRow: Identifiable {
    let valueDate: Date
    let totalValueChf: Double

    var id: Date { valueDate }
}

extension DatabaseManager {
    @discardableResult
    func recordDailyPortfolioValue(valueChf: Double, date: Date = Date()) -> Bool {
        guard let db, tableExists("PortfolioValueHistory") else { return false }

        let sql = """
            INSERT INTO PortfolioValueHistory (value_date, total_value_chf, created_at, updated_at)
            VALUES (?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            ON CONFLICT(value_date)
            DO UPDATE SET total_value_chf = excluded.total_value_chf,
                          updated_at = CURRENT_TIMESTAMP;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("recordDailyPortfolioValue prepare failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        defer { sqlite3_finalize(stmt) }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let dateStr = DateFormatter.iso8601DateOnly.string(from: date)
        sqlite3_bind_text(stmt, 1, (dateStr as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 2, valueChf)

        let ok = sqlite3_step(stmt) == SQLITE_DONE
        if !ok {
            LoggingService.shared.log("recordDailyPortfolioValue step failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        return ok
    }

    func listPortfolioValueHistory(limit: Int? = nil) -> [PortfolioValueHistoryRow] {
        guard let db, tableExists("PortfolioValueHistory") else { return [] }

        var rows: [PortfolioValueHistoryRow] = []
        var sql = "SELECT value_date, total_value_chf FROM PortfolioValueHistory ORDER BY value_date ASC"
        if let limit, limit > 0 { sql += " LIMIT ?" }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("listPortfolioValueHistory prepare failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return []
        }
        defer { sqlite3_finalize(stmt) }

        if let limit, limit > 0 {
            sqlite3_bind_int(stmt, 1, Int32(limit))
        }

        while sqlite3_step(stmt) == SQLITE_ROW {
            let dateStr = String(cString: sqlite3_column_text(stmt, 0))
            let totalValue = sqlite3_column_double(stmt, 1)
            guard let date = DateFormatter.iso8601DateOnly.date(from: dateStr) else { continue }
            rows.append(PortfolioValueHistoryRow(valueDate: date, totalValueChf: totalValue))
        }
        return rows
    }

    @discardableResult
    func deletePortfolioValueHistory(on date: Date) -> Bool {
        guard let db, tableExists("PortfolioValueHistory") else { return false }

        let sql = "DELETE FROM PortfolioValueHistory WHERE value_date = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("deletePortfolioValueHistory prepare failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        defer { sqlite3_finalize(stmt) }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let dateStr = DateFormatter.iso8601DateOnly.string(from: date)
        sqlite3_bind_text(stmt, 1, (dateStr as NSString).utf8String, -1, SQLITE_TRANSIENT)

        let ok = sqlite3_step(stmt) == SQLITE_DONE
        if !ok {
            LoggingService.shared.log("deletePortfolioValueHistory step failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        return ok
    }
}
