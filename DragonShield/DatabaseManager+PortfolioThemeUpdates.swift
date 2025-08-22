// DragonShield/DatabaseManager+PortfolioThemeUpdates.swift
// MARK: - Version 1.1
// MARK: - History
// - 1.0 -> 1.1: Support Markdown bodies and pinning with ordering options.

import SQLite3
import Foundation

extension DatabaseManager {
    func ensurePortfolioThemeUpdateTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS PortfolioThemeUpdate (
            id INTEGER PRIMARY KEY,
            theme_id INTEGER NOT NULL REFERENCES PortfolioTheme(id) ON DELETE CASCADE,
            title TEXT NOT NULL CHECK (LENGTH(title) BETWEEN 1 AND 120),
            body_text TEXT NOT NULL CHECK (LENGTH(body_text) BETWEEN 1 AND 5000),
            body_markdown TEXT NOT NULL CHECK (LENGTH(body_markdown) BETWEEN 1 AND 5000),
            type TEXT NOT NULL CHECK (type IN ('General','Research','Rebalance','Risk')),
            author TEXT NOT NULL,
            pinned INTEGER NOT NULL DEFAULT 0 CHECK (pinned IN (0,1)),
            positions_asof TEXT NULL,
            total_value_chf REAL NULL,
            created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
            updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
        );
        CREATE INDEX IF NOT EXISTS idx_ptu_theme_order ON PortfolioThemeUpdate(theme_id, created_at DESC);
        CREATE INDEX IF NOT EXISTS idx_ptu_theme_pinned_order ON PortfolioThemeUpdate(theme_id, pinned DESC, created_at DESC);
        """
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            LoggingService.shared.log("ensurePortfolioThemeUpdateTable failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
    }

    func listThemeUpdates(themeId: Int, pinnedFirst: Bool = true) -> [PortfolioThemeUpdate] {
        var items: [PortfolioThemeUpdate] = []
        let order = pinnedFirst ? "pinned DESC, created_at DESC" : "created_at DESC"
        let sql = "SELECT id, theme_id, title, body_markdown, type, author, pinned, positions_asof, total_value_chf, created_at, updated_at FROM PortfolioThemeUpdate WHERE theme_id = ? ORDER BY \(order)"
        var stmt: OpaquePointer?
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
                let posAsOf = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
                let value = sqlite3_column_type(stmt, 8) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 8)
                let created = String(cString: sqlite3_column_text(stmt, 9))
                let updated = String(cString: sqlite3_column_text(stmt, 10))
                if let type = PortfolioThemeUpdate.UpdateType(rawValue: typeStr) {
                    let item = PortfolioThemeUpdate(id: id, themeId: themeId, title: title, bodyMarkdown: body, type: type, author: author, pinned: pinned, positionsAsOf: posAsOf, totalValueChf: value, createdAt: created, updatedAt: updated)
                    items.append(item)
                } else {
                    LoggingService.shared.log("Invalid update type '\(typeStr)' for theme update id \(id). Skipping row.", type: .warning, logger: .database)
                }
            }
        } else {
            LoggingService.shared.log("Failed to prepare listThemeUpdates: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return items
    }

    func createThemeUpdate(themeId: Int, title: String, bodyMarkdown: String, type: PortfolioThemeUpdate.UpdateType, pinned: Bool, author: String, positionsAsOf: String?, totalValueChf: Double?) -> PortfolioThemeUpdate? {
        guard PortfolioThemeUpdate.isValidTitle(title), PortfolioThemeUpdate.isValidBody(bodyMarkdown) else {
            LoggingService.shared.log("Invalid title/body for theme update", type: .info, logger: .database)
            return nil
        }
        let sql = "INSERT INTO PortfolioThemeUpdate (theme_id, title, body_text, body_markdown, type, author, pinned, positions_asof, total_value_chf) VALUES (?,?,?,?,?,?,?,?,?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare createThemeUpdate failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return nil
        }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_int(stmt, 1, Int32(themeId))
        sqlite3_bind_text(stmt, 2, title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, bodyMarkdown, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, bodyMarkdown, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 5, type.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 6, author, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 7, pinned ? 1 : 0)
        if let pos = positionsAsOf {
            sqlite3_bind_text(stmt, 8, pos, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 8)
        }
        if let val = totalValueChf {
            sqlite3_bind_double(stmt, 9, val)
        } else {
            sqlite3_bind_null(stmt, 9)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            LoggingService.shared.log("createThemeUpdate failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return nil
        }
        let id = Int(sqlite3_last_insert_rowid(db))
        guard let item = getThemeUpdate(id: id) else { return nil }
        LoggingService.shared.log("{\"themeId\":\(themeId),\"updateId\":\(id),\"actor\":\"\(author)\",\"op\":\"create\",\"pinned\":\(pinned ? 1 : 0),\"created_at\":\"\(item.createdAt)\"}", logger: .database)
        return item
    }

    func getThemeUpdate(id: Int) -> PortfolioThemeUpdate? {
        let sql = "SELECT id, theme_id, title, body_markdown, type, author, pinned, positions_asof, total_value_chf, created_at, updated_at FROM PortfolioThemeUpdate WHERE id = ?"
        var stmt: OpaquePointer?
        var item: PortfolioThemeUpdate?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let themeId = Int(sqlite3_column_int(stmt, 1))
                let title = String(cString: sqlite3_column_text(stmt, 2))
                let body = String(cString: sqlite3_column_text(stmt, 3))
                let typeStr = String(cString: sqlite3_column_text(stmt, 4))
                let author = String(cString: sqlite3_column_text(stmt, 5))
                let pinned = sqlite3_column_int(stmt, 6) == 1
                let posAsOf = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
                let value = sqlite3_column_type(stmt, 8) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 8)
                let created = String(cString: sqlite3_column_text(stmt, 9))
                let updated = String(cString: sqlite3_column_text(stmt, 10))
                if let type = PortfolioThemeUpdate.UpdateType(rawValue: typeStr) {
                    item = PortfolioThemeUpdate(id: id, themeId: themeId, title: title, bodyMarkdown: body, type: type, author: author, pinned: pinned, positionsAsOf: posAsOf, totalValueChf: value, createdAt: created, updatedAt: updated)
                } else {
                    LoggingService.shared.log("Invalid update type '\(typeStr)' for theme update id \(id).", type: .warning, logger: .database)
                }
            }
        } else {
            LoggingService.shared.log("Failed to prepare getThemeUpdate: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return item
    }

    func updateThemeUpdate(id: Int, title: String?, bodyMarkdown: String?, type: PortfolioThemeUpdate.UpdateType?, pinned: Bool?, actor: String, expectedUpdatedAt: String) -> PortfolioThemeUpdate? {
        var sets: [String] = []
        var bind: [Any] = []
        if let title = title {
            sets.append("title = ?")
            bind.append(title)
        }
        if let body = bodyMarkdown {
            sets.append("body_text = ?")
            bind.append(body)
            sets.append("body_markdown = ?")
            bind.append(body)
        }
        if let type = type {
            sets.append("type = ?")
            bind.append(type.rawValue)
        }
        if let p = pinned {
            sets.append("pinned = ?")
            bind.append(p ? 1 : 0)
        }
        sets.append("updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')")
        let sql = "UPDATE PortfolioThemeUpdate SET \(sets.joined(separator: ", ")) WHERE id = ? AND updated_at = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare updateThemeUpdate failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return nil
        }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        var index: Int32 = 1
        for value in bind {
            if let s = value as? String {
                sqlite3_bind_text(stmt, index, s, -1, SQLITE_TRANSIENT)
            } else if let i = value as? Int {
                sqlite3_bind_int(stmt, index, Int32(i))
            }
            index += 1
        }
        sqlite3_bind_int(stmt, index, Int32(id)); index += 1
        sqlite3_bind_text(stmt, index, expectedUpdatedAt, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            LoggingService.shared.log("updateThemeUpdate failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return nil
        }
        if sqlite3_changes(db) == 0 {
            LoggingService.shared.log("updateThemeUpdate concurrency conflict id=\(id)", type: .info, logger: .database)
            return nil
        }
        guard let item = getThemeUpdate(id: id) else { return nil }
        let op: String
        if let p = pinned {
            op = p ? "pin" : "unpin"
        } else {
            op = "update"
        }
        LoggingService.shared.log("{\"themeId\":\(item.themeId),\"updateId\":\(id),\"actor\":\"\(actor)\",\"op\":\"\(op)\",\"pinned\":\(item.pinned ? 1 : 0),\"updated_at\":\"\(item.updatedAt)\"}", logger: .database)
        return item
    }

    func deleteThemeUpdate(id: Int, themeId: Int, actor: String) -> Bool {
        let sql = "DELETE FROM PortfolioThemeUpdate WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare deleteThemeUpdate failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(id))
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            LoggingService.shared.log("deleteThemeUpdate failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        LoggingService.shared.log("{\"themeId\":\(themeId),\"updateId\":\(id),\"actor\":\"\(actor)\",\"op\":\"delete\",\"pinned\":0,\"updated_at\":\"\(ISO8601DateFormatter().string(from: Date()))\"}", logger: .database)
        return true
    }
}
