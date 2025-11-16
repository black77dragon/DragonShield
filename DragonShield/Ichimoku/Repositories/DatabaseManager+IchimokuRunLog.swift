import Foundation
import SQLite3

private let SQLITE_TRANSIENT_RUNLOG = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

extension DatabaseManager {
    func ichimokuStartRunLog(startedAt: Date = Date()) -> Int? {
        let sql = "INSERT INTO ichimoku_run_log (started_at, status) VALUES (?, 'IN_PROGRESS')"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("❌ ichimokuStartRunLog prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        defer { sqlite3_finalize(statement) }
        let startStr = DateFormatter.iso8601DateTime.string(from: startedAt)
        sqlite3_bind_text(statement, 1, (startStr as NSString).utf8String, -1, SQLITE_TRANSIENT_RUNLOG)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            print("❌ ichimokuStartRunLog insert failed: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        return Int(sqlite3_last_insert_rowid(db))
    }

    func ichimokuCompleteRunLog(runId: Int,
                                status: IchimokuRunStatus,
                                message: String?,
                                ticksProcessed: Int,
                                candidatesFound: Int,
                                alertsTriggered: Int,
                                completedAt: Date = Date()) -> Bool
    {
        let sql = """
            UPDATE ichimoku_run_log
               SET status = ?,
                   message = ?,
                   ticks_processed = ?,
                   candidates_found = ?,
                   alerts_triggered = ?,
                   completed_at = ?,
                   updated_at = CURRENT_TIMESTAMP
             WHERE run_id = ?;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("❌ ichimokuCompleteRunLog prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, (status.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT_RUNLOG)
        if let message {
            sqlite3_bind_text(statement, 2, (message as NSString).utf8String, -1, SQLITE_TRANSIENT_RUNLOG)
        } else {
            sqlite3_bind_null(statement, 2)
        }
        sqlite3_bind_int(statement, 3, Int32(ticksProcessed))
        sqlite3_bind_int(statement, 4, Int32(candidatesFound))
        sqlite3_bind_int(statement, 5, Int32(alertsTriggered))
        let completedStr = DateFormatter.iso8601DateTime.string(from: completedAt)
        sqlite3_bind_text(statement, 6, (completedStr as NSString).utf8String, -1, SQLITE_TRANSIENT_RUNLOG)
        sqlite3_bind_int(statement, 7, Int32(runId))
        let ok = sqlite3_step(statement) == SQLITE_DONE
        if !ok {
            print("❌ ichimokuCompleteRunLog update failed: \(String(cString: sqlite3_errmsg(db)))")
        }
        return ok
    }

    func ichimokuFetchRunLogs(limit: Int = 20) -> [IchimokuRunLogRow] {
        let sql = """
            SELECT run_id, started_at, completed_at, status, message, ticks_processed, candidates_found, alerts_triggered
              FROM ichimoku_run_log
             ORDER BY datetime(started_at) DESC
             LIMIT ?;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("❌ ichimokuFetchRunLogs prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return []
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(limit))
        var rows: [IchimokuRunLogRow] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let runId = Int(sqlite3_column_int(statement, 0))
            guard let startedPtr = sqlite3_column_text(statement, 1),
                  let startedAt = DateFormatter.iso8601DateTime.date(from: String(cString: startedPtr)) else { continue }
            let completedAt = sqlite3_column_text(statement, 2).flatMap { DateFormatter.iso8601DateTime.date(from: String(cString: $0)) }
            guard let statusPtr = sqlite3_column_text(statement, 3),
                  let status = IchimokuRunStatus(rawValue: String(cString: statusPtr)) else { continue }
            let message = sqlite3_column_text(statement, 4).map { String(cString: $0) }
            let ticksProcessed = Int(sqlite3_column_int(statement, 5))
            let candidatesFound = Int(sqlite3_column_int(statement, 6))
            let alertsTriggered = Int(sqlite3_column_int(statement, 7))
            rows.append(IchimokuRunLogRow(id: runId,
                                          startedAt: startedAt,
                                          completedAt: completedAt,
                                          status: status,
                                          message: message,
                                          ticksProcessed: ticksProcessed,
                                          candidatesFound: candidatesFound,
                                          alertsTriggered: alertsTriggered))
        }
        return rows
    }
}
