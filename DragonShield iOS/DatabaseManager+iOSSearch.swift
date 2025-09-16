#if os(iOS)
import Foundation
import SQLite3

extension DatabaseManager {
    struct ThemeUpdateSearchHit: Identifiable {
        let id: Int
        let themeId: Int
        let themeName: String
        let themeCode: String
        let update: PortfolioThemeUpdate
    }

    struct InstrumentUpdateSearchHit: Identifiable {
        let id: Int
        let themeId: Int
        let instrumentId: Int
        let themeName: String
        let themeCode: String
        let instrumentName: String
        let instrumentTicker: String?
        let update: PortfolioThemeAssetUpdate
    }

    func searchInstrumentsIOS(query: String, limit: Int = 25) -> [InstrumentRow] {
        guard let db, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        guard tableExistsIOS("Instruments") else { return [] }
        let tokens = normalizedTokens(from: query)
        guard !tokens.isEmpty else { return [] }
        let columns = [
            "instrument_name",
            "COALESCE(ticker_symbol, '')",
            "COALESCE(isin, '')",
            "COALESCE(valor_nr, '')"
        ]
        let (tokenClause, binds) = buildTokenClause(tokens: tokens, columns: columns)
        var sql = """
            SELECT instrument_id,
                   instrument_name,
                   currency,
                   sub_class_id,
                   ticker_symbol,
                   isin,
                   valor_nr,
                   is_deleted,
                   is_active
              FROM Instruments
             WHERE is_deleted = 0
               AND is_active = 1
        """
        if !tokenClause.isEmpty { sql += " AND \(tokenClause)" }
        sql += " ORDER BY instrument_name COLLATE NOCASE LIMIT ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        bindLikeParameters(statement: stmt, values: binds)
        sqlite3_bind_int(stmt, Int32(binds.count + 1), Int32(limit))
        var rows: [InstrumentRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(stmt, 0))
            let name = String(cString: sqlite3_column_text(stmt, 1))
            let currency = String(cString: sqlite3_column_text(stmt, 2))
            let subClassId = Int(sqlite3_column_int(stmt, 3))
            let ticker = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
            let isin = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
            let valor = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
            let isDeleted = sqlite3_column_int(stmt, 7) == 1
            let isActive = sqlite3_column_int(stmt, 8) == 1
            rows.append(InstrumentRow(id: id, name: name, currency: currency, subClassId: subClassId, tickerSymbol: ticker, isin: isin, valorNr: valor, isDeleted: isDeleted, isActive: isActive))
        }
        return rows
    }

    func searchThemesIOS(query: String, limit: Int = 20) -> [PortfolioTheme] {
        guard let db, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        guard tableExistsIOS("PortfolioTheme") else { return [] }
        let tokens = normalizedTokens(from: query)
        guard !tokens.isEmpty else { return [] }
        let hasAssetTable = tableExistsIOS("PortfolioThemeAsset")
        let hasBudget = tableHasColumnIOS(table: "PortfolioTheme", column: "theoretical_budget_chf")
        let hasSoftDelete = tableHasColumnIOS(table: "PortfolioTheme", column: "soft_delete")
        let hasArchivedAt = tableHasColumnIOS(table: "PortfolioTheme", column: "archived_at")
        let columns = [
            "pt.name",
            "pt.code",
            "COALESCE(pt.description, '')"
        ]
        let (tokenClause, binds) = buildTokenClause(tokens: tokens, columns: columns)
        var sql = "SELECT pt.id, pt.name, pt.code, pt.description, pt.institution_id, pt.status_id, pt.created_at, pt.updated_at,"
        sql += hasArchivedAt ? "pt.archived_at" : "NULL"
        sql += ","
        sql += hasSoftDelete ? "pt.soft_delete" : "0"
        if hasBudget { sql += ", pt.theoretical_budget_chf" }
        if hasAssetTable {
            sql += ", (SELECT COUNT(*) FROM PortfolioThemeAsset pta WHERE pta.theme_id = pt.id)"
        } else {
            sql += ", 0"
        }
        sql += " FROM PortfolioTheme pt WHERE 1=1"
        if hasSoftDelete { sql += " AND pt.soft_delete = 0" }
        if !tokenClause.isEmpty { sql += " AND \(tokenClause)" }
        sql += " ORDER BY pt.updated_at DESC LIMIT ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        bindLikeParameters(statement: stmt, values: binds)
        sqlite3_bind_int(stmt, Int32(binds.count + 1), Int32(limit))
        var themes: [PortfolioTheme] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(stmt, 0))
            let name = String(cString: sqlite3_column_text(stmt, 1))
            let code = String(cString: sqlite3_column_text(stmt, 2))
            let desc = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
            let instId = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 4))
            let statusId = Int(sqlite3_column_int(stmt, 5))
            let createdAt = String(cString: sqlite3_column_text(stmt, 6))
            let updatedAt = String(cString: sqlite3_column_text(stmt, 7))
            let archivedRaw = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
            let archivedAt = (archivedRaw?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true) ? nil : archivedRaw
            let softDelete = sqlite3_column_int(stmt, 9) == 1
            var idx = 10
            let budget: Double?
            if hasBudget {
                budget = sqlite3_column_type(stmt, Int32(idx)) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, Int32(idx))
                idx += 1
            } else {
                budget = nil
            }
            let instrumentCount = Int(sqlite3_column_int(stmt, Int32(idx)))
            let theme = PortfolioTheme(
                id: id,
                name: name,
                code: code,
                description: desc,
                institutionId: instId,
                statusId: statusId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                archivedAt: archivedAt,
                softDelete: softDelete,
                theoreticalBudgetChf: budget,
                totalValueBase: nil,
                instrumentCount: instrumentCount
            )
            themes.append(theme)
        }
        return themes
    }

    func searchThemeUpdatesIOS(query: String, limit: Int = 15) -> [ThemeUpdateSearchHit] {
        guard let db, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        guard tableExistsIOS("PortfolioThemeUpdate"), tableExistsIOS("PortfolioTheme") else { return [] }
        let tokens = normalizedTokens(from: query)
        guard !tokens.isEmpty else { return [] }
        let hasNews = tableExistsIOS("NewsType")
        let hasSoftDelete = tableHasColumnIOS(table: "PortfolioThemeUpdate", column: "soft_delete")
        let hasDeletedAt = tableHasColumnIOS(table: "PortfolioThemeUpdate", column: "deleted_at")
        let hasDeletedBy = tableHasColumnIOS(table: "PortfolioThemeUpdate", column: "deleted_by")
        let hasPositions = tableHasColumnIOS(table: "PortfolioThemeUpdate", column: "positions_asof")
        let hasTotalValue = tableHasColumnIOS(table: "PortfolioThemeUpdate", column: "total_value_chf")
        let hasBodyMarkdown = tableHasColumnIOS(table: "PortfolioThemeUpdate", column: "body_markdown")
        let hasBodyText = tableHasColumnIOS(table: "PortfolioThemeUpdate", column: "body_text")
        let bodyExpr: String
        if hasBodyMarkdown && hasBodyText {
            bodyExpr = "COALESCE(u.body_markdown, u.body_text, '')"
        } else if hasBodyMarkdown {
            bodyExpr = "COALESCE(u.body_markdown, '')"
        } else if hasBodyText {
            bodyExpr = "COALESCE(u.body_text, '')"
        } else {
            bodyExpr = "''"
        }
        let columns = [
            "u.title",
            bodyExpr,
            "t.name",
            "t.code"
        ]
        let (tokenClause, binds) = buildTokenClause(tokens: tokens, columns: columns)
        var sql = """
            SELECT u.id,
                   u.theme_id,
                   t.name,
                   t.code,
                   u.title,
                   \(bodyExpr) AS body_value,
                   u.type_id,
                   \(hasNews ? "n.code" : "NULL") AS type_code,
                   \(hasNews ? "n.display_name" : "NULL") AS type_name,
                   u.author,
                   u.pinned,
                   \(hasPositions ? "u.positions_asof" : "NULL") AS positions_asof,
                   \(hasTotalValue ? "u.total_value_chf" : "NULL") AS total_value_chf,
                   u.created_at,
                   u.updated_at,
                   \(hasSoftDelete ? "u.soft_delete" : "0") AS soft_delete,
                   \(hasDeletedAt ? "u.deleted_at" : "NULL") AS deleted_at,
                   \(hasDeletedBy ? "u.deleted_by" : "NULL") AS deleted_by
              FROM PortfolioThemeUpdate u
              JOIN PortfolioTheme t ON t.id = u.theme_id
        """
        if hasNews {
            sql += " LEFT JOIN NewsType n ON n.id = u.type_id"
        }
        sql += " WHERE 1=1"
        if hasSoftDelete { sql += " AND u.soft_delete = 0" }
        if !tokenClause.isEmpty { sql += " AND \(tokenClause)" }
        sql += " ORDER BY u.updated_at DESC LIMIT ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        bindLikeParameters(statement: stmt, values: binds)
        sqlite3_bind_int(stmt, Int32(binds.count + 1), Int32(limit))
        var hits: [ThemeUpdateSearchHit] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let updateId = Int(sqlite3_column_int(stmt, 0))
            let themeId = Int(sqlite3_column_int(stmt, 1))
            let themeName = String(cString: sqlite3_column_text(stmt, 2))
            let themeCode = String(cString: sqlite3_column_text(stmt, 3))
            let title = String(cString: sqlite3_column_text(stmt, 4))
            let body = sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? ""
            let typeId = sqlite3_column_type(stmt, 6) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 6))
            let typeCode = sqlite3_column_text(stmt, 7).map { String(cString: $0) } ?? ""
            let typeName = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
            let author = String(cString: sqlite3_column_text(stmt, 9))
            let pinned = sqlite3_column_int(stmt, 10) == 1
            let positionsAsOf = sqlite3_column_text(stmt, 11).map { String(cString: $0) }
            let totalValue = sqlite3_column_type(stmt, 12) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 12)
            let createdAt = String(cString: sqlite3_column_text(stmt, 13))
            let updatedAt = String(cString: sqlite3_column_text(stmt, 14))
            let softDelete = sqlite3_column_int(stmt, 15) == 1
            let deletedAt = sqlite3_column_text(stmt, 16).map { String(cString: $0) }
            let deletedBy = sqlite3_column_text(stmt, 17).map { String(cString: $0) }
            let update = PortfolioThemeUpdate(
                id: updateId,
                themeId: themeId,
                title: title,
                bodyMarkdown: body,
                typeId: typeId,
                typeCode: typeCode,
                typeDisplayName: typeName,
                author: author,
                pinned: pinned,
                positionsAsOf: positionsAsOf,
                totalValueChf: totalValue,
                createdAt: createdAt,
                updatedAt: updatedAt,
                softDelete: softDelete,
                deletedAt: deletedAt,
                deletedBy: deletedBy
            )
            hits.append(ThemeUpdateSearchHit(id: updateId, themeId: themeId, themeName: themeName, themeCode: themeCode, update: update))
        }
        return hits
    }

    func searchInstrumentUpdatesIOS(query: String, limit: Int = 15) -> [InstrumentUpdateSearchHit] {
        guard let db, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        guard tableExistsIOS("PortfolioThemeAssetUpdate"), tableExistsIOS("PortfolioTheme"), tableExistsIOS("Instruments") else { return [] }
        let tokens = normalizedTokens(from: query)
        guard !tokens.isEmpty else { return [] }
        let hasNews = tableExistsIOS("NewsType")
        let hasBodyMarkdown = tableHasColumnIOS(table: "PortfolioThemeAssetUpdate", column: "body_markdown")
        let hasBodyText = tableHasColumnIOS(table: "PortfolioThemeAssetUpdate", column: "body_text")
        let bodyExpr: String
        if hasBodyMarkdown && hasBodyText {
            bodyExpr = "COALESCE(u.body_markdown, u.body_text, '')"
        } else if hasBodyMarkdown {
            bodyExpr = "COALESCE(u.body_markdown, '')"
        } else if hasBodyText {
            bodyExpr = "COALESCE(u.body_text, '')"
        } else {
            bodyExpr = "''"
        }
        let columns = [
            "u.title",
            bodyExpr,
            "t.name",
            "i.instrument_name",
            "COALESCE(i.ticker_symbol, '')",
            "COALESCE(i.isin, '')"
        ]
        let (tokenClause, binds) = buildTokenClause(tokens: tokens, columns: columns)
        var sql = """
            SELECT u.id,
                   u.theme_id,
                   t.name,
                   t.code,
                   u.instrument_id,
                   i.instrument_name,
                   i.ticker_symbol,
                   u.title,
                   \(bodyExpr) AS body_value,
                   u.type_id,
                   \(hasNews ? "n.code" : "NULL") AS type_code,
                   \(hasNews ? "n.display_name" : "NULL") AS type_name,
                   u.author,
                   u.pinned,
                   u.positions_asof,
                   u.value_chf,
                   u.actual_percent,
                   u.created_at,
                   u.updated_at
              FROM PortfolioThemeAssetUpdate u
              JOIN PortfolioTheme t ON t.id = u.theme_id
              JOIN Instruments i ON i.instrument_id = u.instrument_id
        """
        if hasNews {
            sql += " LEFT JOIN NewsType n ON n.id = u.type_id"
        }
        sql += " WHERE 1=1"
        if !tokenClause.isEmpty { sql += " AND \(tokenClause)" }
        sql += " ORDER BY u.updated_at DESC LIMIT ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        bindLikeParameters(statement: stmt, values: binds)
        sqlite3_bind_int(stmt, Int32(binds.count + 1), Int32(limit))
        var hits: [InstrumentUpdateSearchHit] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let updateId = Int(sqlite3_column_int(stmt, 0))
            let themeId = Int(sqlite3_column_int(stmt, 1))
            let themeName = String(cString: sqlite3_column_text(stmt, 2))
            let themeCode = String(cString: sqlite3_column_text(stmt, 3))
            let instrumentId = Int(sqlite3_column_int(stmt, 4))
            let instrumentName = String(cString: sqlite3_column_text(stmt, 5))
            let ticker = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
            let title = String(cString: sqlite3_column_text(stmt, 7))
            let body = sqlite3_column_text(stmt, 8).map { String(cString: $0) } ?? ""
            let typeId = sqlite3_column_type(stmt, 9) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 9))
            let typeCode = sqlite3_column_text(stmt, 10).map { String(cString: $0) } ?? ""
            let typeName = sqlite3_column_text(stmt, 11).map { String(cString: $0) }
            let author = String(cString: sqlite3_column_text(stmt, 12))
            let pinned = sqlite3_column_int(stmt, 13) == 1
            let positionsAsOf = sqlite3_column_text(stmt, 14).map { String(cString: $0) }
            let valueChf = sqlite3_column_type(stmt, 15) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 15)
            let actualPercent = sqlite3_column_type(stmt, 16) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 16)
            let createdAt = String(cString: sqlite3_column_text(stmt, 17))
            let updatedAt = String(cString: sqlite3_column_text(stmt, 18))
            let update = PortfolioThemeAssetUpdate(
                id: updateId,
                themeId: themeId,
                instrumentId: instrumentId,
                title: title,
                bodyMarkdown: body,
                typeId: typeId,
                typeCode: typeCode,
                typeDisplayName: typeName,
                author: author,
                pinned: pinned,
                positionsAsOf: positionsAsOf,
                valueChf: valueChf,
                actualPercent: actualPercent,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
            hits.append(InstrumentUpdateSearchHit(id: updateId, themeId: themeId, instrumentId: instrumentId, themeName: themeName, themeCode: themeCode, instrumentName: instrumentName, instrumentTicker: ticker, update: update))
        }
        return hits
    }
}

private extension DatabaseManager {
    func normalizedTokens(from query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let separators = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        let raw = trimmed.components(separatedBy: separators)
        var tokens = raw.filter { !$0.isEmpty }
        if tokens.isEmpty { tokens = [trimmed] }
        if tokens.count > 5 { tokens = Array(tokens.prefix(5)) }
        return tokens
    }

    func buildTokenClause(tokens: [String], columns: [String]) -> (String, [String]) {
        guard !tokens.isEmpty else { return ("", []) }
        var clauses: [String] = []
        var binds: [String] = []
        for token in tokens {
            let pattern = likePattern(for: token)
            let columnClauses = columns.map { "\($0) LIKE ? COLLATE NOCASE ESCAPE '\\'" }
            clauses.append("(" + columnClauses.joined(separator: " OR ") + ")")
            binds.append(contentsOf: Array(repeating: pattern, count: columns.count))
        }
        return (clauses.joined(separator: " AND "), binds)
    }

    func likePattern(for token: String) -> String {
        let escaped = escapeLikePattern(token)
        return "%" + escaped + "%"
    }

    func escapeLikePattern(_ token: String) -> String {
        var output = ""
        for ch in token {
            if ch == "%" || ch == "_" || ch == "\\" { output.append("\\") }
            output.append(ch)
        }
        return output
    }

    func bindLikeParameters(statement: OpaquePointer?, values: [String]) {
        guard let statement else { return }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (idx, value) in values.enumerated() {
            sqlite3_bind_text(statement, Int32(idx + 1), value, -1, SQLITE_TRANSIENT)
        }
    }

    func tableHasColumnIOS(table: String, column: String) -> Bool {
        guard let db else { return false }
        var stmt: OpaquePointer?
        let sql = "PRAGMA table_info(\(table))"
        var exists = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let nameC = sqlite3_column_text(stmt, 1) {
                    let name = String(cString: nameC)
                    if name.caseInsensitiveCompare(column) == .orderedSame {
                        exists = true
                        break
                    }
                }
            }
        }
        sqlite3_finalize(stmt)
        return exists
    }
}
#endif
