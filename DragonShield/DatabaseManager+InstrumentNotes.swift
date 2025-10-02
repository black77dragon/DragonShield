import Foundation
import SQLite3

extension DatabaseManager {
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

    private func normalizeNotesText(_ text: String) -> String {
        let lowered = text.lowercased()
        let mapped = lowered.map { $0.isLetter || $0.isNumber ? String($0) : " " }.joined()
        let collapsed = mapped.split { $0 == " " }.joined(separator: " ")
        return " " + collapsed + " "
    }

    /// Returns instrument notes that are scoped to portfolio themes. When `themeId` is nil the
    /// result aggregates notes across all themes the instrument participates in.
    func listInstrumentUpdatesForInstrument(instrumentId: Int, themeId: Int? = nil, pinnedFirst: Bool = true) -> [InstrumentNote] {
        let order = pinnedFirst ? "n.pinned DESC, n.created_at DESC" : "n.created_at DESC"
        var clauses: [String] = ["n.instrument_id = ?", "n.theme_id IS NOT NULL"]
        if themeId != nil { clauses.append("n.theme_id = ?") }
        let whereClause = clauses.joined(separator: " AND ")
        let sql = """
            SELECT n.id, n.instrument_id, n.theme_id, n.title, n.body_markdown, n.type_id, nt.code, nt.display_name,
                   n.author, n.pinned, n.positions_asof, n.value_chf, n.actual_percent, n.created_at, n.updated_at
            FROM InstrumentNote n
            LEFT JOIN NewsType nt ON nt.id = n.type_id
            WHERE \(whereClause)
            ORDER BY \(order)
        """
        return fetchInstrumentNotes(sql: sql) { stmt in
            sqlite3_bind_int(stmt, 1, Int32(instrumentId))
            if let themeId {
                sqlite3_bind_int(stmt, 2, Int32(themeId))
            }
        }
    }

    /// Returns instrument notes that are not linked to any portfolio theme.
    func listInstrumentGeneralNotes(instrumentId: Int, pinnedFirst: Bool = true) -> [InstrumentNote] {
        let order = pinnedFirst ? "n.pinned DESC, n.created_at DESC" : "n.created_at DESC"
        let sql = """
            SELECT n.id, n.instrument_id, n.theme_id, n.title, n.body_markdown, n.type_id, nt.code, nt.display_name,
                   n.author, n.pinned, n.positions_asof, n.value_chf, n.actual_percent, n.created_at, n.updated_at
            FROM InstrumentNote n
            LEFT JOIN NewsType nt ON nt.id = n.type_id
            WHERE n.instrument_id = ? AND n.theme_id IS NULL
            ORDER BY \(order)
        """
        return fetchInstrumentNotes(sql: sql) { stmt in
            sqlite3_bind_int(stmt, 1, Int32(instrumentId))
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

    func createInstrumentNote(instrumentId: Int, title: String, bodyMarkdown: String, newsTypeCode: String? = nil, pinned: Bool, author: String, source: String? = nil) -> InstrumentNote? {
        let typeCode = newsTypeCode ?? PortfolioUpdateType.General.rawValue
        guard InstrumentNote.isValidTitle(title), InstrumentNote.isValidBody(bodyMarkdown) else { return nil }
        let sql = """
            INSERT INTO InstrumentNote (instrument_id, theme_id, title, body_text, body_markdown, type, type_id, author, pinned)
            VALUES (?, NULL, ?, ?, ?, ?, (SELECT id FROM NewsType WHERE code = ?), ?, ?)
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare createInstrumentNote failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return nil
        }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_int(stmt, 1, Int32(instrumentId))
        sqlite3_bind_text(stmt, 2, title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, bodyMarkdown, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, bodyMarkdown, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 5, typeCode, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 6, typeCode, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 7, author, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 8, pinned ? 1 : 0)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            LoggingService.shared.log("createInstrumentNote insert failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            sqlite3_finalize(stmt)
            return nil
        }
        sqlite3_finalize(stmt)
        let newId = Int(sqlite3_last_insert_rowid(db))
        guard let item = getInstrumentUpdate(id: newId) else { return nil }
        var payload: [String: Any] = [
            "instrumentId": instrumentId,
            "noteId": newId,
            "actor": author,
            "op": "create",
            "pinned": pinned ? 1 : 0
        ]
        if let source = source { payload["source"] = source }
        if let data = try? JSONSerialization.data(withJSONObject: payload), let log = String(data: data, encoding: .utf8) {
            LoggingService.shared.log(log, logger: .database)
        }
        return item
    }

    func createInstrumentNote(instrumentId: Int, title: String, bodyMarkdown: String, type: PortfolioUpdateType, pinned: Bool, author: String, source: String? = nil) -> InstrumentNote? {
        createInstrumentNote(instrumentId: instrumentId, title: title, bodyMarkdown: bodyMarkdown, newsTypeCode: type.rawValue, pinned: pinned, author: author, source: source)
    }

    func listThemeMentions(themeId: Int, instrumentCode: String, instrumentName: String) -> [PortfolioThemeUpdate] {
        let sql = "SELECT u.id, u.theme_id, u.title, COALESCE(u.body_markdown, u.body_text), u.type_id, n.code, n.display_name, u.author, u.pinned, u.positions_asof, u.total_value_chf, u.created_at, u.updated_at, u.soft_delete, u.deleted_at, u.deleted_by FROM PortfolioThemeUpdate u LEFT JOIN NewsType n ON n.id = u.type_id WHERE u.theme_id = ? AND u.soft_delete = 0 ORDER BY u.created_at DESC"
        var stmt: OpaquePointer?
        var items: [PortfolioThemeUpdate] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(themeId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let themeId = Int(sqlite3_column_int(stmt, 1))
                let title = String(cString: sqlite3_column_text(stmt, 2))
                let body = String(cString: sqlite3_column_text(stmt, 3))
                let typeId = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 4))
                let typeStr = sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? ""
                let typeName = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
                let author = String(cString: sqlite3_column_text(stmt, 7))
                let pinned = sqlite3_column_int(stmt, 8) == 1
                let positionsAsOf = sqlite3_column_text(stmt, 9).map { String(cString: $0) }
                let totalValue = sqlite3_column_type(stmt, 10) != SQLITE_NULL ? sqlite3_column_double(stmt, 10) : nil
                let created = String(cString: sqlite3_column_text(stmt, 11))
                let updated = String(cString: sqlite3_column_text(stmt, 12))
                let softDelete = sqlite3_column_int(stmt, 13) == 1
                let deletedAt = sqlite3_column_text(stmt, 14).map { String(cString: $0) }
                let deletedBy = sqlite3_column_text(stmt, 15).map { String(cString: $0) }
                let combined = title + " " + body
                let norm = normalizeNotesText(combined)
                var matched = false
                if instrumentCode.count >= 3 {
                    let token = " " + instrumentCode.lowercased() + " "
                    if norm.contains(token) { matched = true }
                }
                if !matched {
                    let lowerName = instrumentName.lowercased()
                    if norm.contains(lowerName) {
                        matched = true
                    } else {
                        let nameTokens = lowerName.split { !$0.isLetter && !$0.isNumber }
                        if !nameTokens.isEmpty && nameTokens.allSatisfy({ norm.contains(" \($0) ") }) {
                            matched = true
                        }
                    }
                }
                if matched {
                    items.append(PortfolioThemeUpdate(id: id, themeId: themeId, title: title, bodyMarkdown: body, typeId: typeId, typeCode: typeStr, typeDisplayName: typeName, author: author, pinned: pinned, positionsAsOf: positionsAsOf, totalValueChf: totalValue, createdAt: created, updatedAt: updated, softDelete: softDelete, deletedAt: deletedAt, deletedBy: deletedBy))
                }
            }
        } else {
            LoggingService.shared.log("Failed to prepare listThemeMentions: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return items
    }

    func instrumentNotesSummary(instrumentId: Int, instrumentCode: String, instrumentName: String) -> (updates: Int, mentions: Int) {
        let updates = singleIntQuery("SELECT COUNT(*) FROM InstrumentNote WHERE instrument_id = ? AND theme_id IS NOT NULL") { stmt in
            sqlite3_bind_int(stmt, 1, Int32(instrumentId))
        } ?? 0
        let themes = listThemesForInstrumentWithUpdateCounts(instrumentId: instrumentId, instrumentCode: instrumentCode, instrumentName: instrumentName)
        let mentions = themes.reduce(0) { $0 + $1.mentionsCount }
        return (updates, mentions)
    }
}
