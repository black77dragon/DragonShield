import Foundation
import SQLite3

extension DatabaseManager {
    func ensurePortfolioThemeAssetUpdateTable() {
        ensureInstrumentNoteTable()
        migrateLegacyInstrumentUpdates()
    }

    private func singleIntQuery(_ sql: String, bind: ((OpaquePointer) -> Void)? = nil) -> Int? {
        guard let db else { return nil }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("singleIntQuery prepare failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return nil
        }
        bind?(stmt!)
        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }
        return nil
    }

    private func ensureInstrumentNoteTable() {
        let createSQL = """
        CREATE TABLE IF NOT EXISTS InstrumentNote (
            id INTEGER PRIMARY KEY,
            instrument_id INTEGER NOT NULL REFERENCES Instruments(instrument_id) ON DELETE SET NULL,
            theme_id INTEGER NULL REFERENCES PortfolioTheme(id) ON DELETE CASCADE,
            title TEXT NOT NULL CHECK (LENGTH(title) BETWEEN 1 AND 120),
            body_text TEXT NOT NULL CHECK (LENGTH(body_text) BETWEEN 1 AND 5000),
            body_markdown TEXT NOT NULL CHECK (LENGTH(body_markdown) BETWEEN 1 AND 5000),
            type TEXT NOT NULL DEFAULT 'General' CHECK (type IN (\(PortfolioUpdateType.allowedSQLList))),
            type_id INTEGER NULL REFERENCES NewsType(id),
            author TEXT NOT NULL,
            pinned INTEGER NOT NULL DEFAULT 0 CHECK (pinned IN (0,1)),
            positions_asof TEXT NULL,
            value_chf REAL NULL,
            actual_percent REAL NULL,
            created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
            updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
        );
        CREATE INDEX IF NOT EXISTS idx_instrument_note_instrument_order ON InstrumentNote(instrument_id, created_at DESC);
        CREATE INDEX IF NOT EXISTS idx_instrument_note_theme ON InstrumentNote(theme_id, created_at DESC);
        CREATE INDEX IF NOT EXISTS idx_instrument_note_pinned ON InstrumentNote(pinned, created_at DESC);
        """
        if sqlite3_exec(db, createSQL, nil, nil, nil) != SQLITE_OK {
            LoggingService.shared.log("ensureInstrumentNoteTable failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }

        var addedThemeColumn = false
        if !tableHasColumn("InstrumentNote", column: "theme_id") {
            if sqlite3_exec(db, "ALTER TABLE InstrumentNote ADD COLUMN theme_id INTEGER NULL REFERENCES PortfolioTheme(id) ON DELETE CASCADE;", nil, nil, nil) != SQLITE_OK {
                LoggingService.shared.log("ALTER InstrumentNote add theme_id failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            } else {
                addedThemeColumn = true
                _ = sqlite3_exec(db, "CREATE INDEX IF NOT EXISTS idx_instrument_note_theme ON InstrumentNote(theme_id, created_at DESC);", nil, nil, nil)
                let inferSQL = """
                    -- Backfill legacy rows that predate the theme_id column; run only during migration.
                    UPDATE InstrumentNote
                    SET theme_id = (
                        SELECT a.theme_id FROM PortfolioThemeAsset a
                        WHERE a.instrument_id = InstrumentNote.instrument_id
                    )
                    WHERE theme_id IS NULL AND (
                        SELECT COUNT(*) FROM PortfolioThemeAsset WHERE instrument_id = InstrumentNote.instrument_id
                    ) = 1
                """
                if sqlite3_exec(db, inferSQL, nil, nil, nil) != SQLITE_OK {
                    LoggingService.shared.log("InstrumentNote theme inference failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
                }
            }
        }

        if !addedThemeColumn {
            _ = sqlite3_exec(db, "CREATE INDEX IF NOT EXISTS idx_instrument_note_theme ON InstrumentNote(theme_id, created_at DESC);", nil, nil, nil)
        }

        if tableExistsSafe("InstrumentNoteContext") {
            if sqlite3_exec(db, "DROP TABLE IF EXISTS InstrumentNoteContext;", nil, nil, nil) != SQLITE_OK {
                LoggingService.shared.log("drop InstrumentNoteContext failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            }
        }
    }

    private func migrateLegacyInstrumentUpdates() {
        guard tableExistsSafe("PortfolioThemeAssetUpdate"),
              tableExistsSafe("InstrumentNote"),
              singleIntQuery("SELECT COUNT(*) FROM InstrumentNote") == 0 else { return }

        LoggingService.shared.log("Migrating legacy PortfolioThemeAssetUpdate records into InstrumentNote", logger: .database)
        let hasTypeColumn = tableHasColumn("PortfolioThemeAssetUpdate", column: "type")
        let hasBodyMarkdown = tableHasColumn("PortfolioThemeAssetUpdate", column: "body_markdown")
        let copySQL: String
        if hasTypeColumn, hasBodyMarkdown {
            copySQL = "INSERT INTO InstrumentNote (id, instrument_id, theme_id, title, body_text, body_markdown, type, type_id, author, pinned, positions_asof, value_chf, actual_percent, created_at, updated_at) SELECT id, instrument_id, theme_id, title, body_text, body_markdown, type, type_id, author, pinned, positions_asof, value_chf, actual_percent, created_at, updated_at FROM PortfolioThemeAssetUpdate"
        } else if hasBodyMarkdown {
            copySQL = "INSERT INTO InstrumentNote (id, instrument_id, theme_id, title, body_text, body_markdown, author, pinned, positions_asof, value_chf, actual_percent, created_at, updated_at) SELECT id, instrument_id, NULL, title, body_text, body_markdown, author, pinned, positions_asof, value_chf, actual_percent, created_at, updated_at FROM PortfolioThemeAssetUpdate"
        } else {
            copySQL = "INSERT INTO InstrumentNote (id, instrument_id, theme_id, title, body_text, body_markdown, author, pinned, positions_asof, value_chf, actual_percent, created_at, updated_at) SELECT id, instrument_id, NULL, title, body_text, body_text, author, pinned, positions_asof, value_chf, actual_percent, created_at, updated_at FROM PortfolioThemeAssetUpdate"
        }
        if sqlite3_exec(db, copySQL, nil, nil, nil) != SQLITE_OK {
            LoggingService.shared.log("Legacy migration copy failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        let updateThemeSQL = "UPDATE InstrumentNote SET theme_id = (SELECT theme_id FROM PortfolioThemeAssetUpdate WHERE PortfolioThemeAssetUpdate.id = InstrumentNote.id) WHERE theme_id IS NULL"
        if sqlite3_exec(db, updateThemeSQL, nil, nil, nil) != SQLITE_OK {
            LoggingService.shared.log("Legacy migration theme assignment failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
    }

    private func fetchInstrumentNotes(sql: String, bind: (OpaquePointer) -> Void) -> [InstrumentNote] {
        guard let db else { return [] }
        var stmt: OpaquePointer?
        var notes: [InstrumentNote] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            bind(stmt!)
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let instrumentId = Int(sqlite3_column_int(stmt, 1))
                let themeId = sqlite3_column_type(stmt, 2) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 2))
                let title = String(cString: sqlite3_column_text(stmt, 3))
                let body = String(cString: sqlite3_column_text(stmt, 4))
                let typeId = sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 5))
                let typeCode = sqlite3_column_text(stmt, 6).map { String(cString: $0) } ?? "General"
                let typeName = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
                let author = String(cString: sqlite3_column_text(stmt, 8))
                let pinned = sqlite3_column_int(stmt, 9) == 1
                let positionsAsOf = sqlite3_column_text(stmt, 10).map { String(cString: $0) }
                let value = sqlite3_column_type(stmt, 11) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 11)
                let actual = sqlite3_column_type(stmt, 12) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 12)
                let created = String(cString: sqlite3_column_text(stmt, 13))
                let updated = String(cString: sqlite3_column_text(stmt, 14))
                let note = InstrumentNote(id: id, instrumentId: instrumentId, themeId: themeId, title: title, bodyMarkdown: body, typeId: typeId, typeCode: typeCode, typeDisplayName: typeName, author: author, pinned: pinned, positionsAsOf: positionsAsOf, valueChf: value, actualPercent: actual, createdAt: created, updatedAt: updated)
                notes.append(note)
            }
        } else {
            LoggingService.shared.log("fetchInstrumentNotes prepare failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return notes
    }

    func listInstrumentUpdates(themeId: Int, instrumentId: Int, pinnedFirst: Bool = true) -> [InstrumentNote] {
        let order = pinnedFirst ? "n.pinned DESC, n.created_at DESC" : "n.created_at DESC"
        let sql = """
            SELECT n.id, n.instrument_id, n.theme_id, n.title, n.body_markdown, n.type_id, nt.code, nt.display_name, n.author, n.pinned, n.positions_asof, n.value_chf, n.actual_percent, n.created_at, n.updated_at
            FROM InstrumentNote n
            LEFT JOIN NewsType nt ON nt.id = n.type_id
            WHERE n.theme_id = ? AND n.instrument_id = ?
            ORDER BY \(order)
        """
        return fetchInstrumentNotes(sql: sql) { stmt in
            sqlite3_bind_int(stmt, 1, Int32(themeId))
            sqlite3_bind_int(stmt, 2, Int32(instrumentId))
        }
    }

    func getInstrumentUpdate(id: Int) -> InstrumentNote? {
        let sql = """
            SELECT n.id, n.instrument_id, n.theme_id, n.title, n.body_markdown, n.type_id, nt.code, nt.display_name, n.author, n.pinned, n.positions_asof, n.value_chf, n.actual_percent, n.created_at, n.updated_at
            FROM InstrumentNote n
            LEFT JOIN NewsType nt ON nt.id = n.type_id
            WHERE n.id = ?
        """
        return fetchInstrumentNotes(sql: sql) { stmt in
            sqlite3_bind_int(stmt, 1, Int32(id))
        }.first
    }

    func createInstrumentUpdate(themeId: Int, instrumentId: Int, title: String, bodyMarkdown: String, newsTypeCode: String, pinned: Bool, author: String, breadcrumb: (positionsAsOf: String?, valueChf: Double?, actualPercent: Double?)? = nil, source: String? = nil) -> InstrumentNote? {
        guard InstrumentNote.isValidTitle(title), InstrumentNote.isValidBody(bodyMarkdown) else {
            LoggingService.shared.log("Invalid title/body for instrument update", type: .info, logger: .database)
            return nil
        }
        let sql = """
            INSERT INTO InstrumentNote (instrument_id, theme_id, title, body_text, body_markdown, type, type_id, author, pinned, positions_asof, value_chf, actual_percent)
            VALUES (?, ?, ?, ?, ?, ?, (SELECT id FROM NewsType WHERE code = ?), ?, ?, ?, ?, ?)
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare createInstrumentUpdate failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return nil
        }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_int(stmt, 1, Int32(instrumentId))
        sqlite3_bind_int(stmt, 2, Int32(themeId))
        sqlite3_bind_text(stmt, 3, title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, bodyMarkdown, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 5, bodyMarkdown, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 6, newsTypeCode, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 7, newsTypeCode, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 8, author, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 9, pinned ? 1 : 0)
        if let bc = breadcrumb {
            if let pos = bc.positionsAsOf {
                sqlite3_bind_text(stmt, 10, pos, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 10)
            }
            if let value = bc.valueChf {
                sqlite3_bind_double(stmt, 11, value)
            } else {
                sqlite3_bind_null(stmt, 11)
            }
            if let actual = bc.actualPercent {
                sqlite3_bind_double(stmt, 12, actual)
            } else {
                sqlite3_bind_null(stmt, 12)
            }
        } else {
            sqlite3_bind_null(stmt, 10)
            sqlite3_bind_null(stmt, 11)
            sqlite3_bind_null(stmt, 12)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            LoggingService.shared.log("createInstrumentUpdate insert failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            sqlite3_finalize(stmt)
            return nil
        }
        sqlite3_finalize(stmt)
        let newId = Int(sqlite3_last_insert_rowid(db))
        guard let item = getInstrumentUpdate(id: newId) else { return nil }
        var payload: [String: Any] = [
            "themeId": themeId,
            "instrumentId": instrumentId,
            "updateId": newId,
            "actor": author,
            "op": "create",
            "pinned": pinned ? 1 : 0,
            "created_at": item.createdAt,
        ]
        if let source = source { payload["source"] = source }
        if let data = try? JSONSerialization.data(withJSONObject: payload), let log = String(data: data, encoding: .utf8) {
            LoggingService.shared.log(log, logger: .database)
        }
        return item
    }

    func updateInstrumentUpdate(id: Int, title: String?, bodyMarkdown: String?, newsTypeCode: String?, pinned: Bool?, actor: String, expectedUpdatedAt: String, source: String? = nil) -> InstrumentNote? {
        var sets: [String] = []
        if let title = title {
            guard InstrumentNote.isValidTitle(title) else { return nil }
            sets.append("title = ?")
        }
        if let bodyMarkdown = bodyMarkdown {
            guard InstrumentNote.isValidBody(bodyMarkdown) else { return nil }
            sets.append("body_text = ?")
            sets.append("body_markdown = ?")
        }
        if let _ = newsTypeCode {
            sets.append("type = ?")
            sets.append("type_id = (SELECT id FROM NewsType WHERE code = ?)")
        }
        if let _ = pinned {
            sets.append("pinned = ?")
        }
        sets.append("updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')")
        let sql = "UPDATE InstrumentNote SET \(sets.joined(separator: ", ")) WHERE id = ? AND updated_at = ?"
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
        if let code = newsTypeCode {
            sqlite3_bind_text(stmt, idx, code, -1, SQLITE_TRANSIENT); idx += 1
            sqlite3_bind_text(stmt, idx, code, -1, SQLITE_TRANSIENT); idx += 1
        }
        if let pin = pinned {
            sqlite3_bind_int(stmt, idx, pin ? 1 : 0); idx += 1
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
        if let pinned = pinned, title == nil, bodyMarkdown == nil, newsTypeCode == nil {
            op = pinned ? "pin" : "unpin"
        }
        var payload: [String: Any] = [
            "themeId": item.themeId ?? -1,
            "instrumentId": item.instrumentId,
            "updateId": id,
            "actor": actor,
            "op": op,
            "pinned": item.pinned ? 1 : 0,
            "updated_at": item.updatedAt,
        ]
        if let source = source { payload["source"] = source }
        if let data = try? JSONSerialization.data(withJSONObject: payload), let log = String(data: data, encoding: .utf8) {
            LoggingService.shared.log(log, logger: .database)
        }
        return item
    }

    func deleteInstrumentUpdate(id: Int, actor: String, source: String? = nil) -> Bool {
        guard let item = getInstrumentUpdate(id: id) else { return false }
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "DELETE FROM InstrumentNote WHERE id = ?", -1, &stmt, nil) != SQLITE_OK {
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
            "themeId": item.themeId ?? -1,
            "instrumentId": item.instrumentId,
            "updateId": id,
            "actor": actor,
            "op": "delete",
            "pinned": item.pinned ? 1 : 0,
            "updated_at": item.updatedAt,
        ]
        if let source = source { payload["source"] = source }
        if let data = try? JSONSerialization.data(withJSONObject: payload), let log = String(data: data, encoding: .utf8) {
            LoggingService.shared.log(log, logger: .database)
        }
        return true
    }

    func countInstrumentUpdates(themeId: Int, instrumentId: Int) -> Int {
        let sql = "SELECT COUNT(*) FROM InstrumentNote WHERE theme_id = ? AND instrument_id = ?"
        return singleIntQuery(sql) { stmt in
            sqlite3_bind_int(stmt, 1, Int32(themeId))
            sqlite3_bind_int(stmt, 2, Int32(instrumentId))
        } ?? 0
    }

    private func normalizeForMentions(_ text: String) -> String {
        let lowered = text.lowercased()
        let mapped = lowered.map { $0.isLetter || $0.isNumber ? String($0) : " " }.joined()
        let collapsed = mapped.split { $0 == " " }.joined(separator: " ")
        return " " + collapsed + " "
    }

    private func mentionCount(themeId: Int, code: String, name: String) -> Int {
        guard let db else { return 0 }
        let sql = "SELECT title, COALESCE(body_markdown, body_text) FROM PortfolioThemeUpdate WHERE theme_id = ? AND soft_delete = 0"
        var stmt: OpaquePointer?
        var count = 0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(themeId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let title = String(cString: sqlite3_column_text(stmt, 0))
                let body = String(cString: sqlite3_column_text(stmt, 1))
                let combined = title + " " + body
                let norm = normalizeForMentions(combined)
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
            LoggingService.shared.log("mentionCount prepare failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return count
    }

    func listThemesForInstrumentWithUpdateCounts(instrumentId: Int, instrumentCode: String, instrumentName: String) -> [(themeId: Int, themeName: String, isArchived: Bool, updatesCount: Int, mentionsCount: Int)] {
        let sql = """
            SELECT t.id, t.name, t.archived_at IS NOT NULL AS archived, COUNT(n.id) AS cnt
            FROM PortfolioThemeAsset a
            JOIN PortfolioTheme t ON a.theme_id = t.id
            LEFT JOIN InstrumentNote n
                ON n.theme_id = a.theme_id AND n.instrument_id = a.instrument_id
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
            LoggingService.shared.log("listThemesForInstrumentWithUpdateCounts failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return results
    }

    private func tableExistsSafe(_ name: String) -> Bool {
        #if os(iOS)
            return tableExistsIOS(name)
        #else
            return tableExists(name)
        #endif
    }
}

extension DatabaseManager {
    func listAllInstrumentUpdates(pinnedFirst: Bool = true, searchQuery: String? = nil, typeId: Int? = nil) -> [InstrumentNote] {
        var clauses: [String] = []
        if typeId != nil { clauses.append("n.type_id = ?") }
        if let q = searchQuery, !q.isEmpty {
            clauses.append("(LOWER(n.title) LIKE '%' || LOWER(?) || '%' OR LOWER(n.body_markdown) LIKE '%' || LOWER(?) || '%')")
        }
        let whereClause = clauses.isEmpty ? "1=1" : clauses.joined(separator: " AND ")
        let order = pinnedFirst ? "n.pinned DESC, n.created_at DESC" : "n.created_at DESC"
        let sql = """
            SELECT n.id, n.instrument_id, n.theme_id, n.title, n.body_markdown, n.type_id, nt.code, nt.display_name, n.author, n.pinned, n.positions_asof, n.value_chf, n.actual_percent, n.created_at, n.updated_at
            FROM InstrumentNote n
            LEFT JOIN NewsType nt ON nt.id = n.type_id
            WHERE \(whereClause)
            ORDER BY \(order)
        """
        return fetchInstrumentNotes(sql: sql) { stmt in
            var idx: Int32 = 1
            if let tid = typeId {
                sqlite3_bind_int(stmt, idx, Int32(tid)); idx += 1
            }
            if let q = searchQuery, !q.isEmpty {
                let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                sqlite3_bind_text(stmt, idx, q, -1, SQLITE_TRANSIENT); idx += 1
                sqlite3_bind_text(stmt, idx, q, -1, SQLITE_TRANSIENT); idx += 1
            }
        }
    }
}
