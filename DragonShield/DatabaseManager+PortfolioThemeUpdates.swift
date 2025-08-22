// DragonShield/DatabaseManager+PortfolioThemeUpdates.swift
// MARK: - Version 1.0
// MARK: - History
// - Initial creation: CRUD helpers for PortfolioThemeUpdate with optimistic concurrency.

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
            type TEXT NOT NULL CHECK (type IN ('General','Research','Rebalance','Risk')),
            author TEXT NOT NULL,
            positions_asof TEXT NULL,
            total_value_chf REAL NULL,
            created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
            updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
        );
        CREATE INDEX IF NOT EXISTS idx_ptu_theme_order ON PortfolioThemeUpdate(theme_id, created_at DESC);
        """
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            LoggingService.shared.log("ensurePortfolioThemeUpdateTable failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
    }

    func listThemeUpdates(themeId: Int) -> [PortfolioThemeUpdate] {
        var items: [PortfolioThemeUpdate] = []
        let sql = "SELECT id, theme_id, title, body_text, type, author, positions_asof, total_value_chf, created_at, updated_at FROM PortfolioThemeUpdate WHERE theme_id = ? ORDER BY created_at DESC"
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
                let posAsOf = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
                let value = sqlite3_column_type(stmt, 7) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 7)
                let created = String(cString: sqlite3_column_text(stmt, 8))
                let updated = String(cString: sqlite3_column_text(stmt, 9))
                if let type = PortfolioThemeUpdate.UpdateType(rawValue: typeStr) {
                    let item = PortfolioThemeUpdate(id: id, themeId: themeId, title: title, bodyText: body, type: type, author: author, positionsAsOf: posAsOf, totalValueChf: value, createdAt: created, updatedAt: updated)
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

    func createThemeUpdate(themeId: Int, title: String, bodyText: String, type: PortfolioThemeUpdate.UpdateType, author: String, positionsAsOf: String?, totalValueChf: Double?) -> PortfolioThemeUpdate? {
        guard PortfolioThemeUpdate.isValidTitle(title), PortfolioThemeUpdate.isValidBody(bodyText) else {
            LoggingService.shared.log("Invalid title/body for theme update", type: .info, logger: .database)
            return nil
        }
        let sql = "INSERT INTO PortfolioThemeUpdate (theme_id, title, body_text, type, author, positions_asof, total_value_chf) VALUES (?,?,?,?,?,?,?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare createThemeUpdate failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return nil
        }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_int(stmt, 1, Int32(themeId))
        sqlite3_bind_text(stmt, 2, title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, bodyText, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, type.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 5, author, -1, SQLITE_TRANSIENT)
        if let pos = positionsAsOf {
            sqlite3_bind_text(stmt, 6, pos, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 6)
        }
        if let val = totalValueChf {
            sqlite3_bind_double(stmt, 7, val)
        } else {
            sqlite3_bind_null(stmt, 7)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            LoggingService.shared.log("createThemeUpdate failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return nil
        }
        let id = Int(sqlite3_last_insert_rowid(db))
        LoggingService.shared.log("createThemeUpdate themeId=\(themeId) id=\(id)", logger: .database)
        return getThemeUpdate(id: id)
    }

    func getThemeUpdate(id: Int) -> PortfolioThemeUpdate? {
        let sql = "SELECT id, theme_id, title, body_text, type, author, positions_asof, total_value_chf, created_at, updated_at FROM PortfolioThemeUpdate WHERE id = ?"
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
                let posAsOf = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
                let value = sqlite3_column_type(stmt, 7) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 7)
                let created = String(cString: sqlite3_column_text(stmt, 8))
                let updated = String(cString: sqlite3_column_text(stmt, 9))
                if let type = PortfolioThemeUpdate.UpdateType(rawValue: typeStr) {
                    item = PortfolioThemeUpdate(id: id, themeId: themeId, title: title, bodyText: body, type: type, author: author, positionsAsOf: posAsOf, totalValueChf: value, createdAt: created, updatedAt: updated)
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

    func updateThemeUpdate(id: Int, title: String, bodyText: String, type: PortfolioThemeUpdate.UpdateType, expectedUpdatedAt: String) -> PortfolioThemeUpdate? {
        guard PortfolioThemeUpdate.isValidTitle(title), PortfolioThemeUpdate.isValidBody(bodyText) else {
            LoggingService.shared.log("Invalid title/body for updateThemeUpdate", type: .info, logger: .database)
            return nil
        }
        let sql = "UPDATE PortfolioThemeUpdate SET title = ?, body_text = ?, type = ?, updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = ? AND updated_at = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare updateThemeUpdate failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return nil
        }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, bodyText, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, type.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 4, Int32(id))
        sqlite3_bind_text(stmt, 5, expectedUpdatedAt, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            LoggingService.shared.log("updateThemeUpdate failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return nil
        }
        if sqlite3_changes(db) == 0 {
            LoggingService.shared.log("updateThemeUpdate concurrency conflict id=\(id)", type: .info, logger: .database)
            return nil
        }
        LoggingService.shared.log("updateThemeUpdate id=\(id)", logger: .database)
        return getThemeUpdate(id: id)
    }

    func deleteThemeUpdate(id: Int) -> Bool {
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
        LoggingService.shared.log("deleteThemeUpdate id=\(id)", logger: .database)
        return true
    }
}
