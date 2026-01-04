import Foundation
import OSLog
import SQLite3

extension DatabaseManager {
    @discardableResult
    func upsertWeeklyChecklist(themeId: Int,
                               weekStartDate: Date,
                               status: WeeklyChecklistStatus,
                               answers: WeeklyChecklistAnswers?,
                               skipComment: String?,
                               completedAt: Date?,
                               skippedAt: Date?) -> Bool
    {
        guard let db, tableExists("WeeklyChecklist") else { return false }

        let weekStartStr = DateFormatter.iso8601DateOnly.string(from: weekStartDate)
        let selectSql = "SELECT id, status, revision FROM WeeklyChecklist WHERE theme_id = ? AND week_start_date = ? LIMIT 1"
        var selectStmt: OpaquePointer?
        var existingId: Int?
        var existingStatus: WeeklyChecklistStatus?
        var existingRevision = 0

        if sqlite3_prepare_v2(db, selectSql, -1, &selectStmt, nil) == SQLITE_OK {
            sqlite3_bind_int(selectStmt, 1, Int32(themeId))
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(selectStmt, 2, (weekStartStr as NSString).utf8String, -1, SQLITE_TRANSIENT)
            if sqlite3_step(selectStmt) == SQLITE_ROW {
                existingId = Int(sqlite3_column_int(selectStmt, 0))
                if let statusPtr = sqlite3_column_text(selectStmt, 1) {
                    existingStatus = WeeklyChecklistStatus(rawValue: String(cString: statusPtr))
                }
                existingRevision = Int(sqlite3_column_int(selectStmt, 2))
            }
        }
        sqlite3_finalize(selectStmt)

        let answersJSON = answers?.encodeJSON()
        let completedStr = completedAt.map { DateFormatter.iso8601DateTime.string(from: $0) }
        let skippedStr = skippedAt.map { DateFormatter.iso8601DateTime.string(from: $0) }

        if let existingId {
            let shouldIncrement = existingStatus == .completed
            let newRevision = shouldIncrement ? existingRevision + 1 : existingRevision
            let updateSql = """
                UPDATE WeeklyChecklist
                   SET status = ?,
                       answers_json = ?,
                       completed_at = ?,
                       skipped_at = ?,
                       skip_comment = ?,
                       last_edited_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'),
                       revision = ?
                 WHERE id = ?;
            """
            var updateStmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, updateSql, -1, &updateStmt, nil) == SQLITE_OK else {
                LoggingService.shared.log("upsertWeeklyChecklist update prepare failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
                return false
            }
            defer { sqlite3_finalize(updateStmt) }
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(updateStmt, 1, status.rawValue, -1, SQLITE_TRANSIENT)
            if let json = answersJSON {
                sqlite3_bind_text(updateStmt, 2, json, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(updateStmt, 2)
            }
            if let completedStr {
                sqlite3_bind_text(updateStmt, 3, completedStr, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(updateStmt, 3)
            }
            if let skippedStr {
                sqlite3_bind_text(updateStmt, 4, skippedStr, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(updateStmt, 4)
            }
            if let skipComment, !skipComment.isEmpty {
                sqlite3_bind_text(updateStmt, 5, skipComment, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(updateStmt, 5)
            }
            sqlite3_bind_int(updateStmt, 6, Int32(newRevision))
            sqlite3_bind_int(updateStmt, 7, Int32(existingId))
            let ok = sqlite3_step(updateStmt) == SQLITE_DONE
            if !ok {
                LoggingService.shared.log("upsertWeeklyChecklist update failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            }
            return ok
        }

        let insertSql = """
            INSERT INTO WeeklyChecklist (theme_id, week_start_date, status, answers_json, completed_at, skipped_at, skip_comment, last_edited_at, revision)
            VALUES (?, ?, ?, ?, ?, ?, ?, STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'), 0);
        """
        var insertStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSql, -1, &insertStmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("upsertWeeklyChecklist insert prepare failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        defer { sqlite3_finalize(insertStmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_int(insertStmt, 1, Int32(themeId))
        sqlite3_bind_text(insertStmt, 2, (weekStartStr as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(insertStmt, 3, status.rawValue, -1, SQLITE_TRANSIENT)
        if let json = answersJSON {
            sqlite3_bind_text(insertStmt, 4, json, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(insertStmt, 4)
        }
        if let completedStr {
            sqlite3_bind_text(insertStmt, 5, completedStr, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(insertStmt, 5)
        }
        if let skippedStr {
            sqlite3_bind_text(insertStmt, 6, skippedStr, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(insertStmt, 6)
        }
        if let skipComment, !skipComment.isEmpty {
            sqlite3_bind_text(insertStmt, 7, skipComment, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(insertStmt, 7)
        }
        let ok = sqlite3_step(insertStmt) == SQLITE_DONE
        if !ok {
            LoggingService.shared.log("upsertWeeklyChecklist insert failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        return ok
    }

    func fetchWeeklyChecklist(themeId: Int, weekStartDate: Date) -> WeeklyChecklistEntry? {
        guard let db, tableExists("WeeklyChecklist") else { return nil }
        let weekStartStr = DateFormatter.iso8601DateOnly.string(from: weekStartDate)
        let sql = """
            SELECT id, theme_id, week_start_date, status, answers_json, completed_at, skipped_at, skip_comment, last_edited_at, revision, created_at
              FROM WeeklyChecklist
             WHERE theme_id = ? AND week_start_date = ?
             LIMIT 1;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("fetchWeeklyChecklist prepare failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return nil
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(themeId))
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 2, (weekStartStr as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) == SQLITE_ROW {
            return parseWeeklyChecklistRow(stmt)
        }
        return nil
    }

    func listWeeklyChecklists(themeId: Int, limit: Int? = nil) -> [WeeklyChecklistEntry] {
        guard let db, tableExists("WeeklyChecklist") else { return [] }
        var rows: [WeeklyChecklistEntry] = []
        var sql = """
            SELECT id, theme_id, week_start_date, status, answers_json, completed_at, skipped_at, skip_comment, last_edited_at, revision, created_at
              FROM WeeklyChecklist
             WHERE theme_id = ?
             ORDER BY week_start_date DESC
        """
        if let limit, limit > 0 { sql += " LIMIT ?" }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("listWeeklyChecklists prepare failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return []
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(themeId))
        if let limit, limit > 0 {
            sqlite3_bind_int(stmt, 2, Int32(limit))
        }
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let row = parseWeeklyChecklistRow(stmt) {
                rows.append(row)
            }
        }
        return rows
    }

    func fetchLastWeeklyChecklist(themeId: Int, status: WeeklyChecklistStatus) -> WeeklyChecklistEntry? {
        guard let db, tableExists("WeeklyChecklist") else { return nil }
        let sql = """
            SELECT id, theme_id, week_start_date, status, answers_json, completed_at, skipped_at, skip_comment, last_edited_at, revision, created_at
              FROM WeeklyChecklist
             WHERE theme_id = ? AND status = ?
             ORDER BY week_start_date DESC
             LIMIT 1;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("fetchLastWeeklyChecklist prepare failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return nil
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(themeId))
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 2, status.rawValue, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) == SQLITE_ROW {
            return parseWeeklyChecklistRow(stmt)
        }
        return nil
    }

    private func parseWeeklyChecklistRow(_ stmt: OpaquePointer?) -> WeeklyChecklistEntry? {
        guard let stmt else { return nil }
        let id = Int(sqlite3_column_int(stmt, 0))
        let themeId = Int(sqlite3_column_int(stmt, 1))
        let weekStr = String(cString: sqlite3_column_text(stmt, 2))
        guard let weekStart = DateFormatter.iso8601DateOnly.date(from: weekStr) else { return nil }
        guard let statusPtr = sqlite3_column_text(stmt, 3) else { return nil }
        let status = WeeklyChecklistStatus(rawValue: String(cString: statusPtr)) ?? .draft
        let answersStr = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
        let answers = answersStr.flatMap { WeeklyChecklistAnswers.decode(from: $0) }
        let completedStr = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
        let skippedStr = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
        let skipComment = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
        let lastEditedStr = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
        let revision = Int(sqlite3_column_int(stmt, 9))
        let createdStr = sqlite3_column_text(stmt, 10).map { String(cString: $0) }

        let completedAt = completedStr.flatMap { ISO8601DateParser.parse($0) }
        let skippedAt = skippedStr.flatMap { ISO8601DateParser.parse($0) }
        let lastEditedAt = lastEditedStr.flatMap { ISO8601DateParser.parse($0) } ?? weekStart
        let createdAt = createdStr.flatMap { ISO8601DateParser.parse($0) } ?? weekStart

        return WeeklyChecklistEntry(
            id: id,
            themeId: themeId,
            weekStartDate: weekStart,
            status: status,
            answers: answers,
            completedAt: completedAt,
            skippedAt: skippedAt,
            skipComment: skipComment,
            lastEditedAt: lastEditedAt,
            revision: revision,
            createdAt: createdAt
        )
    }
}
