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
        if themeId != nil {
            whereClause = "theme_id = ? AND instrument_id = ?"
        } else {
            whereClause = "instrument_id = ?"
        }
        let sql = "SELECT u.id, u.theme_id, u.instrument_id, u.title, u.body_markdown, u.type_id, u.type, n.display_name, u.author, u.pinned, u.positions_asof, u.value_chf, u.actual_percent, u.created_at, u.updated_at FROM PortfolioThemeAssetUpdate u LEFT JOIN NewsType n ON n.id = u.type_id WHERE \(whereClause) ORDER BY \(order)"
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
                let typeId = sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 5))
                let typeStr = sqlite3_column_text(stmt, 6).map { String(cString: $0) } ?? ""
                let typeName = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
                let author = String(cString: sqlite3_column_text(stmt, 8))
                let pinned = sqlite3_column_int(stmt, 9) == 1
                let positionsAsOf = sqlite3_column_text(stmt, 10).map { String(cString: $0) }
                let value = sqlite3_column_type(stmt, 11) != SQLITE_NULL ? sqlite3_column_double(stmt, 11) : nil
                let actual = sqlite3_column_type(stmt, 12) != SQLITE_NULL ? sqlite3_column_double(stmt, 12) : nil
                let created = String(cString: sqlite3_column_text(stmt, 13))
                let updated = String(cString: sqlite3_column_text(stmt, 14))
                items.append(PortfolioThemeAssetUpdate(id: id, themeId: themeId, instrumentId: instrumentId, title: title, bodyMarkdown: body, typeId: typeId, typeCode: typeStr, typeDisplayName: typeName, author: author, pinned: pinned, positionsAsOf: positionsAsOf, valueChf: value, actualPercent: actual, createdAt: created, updatedAt: updated))
            }
        } else {
            LoggingService.shared.log("Failed to prepare listInstrumentUpdatesForInstrument: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return items
    }

    func listThemeMentions(themeId: Int, instrumentCode: String, instrumentName: String) -> [PortfolioThemeUpdate] {
        let sql = "SELECT u.id, u.theme_id, u.title, COALESCE(u.body_markdown, u.body_text), u.type_id, u.type, n.display_name, u.author, u.pinned, u.positions_asof, u.total_value_chf, u.created_at, u.updated_at, u.soft_delete, u.deleted_at, u.deleted_by FROM PortfolioThemeUpdate u LEFT JOIN NewsType n ON n.id = u.type_id WHERE u.theme_id = ? AND u.soft_delete = 0 ORDER BY u.created_at DESC"
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
