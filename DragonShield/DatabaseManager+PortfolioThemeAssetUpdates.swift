import Foundation
import SQLite3

extension DatabaseManager {
    func ensurePortfolioThemeAssetUpdateTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS PortfolioThemeAssetUpdate (
            id INTEGER PRIMARY KEY,
            theme_id INTEGER NOT NULL REFERENCES PortfolioTheme(id) ON DELETE CASCADE,
            instrument_id INTEGER NOT NULL REFERENCES Instruments(instrument_id) ON DELETE SET NULL,
            title TEXT NOT NULL CHECK (LENGTH(title) BETWEEN 1 AND 120),
            body_text TEXT NOT NULL CHECK (LENGTH(body_text) BETWEEN 1 AND 5000),
            body_markdown TEXT NULL,
            type TEXT NOT NULL CHECK (type IN ('General','Research','Rebalance','Risk')),
            author TEXT NOT NULL,
            positions_asof TEXT NULL,
            value_chf REAL NULL,
            actual_percent REAL NULL,
            pinned INTEGER NOT NULL DEFAULT 0 CHECK (pinned IN (0,1)),
            created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
            updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
        );
        CREATE INDEX IF NOT EXISTS idx_ptau_theme_instr_order ON PortfolioThemeAssetUpdate(theme_id, instrument_id, created_at DESC);
        CREATE INDEX IF NOT EXISTS idx_ptau_theme_instr_pinned_order ON PortfolioThemeAssetUpdate(theme_id, instrument_id, pinned DESC, created_at DESC);
        """
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            LoggingService.shared.log("ensurePortfolioThemeAssetUpdateTable failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
    }

    func listInstrumentUpdates(themeId: Int, instrumentId: Int, pinnedFirst: Bool = true) -> [PortfolioThemeAssetUpdate] {
        var items: [PortfolioThemeAssetUpdate] = []
        let order = pinnedFirst ? "pinned DESC, created_at DESC" : "created_at DESC"
        let sql = "SELECT id, theme_id, instrument_id, title, body_markdown, type, author, positions_asof, value_chf, actual_percent, pinned, created_at, updated_at FROM PortfolioThemeAssetUpdate WHERE theme_id = ? AND instrument_id = ? ORDER BY \(order)"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(themeId))
            sqlite3_bind_int(stmt, 2, Int32(instrumentId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let themeId = Int(sqlite3_column_int(stmt, 1))
                let instrumentId = Int(sqlite3_column_int(stmt, 2))
                let title = String(cString: sqlite3_column_text(stmt, 3))
                let body = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ""
                let typeStr = String(cString: sqlite3_column_text(stmt, 5))
                let author = String(cString: sqlite3_column_text(stmt, 6))
                let positionsAsOf = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
                let value = sqlite3_column_type(stmt, 8) != SQLITE_NULL ? sqlite3_column_double(stmt, 8) : nil
                let actual = sqlite3_column_type(stmt, 9) != SQLITE_NULL ? sqlite3_column_double(stmt, 9) : nil
                let pinned = sqlite3_column_int(stmt, 10) == 1
                let created = String(cString: sqlite3_column_text(stmt, 11))
                let updated = String(cString: sqlite3_column_text(stmt, 12))
                if let type = PortfolioThemeAssetUpdate.UpdateType(rawValue: typeStr) {
                    items.append(PortfolioThemeAssetUpdate(id: id, themeId: themeId, instrumentId: instrumentId, title: title, bodyMarkdown: body, type: type, author: author, positionsAsOf: positionsAsOf, valueChf: value, actualPercent: actual, pinned: pinned, createdAt: created, updatedAt: updated))
                } else {
                    LoggingService.shared.log("Invalid update type '\(typeStr)' for instrument update id \(id). Skipping row.", type: .warning, logger: .database)
                }
            }
        } else {
            LoggingService.shared.log("Failed to prepare listInstrumentUpdates: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return items
    }

    func getInstrumentUpdate(id: Int) -> PortfolioThemeAssetUpdate? {
        let sql = "SELECT id, theme_id, instrument_id, title, body_markdown, type, author, positions_asof, value_chf, actual_percent, pinned, created_at, updated_at FROM PortfolioThemeAssetUpdate WHERE id = ?"
        var stmt: OpaquePointer?
        var item: PortfolioThemeAssetUpdate?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let themeId = Int(sqlite3_column_int(stmt, 1))
                let instrumentId = Int(sqlite3_column_int(stmt, 2))
                let title = String(cString: sqlite3_column_text(stmt, 3))
                let body = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ""
                let typeStr = String(cString: sqlite3_column_text(stmt, 5))
                let author = String(cString: sqlite3_column_text(stmt, 6))
                let positionsAsOf = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
                let value = sqlite3_column_type(stmt, 8) != SQLITE_NULL ? sqlite3_column_double(stmt, 8) : nil
                let actual = sqlite3_column_type(stmt, 9) != SQLITE_NULL ? sqlite3_column_double(stmt, 9) : nil
                let pinned = sqlite3_column_int(stmt, 10) == 1
                let created = String(cString: sqlite3_column_text(stmt, 11))
                let updated = String(cString: sqlite3_column_text(stmt, 12))
                if let type = PortfolioThemeAssetUpdate.UpdateType(rawValue: typeStr) {
                    item = PortfolioThemeAssetUpdate(id: id, themeId: themeId, instrumentId: instrumentId, title: title, bodyMarkdown: body, type: type, author: author, positionsAsOf: positionsAsOf, valueChf: value, actualPercent: actual, pinned: pinned, createdAt: created, updatedAt: updated)
                } else {
                    LoggingService.shared.log("Invalid update type '\(typeStr)' for instrument update id \(id).", type: .warning, logger: .database)
                }
            }
        } else {
            LoggingService.shared.log("Failed to prepare getInstrumentUpdate: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return item
    }

    func createInstrumentUpdate(themeId: Int, instrumentId: Int, title: String, bodyMarkdown: String, type: PortfolioThemeAssetUpdate.UpdateType, pinned: Bool, author: String, breadcrumb: (positionsAsOf: String?, valueChf: Double?, actualPercent: Double?)? = nil, source: String? = nil) -> PortfolioThemeAssetUpdate? {
        guard PortfolioThemeAssetUpdate.isValidTitle(title), PortfolioThemeAssetUpdate.isValidBody(bodyMarkdown) else {
            LoggingService.shared.log("Invalid title/body for instrument update", type: .info, logger: .database)
            return nil
        }
        let sql = "INSERT INTO PortfolioThemeAssetUpdate (theme_id, instrument_id, title, body_markdown, body_text, type, author, positions_asof, value_chf, actual_percent, pinned) VALUES (?,?,?,?,?,?,?,?,?,?,?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare createInstrumentUpdate failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return nil
        }
        sqlite3_bind_int(stmt, 1, Int32(themeId))
        sqlite3_bind_int(stmt, 2, Int32(instrumentId))
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 3, title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, bodyMarkdown, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 5, bodyMarkdown, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 6, type.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 7, author, -1, SQLITE_TRANSIENT)
        if let bc = breadcrumb {
            bc.positionsAsOf.map { sqlite3_bind_text(stmt, 8, $0, -1, SQLITE_TRANSIENT) } ?? sqlite3_bind_null(stmt, 8)
            if let v = bc.valueChf { sqlite3_bind_double(stmt, 9, v) } else { sqlite3_bind_null(stmt, 9) }
            if let a = bc.actualPercent { sqlite3_bind_double(stmt, 10, a) } else { sqlite3_bind_null(stmt, 10) }
        } else {
            sqlite3_bind_null(stmt, 8)
            sqlite3_bind_null(stmt, 9)
            sqlite3_bind_null(stmt, 10)
        }
        sqlite3_bind_int(stmt, 11, pinned ? 1 : 0)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            LoggingService.shared.log("createInstrumentUpdate failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            sqlite3_finalize(stmt)
            return nil
        }
        let id = Int(sqlite3_last_insert_rowid(db))
        sqlite3_finalize(stmt)
        guard let item = getInstrumentUpdate(id: id) else { return nil }
        var payload: [String: Any] = [
            "themeId": themeId,
            "instrumentId": instrumentId,
            "updateId": id,
            "actor": author,
            "op": "create",
            "pinned": pinned,
            "type": type.rawValue,
            "created_at": item.createdAt
        ]
        if let source = source { payload["source"] = source }
        if let data = try? JSONSerialization.data(withJSONObject: payload), let log = String(data: data, encoding: .utf8) {
            LoggingService.shared.log(log, logger: .database)
        }
        return item
    }

    func updateInstrumentUpdate(id: Int, title: String?, bodyMarkdown: String?, type: PortfolioThemeAssetUpdate.UpdateType?, pinned: Bool?, actor: String, expectedUpdatedAt: String, source: String? = nil) -> PortfolioThemeAssetUpdate? {
        var sets: [String] = []
        if let title = title {
            guard PortfolioThemeAssetUpdate.isValidTitle(title) else { return nil }
            sets.append("title = ?")
        }
        if let bodyMarkdown = bodyMarkdown {
            guard PortfolioThemeAssetUpdate.isValidBody(bodyMarkdown) else { return nil }
            sets.append("body_markdown = ?")
            sets.append("body_text = ?")
        }
        if let _ = type {
            sets.append("type = ?")
        }
        if let _ = pinned {
            sets.append("pinned = ?")
        }
        sets.append("updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')")
        let sql = "UPDATE PortfolioThemeAssetUpdate SET \(sets.joined(separator: ", ")) WHERE id = ? AND updated_at = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare updateInstrumentUpdate failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return nil
        }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        var idx: Int32 = 1
        if let title = title {
            sqlite3_bind_text(stmt, idx, title, -1, SQLITE_TRANSIENT); idx += 1
        }
        if let bodyMarkdown = bodyMarkdown {
            sqlite3_bind_text(stmt, idx, bodyMarkdown, -1, SQLITE_TRANSIENT); idx += 1
            sqlite3_bind_text(stmt, idx, bodyMarkdown, -1, SQLITE_TRANSIENT); idx += 1
        }
        if let type = type {
            sqlite3_bind_text(stmt, idx, type.rawValue, -1, SQLITE_TRANSIENT); idx += 1
        }
        if let pinned = pinned {
            sqlite3_bind_int(stmt, idx, pinned ? 1 : 0); idx += 1
        }
        sqlite3_bind_int(stmt, idx, Int32(id)); idx += 1
        sqlite3_bind_text(stmt, idx, expectedUpdatedAt, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            LoggingService.shared.log("updateInstrumentUpdate failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            sqlite3_finalize(stmt)
            return nil
        }
        if sqlite3_changes(db) == 0 {
            LoggingService.shared.log("updateInstrumentUpdate concurrency conflict id=\(id)", type: .info, logger: .database)
            sqlite3_finalize(stmt)
            return nil
        }
        sqlite3_finalize(stmt)
        guard let item = getInstrumentUpdate(id: id) else { return nil }
        var op = "update"
        if let pinned = pinned { op = pinned ? "pin" : "unpin" }
        var payload: [String: Any] = [
            "themeId": item.themeId,
            "instrumentId": item.instrumentId,
            "updateId": id,
            "actor": actor,
            "op": op,
            "pinned": item.pinned,
            "type": item.type.rawValue,
            "updated_at": item.updatedAt
        ]
        if let source = source { payload["source"] = source }
        if let data = try? JSONSerialization.data(withJSONObject: payload), let log = String(data: data, encoding: .utf8) {
            LoggingService.shared.log(log, logger: .database)
        }
        return item
    }

    func deleteInstrumentUpdate(id: Int, actor: String, source: String? = nil) -> Bool {
        var themeId: Int = 0
        var instrumentId: Int = 0
        var pinned: Bool = false
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT theme_id, instrument_id, pinned FROM PortfolioThemeAssetUpdate WHERE id = ?", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW {
                themeId = Int(sqlite3_column_int(stmt, 0))
                instrumentId = Int(sqlite3_column_int(stmt, 1))
                pinned = sqlite3_column_int(stmt, 2) == 1
            }
        }
        sqlite3_finalize(stmt)
        guard themeId != 0 else { return false }
        if sqlite3_prepare_v2(db, "DELETE FROM PortfolioThemeAssetUpdate WHERE id = ?", -1, &stmt, nil) != SQLITE_OK {
            LoggingService.shared.log("prepare deleteInstrumentUpdate failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        sqlite3_bind_int(stmt, 1, Int32(id))
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            LoggingService.shared.log("deleteInstrumentUpdate failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            sqlite3_finalize(stmt)
            return false
        }
        sqlite3_finalize(stmt)
        var payload: [String: Any] = [
            "themeId": themeId,
            "instrumentId": instrumentId,
            "updateId": id,
            "actor": actor,
            "op": "delete",
            "pinned": pinned
        ]
        if let source = source { payload["source"] = source }
        if let data = try? JSONSerialization.data(withJSONObject: payload), let log = String(data: data, encoding: .utf8) {
            LoggingService.shared.log(log, logger: .database)
        }
        return true
    }

    func countInstrumentUpdates(themeId: Int, instrumentId: Int) -> Int {
        let sql = "SELECT COUNT(*) FROM PortfolioThemeAssetUpdate WHERE theme_id = ? AND instrument_id = ?"
        var stmt: OpaquePointer?
        var count = 0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(themeId))
            sqlite3_bind_int(stmt, 2, Int32(instrumentId))
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, 0))
            }
        } else {
            LoggingService.shared.log("Failed to prepare countInstrumentUpdates: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return count
    }
}
