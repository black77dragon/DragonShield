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
            body_markdown TEXT NOT NULL CHECK (LENGTH(body_markdown) BETWEEN 1 AND 5000),
            type TEXT NOT NULL CHECK (type IN (\(PortfolioUpdateType.allowedSQLList))),
            type_id INTEGER NULL REFERENCES NewsType(id),
            author TEXT NOT NULL,
            pinned INTEGER NOT NULL DEFAULT 0 CHECK (pinned IN (0,1)),
            positions_asof TEXT NULL,
            value_chf REAL NULL,
            actual_percent REAL NULL,
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
        let sql = "SELECT id, theme_id, instrument_id, title, body_markdown, type, author, pinned, positions_asof, value_chf, actual_percent, created_at, updated_at FROM PortfolioThemeAssetUpdate WHERE theme_id = ? AND instrument_id = ? ORDER BY \(order)"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(themeId))
            sqlite3_bind_int(stmt, 2, Int32(instrumentId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let themeId = Int(sqlite3_column_int(stmt, 1))
                let instrumentId = Int(sqlite3_column_int(stmt, 2))
                let title = String(cString: sqlite3_column_text(stmt, 3))
                let body = String(cString: sqlite3_column_text(stmt, 4))
                let typeStr = String(cString: sqlite3_column_text(stmt, 5))
                let author = String(cString: sqlite3_column_text(stmt, 6))
                let pinned = sqlite3_column_int(stmt, 7) == 1
                let positionsAsOf = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
                let value = sqlite3_column_type(stmt, 9) != SQLITE_NULL ? sqlite3_column_double(stmt, 9) : nil
                let actual = sqlite3_column_type(stmt, 10) != SQLITE_NULL ? sqlite3_column_double(stmt, 10) : nil
                let created = String(cString: sqlite3_column_text(stmt, 11))
                let updated = String(cString: sqlite3_column_text(stmt, 12))
                if let type = PortfolioThemeAssetUpdate.UpdateType(rawValue: typeStr) {
                    items.append(PortfolioThemeAssetUpdate(id: id, themeId: themeId, instrumentId: instrumentId, title: title, bodyMarkdown: body, type: type, author: author, pinned: pinned, positionsAsOf: positionsAsOf, valueChf: value, actualPercent: actual, createdAt: created, updatedAt: updated))
                } else {
                    LoggingService.shared.log("Invalid update type '\\(typeStr)' for instrument update id \\(id). Skipping row.", type: .warning, logger: .database)
                }
            }
        } else {
            LoggingService.shared.log("Failed to prepare listInstrumentUpdates: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return items
    }

    func getInstrumentUpdate(id: Int) -> PortfolioThemeAssetUpdate? {
        let sql = "SELECT id, theme_id, instrument_id, title, body_markdown, type, author, pinned, positions_asof, value_chf, actual_percent, created_at, updated_at FROM PortfolioThemeAssetUpdate WHERE id = ?"
        var stmt: OpaquePointer?
        var item: PortfolioThemeAssetUpdate?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let themeId = Int(sqlite3_column_int(stmt, 1))
                let instrumentId = Int(sqlite3_column_int(stmt, 2))
                let title = String(cString: sqlite3_column_text(stmt, 3))
                let body = String(cString: sqlite3_column_text(stmt, 4))
                let typeStr = String(cString: sqlite3_column_text(stmt, 5))
                let author = String(cString: sqlite3_column_text(stmt, 6))
                let pinned = sqlite3_column_int(stmt, 7) == 1
                let positionsAsOf = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
                let value = sqlite3_column_type(stmt, 9) != SQLITE_NULL ? sqlite3_column_double(stmt, 9) : nil
                let actual = sqlite3_column_type(stmt, 10) != SQLITE_NULL ? sqlite3_column_double(stmt, 10) : nil
                let created = String(cString: sqlite3_column_text(stmt, 11))
                let updated = String(cString: sqlite3_column_text(stmt, 12))
                if let type = PortfolioThemeAssetUpdate.UpdateType(rawValue: typeStr) {
                    item = PortfolioThemeAssetUpdate(id: id, themeId: themeId, instrumentId: instrumentId, title: title, bodyMarkdown: body, type: type, author: author, pinned: pinned, positionsAsOf: positionsAsOf, valueChf: value, actualPercent: actual, createdAt: created, updatedAt: updated)
                } else {
                    LoggingService.shared.log("Invalid update type '\\(typeStr)' for instrument update id \\(id).", type: .warning, logger: .database)
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
        let sql = "INSERT INTO PortfolioThemeAssetUpdate (theme_id, instrument_id, title, body_text, body_markdown, type, type_id, author, pinned, positions_asof, value_chf, actual_percent) VALUES (?,?,?,?,?,?,(SELECT id FROM NewsType WHERE code = ?),?,?,?, ?,?)"
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
        // bind for subselect (type code again)
        sqlite3_bind_text(stmt, 7, type.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 8, author, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 9, pinned ? 1 : 0)
        if let bc = breadcrumb {
            if let s = bc.positionsAsOf { sqlite3_bind_text(stmt, 10, s, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 10) }
            if let v = bc.valueChf { sqlite3_bind_double(stmt, 11, v) } else { sqlite3_bind_null(stmt, 11) }
            if let a = bc.actualPercent { sqlite3_bind_double(stmt, 12, a) } else { sqlite3_bind_null(stmt, 12) }
        } else {
            sqlite3_bind_null(stmt, 10); sqlite3_bind_null(stmt, 11); sqlite3_bind_null(stmt, 12)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            LoggingService.shared.log("createInstrumentUpdate failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            sqlite3_finalize(stmt)
            return nil
        }
        let newId = Int(sqlite3_last_insert_rowid(db))
        sqlite3_finalize(stmt)
        guard let item = getInstrumentUpdate(id: newId) else { return nil }
        var payload: [String: Any] = [
            "themeId": themeId,
            "instrumentId": instrumentId,
            "updateId": newId,
            "actor": author,
            "op": "create",
            "pinned": pinned ? 1 : 0,
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
            sets.append("body_text = ?")
            sets.append("body_markdown = ?")
        }
        if let _ = type {
            sets.append("type = ?")
            sets.append("type_id = (SELECT id FROM NewsType WHERE code = ?)")
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
        if let pinned = pinned, title == nil && bodyMarkdown == nil && type == nil {
            op = pinned ? "pin" : "unpin"
        }
        var payload: [String: Any] = [
            "themeId": item.themeId,
            "instrumentId": item.instrumentId,
            "updateId": id,
            "actor": actor,
            "op": op,
            "pinned": item.pinned ? 1 : 0,
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
        var pinned: Int32 = 0
        var updatedAt: String = ""
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT theme_id, instrument_id, pinned, updated_at FROM PortfolioThemeAssetUpdate WHERE id = ?", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW {
                themeId = Int(sqlite3_column_int(stmt, 0))
                instrumentId = Int(sqlite3_column_int(stmt, 1))
                pinned = sqlite3_column_int(stmt, 2)
                updatedAt = String(cString: sqlite3_column_text(stmt, 3))
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
            "pinned": Int(pinned),
            "updated_at": updatedAt
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

    private func normalize(_ text: String) -> String {
        let lowered = text.lowercased()
        let mapped = lowered.map { $0.isLetter || $0.isNumber ? String($0) : " " }.joined()
        let collapsed = mapped.split { $0 == " " }.joined(separator: " ")
        return " " + collapsed + " "
    }

    private func mentionCount(themeId: Int, code: String, name: String) -> Int {
        let sql = "SELECT title, COALESCE(body_markdown, body_text) FROM PortfolioThemeUpdate WHERE theme_id = ? AND soft_delete = 0"
        var stmt: OpaquePointer?
        var count = 0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(themeId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let title = String(cString: sqlite3_column_text(stmt, 0))
                let body = String(cString: sqlite3_column_text(stmt, 1))
                let combined = title + " " + body
                let norm = normalize(combined)
                var matched = false
                if code.count >= 3 {
                    let token = " " + code.lowercased() + " "
                    if norm.contains(token) { matched = true }
                }
                if !matched {
                    let lowerName = name.lowercased()
                    if norm.contains(lowerName) {
                        matched = true
                    } else {
                        let nameTokens = lowerName.split { !$0.isLetter && !$0.isNumber }
                        if !nameTokens.isEmpty && nameTokens.allSatisfy({ norm.contains(" \($0) ") }) {
                            matched = true
                        }
                    }
                }
                if matched { count += 1 }
            }
        } else {
            LoggingService.shared.log("Failed to prepare mentionCount: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return count
    }

    func listThemesForInstrumentWithUpdateCounts(instrumentId: Int, instrumentCode: String, instrumentName: String) -> [(themeId: Int, themeName: String, isArchived: Bool, updatesCount: Int, mentionsCount: Int)] {
        let sql = """
            SELECT t.id, t.name, t.archived_at IS NOT NULL AS archived, COUNT(u.id) AS cnt
            FROM PortfolioThemeAsset a
            JOIN PortfolioTheme t ON a.theme_id = t.id
            LEFT JOIN PortfolioThemeAssetUpdate u
                ON u.theme_id = a.theme_id AND u.instrument_id = a.instrument_id
            WHERE a.instrument_id = ?
            GROUP BY t.id, t.name, t.archived_at
            ORDER BY t.name
        """
        var stmt: OpaquePointer?
        var results: [(Int, String, Bool, Int, Int)] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(instrumentId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let themeId = Int(sqlite3_column_int(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 1))
                let archived = sqlite3_column_int(stmt, 2) == 1
                let count = Int(sqlite3_column_int(stmt, 3))
                let mentions = mentionCount(themeId: themeId, code: instrumentCode, name: instrumentName)
                results.append((themeId, name, archived, count, mentions))
            }
        } else {
            LoggingService.shared.log("Failed to prepare listThemesForInstrumentWithUpdateCounts: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return results
    }
}
