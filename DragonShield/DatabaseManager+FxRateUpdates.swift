import SQLite3
import Foundation

extension DatabaseManager {
    struct FxRateUpdateLog: Identifiable {
        var id: Int
        var updateDate: Date
        var apiProvider: String
        var currenciesUpdated: String?
        var status: String
        var errorMessage: String?
        var ratesCount: Int
        var executionTimeMs: Int?
        var createdAt: Date
    }

    @discardableResult
    func recordFxRateUpdate(updateDate: Date,
                             apiProvider: String,
                             currenciesUpdated: [String],
                             status: String,
                             errorMessage: String?,
                             ratesCount: Int,
                             executionTimeMs: Int?) -> Bool {
        let sql = """
            INSERT INTO FxRateUpdates (update_date, api_provider, currencies_updated, status, error_message, rates_count, execution_time_ms)
            VALUES (?, ?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare recordFxRateUpdate: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        defer { sqlite3_finalize(stmt) }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let dateStr = DateFormatter.iso8601DateOnly.string(from: updateDate)
        sqlite3_bind_text(stmt, 1, (dateStr as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, (apiProvider as NSString).utf8String, -1, SQLITE_TRANSIENT)
        let joined = currenciesUpdated.isEmpty ? nil : currenciesUpdated.joined(separator: ",")
        if let j = joined { sqlite3_bind_text(stmt, 3, (j as NSString).utf8String, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 3) }
        sqlite3_bind_text(stmt, 4, (status as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if let err = errorMessage { sqlite3_bind_text(stmt, 5, (err as NSString).utf8String, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 5) }
        sqlite3_bind_int(stmt, 6, Int32(ratesCount))
        if let ms = executionTimeMs { sqlite3_bind_int(stmt, 7, Int32(ms)) } else { sqlite3_bind_null(stmt, 7) }

        let ok = sqlite3_step(stmt) == SQLITE_DONE
        if !ok { print("❌ recordFxRateUpdate insert failed: \(String(cString: sqlite3_errmsg(db)))") }
        return ok
    }

    func fetchLastFxRateUpdate() -> FxRateUpdateLog? {
        let sql = """
            SELECT update_id, update_date, api_provider, currencies_updated, status, error_message, rates_count, execution_time_ms, created_at
              FROM FxRateUpdates
             ORDER BY created_at DESC
             LIMIT 1;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare fetchLastFxRateUpdate: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(stmt, 0))
            let dateStr = String(cString: sqlite3_column_text(stmt, 1))
            let updDate = DateFormatter.iso8601DateOnly.date(from: dateStr) ?? Date()
            let provider = String(cString: sqlite3_column_text(stmt, 2))
            let currs = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
            let status = String(cString: sqlite3_column_text(stmt, 4))
            let err = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
            let count = Int(sqlite3_column_int(stmt, 6))
            let execMs = sqlite3_column_text(stmt, 7).map { Int(String(cString: $0)) } ?? nil
            let createdStr = String(cString: sqlite3_column_text(stmt, 8))
            let created = DateFormatter.iso8601DateTime.date(from: createdStr) ?? Date()
            return FxRateUpdateLog(id: id, updateDate: updDate, apiProvider: provider, currenciesUpdated: currs, status: status, errorMessage: err, ratesCount: count, executionTimeMs: execMs, createdAt: created)
        }
        return nil
    }
}

