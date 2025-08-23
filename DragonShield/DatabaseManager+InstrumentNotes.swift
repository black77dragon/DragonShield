import Foundation
import SQLite3

extension DatabaseManager {
    private func normalizeNotesText(_ text: String) -> String {
        let lowered = text.lowercased()
        let mapped = lowered.map { $0.isLetter || $0.isNumber ? String($0) : " " }.joined()
        let collapsed = mapped.split { $0 == " " }.joined(separator: " ")
        return " " + collapsed + " "
    }

    func listInstrumentUpdatesForInstrument(instrumentId: Int, themeId: Int? = nil, pinnedFirst: Bool = true) -> [PortfolioThemeAssetUpdate] {
        var items: [PortfolioThemeAssetUpdate] = []
        let order = pinnedFirst ? "pinned DESC, created_at DESC" : "created_at DESC"
        let whereClause: String
        if let tid = themeId {
            whereClause = "theme_id = ? AND instrument_id = ?"
        } else {
            whereClause = "instrument_id = ?"
        }
        let sql = "SELECT id, theme_id, instrument_id, title, body_markdown, type, author, pinned, positions_asof, value_chf, actual_percent, created_at, updated_at FROM PortfolioThemeAssetUpdate WHERE \(whereClause) ORDER BY \(order)"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if let tid = themeId {
                sqlite3_bind_int(stmt, 1, Int32(tid))
                sqlite3_bind_int(stmt, 2, Int32(instrumentId))
            } else {
                sqlite3_bind_int(stmt, 1, Int32(instrumentId))
            }
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
            LoggingService.shared.log("Failed to prepare listInstrumentUpdatesForInstrument: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return items
    }

    func listThemeMentions(themeId: Int, instrumentCode: String, instrumentName: String) -> [PortfolioThemeUpdate] {
        let sql = "SELECT id, theme_id, title, COALESCE(body_markdown, body_text), type, author, pinned, positions_asof, total_value_chf, created_at, updated_at, soft_delete, deleted_at, deleted_by FROM PortfolioThemeUpdate WHERE theme_id = ? AND soft_delete = 0 ORDER BY created_at DESC"
        var stmt: OpaquePointer?
        var items: [PortfolioThemeUpdate] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(themeId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let themeId = Int(sqlite3_column_int(stmt, 1))
                let title = String(cString: sqlite3_column_text(stmt, 2))
                let body = String(cString: sqlite3_column_text(stmt, 3))
                let typeStr = String(cString: sqlite3_column_text(stmt, 4))
                let author = String(cString: sqlite3_column_text(stmt, 5))
                let pinned = sqlite3_column_int(stmt, 6) == 1
                let positionsAsOf = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
                let totalValue = sqlite3_column_type(stmt, 8) != SQLITE_NULL ? sqlite3_column_double(stmt, 8) : nil
                let created = String(cString: sqlite3_column_text(stmt, 9))
                let updated = String(cString: sqlite3_column_text(stmt, 10))
                let softDelete = sqlite3_column_int(stmt, 11) == 1
                let deletedAt = sqlite3_column_text(stmt, 12).map { String(cString: $0) }
                let deletedBy = sqlite3_column_text(stmt, 13).map { String(cString: $0) }
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
                if matched, let type = PortfolioThemeUpdate.UpdateType(rawValue: typeStr) {
                    items.append(PortfolioThemeUpdate(id: id, themeId: themeId, title: title, bodyMarkdown: body, type: type, author: author, pinned: pinned, positionsAsOf: positionsAsOf, totalValueChf: totalValue, createdAt: created, updatedAt: updated, softDelete: softDelete, deletedAt: deletedAt, deletedBy: deletedBy))
                }
            }
        } else {
            LoggingService.shared.log("Failed to prepare listThemeMentions: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return items
    }

    func instrumentNotesSummary(instrumentId: Int, instrumentCode: String, instrumentName: String) -> (updates: Int, mentions: Int) {
        var updates = 0
        let sql = "SELECT COUNT(*) FROM PortfolioThemeAssetUpdate WHERE instrument_id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(instrumentId))
            if sqlite3_step(stmt) == SQLITE_ROW {
                updates = Int(sqlite3_column_int(stmt, 0))
            }
        } else {
            LoggingService.shared.log("Failed to prepare instrumentNotesSummary updates: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        let themes = listThemesForInstrumentWithUpdateCounts(instrumentId: instrumentId, instrumentCode: instrumentCode, instrumentName: instrumentName)
        let mentions = themes.reduce(0) { $0 + $1.mentionsCount }
        return (updates, mentions)
    }
}

