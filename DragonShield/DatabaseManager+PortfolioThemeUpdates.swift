// DragonShield/DatabaseManager+PortfolioThemeUpdates.swift
// MARK: - Version 1.2
// MARK: - History
// - 1.0 -> 1.1: Support Markdown bodies and pinning with ordering options.
// - 1.1 -> 1.2: Add search, type filter, and soft-delete with restore and permanent delete.

import SQLite3
import Foundation

extension DatabaseManager {
    enum ThemeUpdateView {
        case active
        case deleted
    }

    private static let isoDateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        return f
    }()

    func ensurePortfolioThemeUpdateTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS PortfolioThemeUpdate (
            id INTEGER PRIMARY KEY,
            theme_id INTEGER NOT NULL REFERENCES PortfolioTheme(id) ON DELETE CASCADE,
            title TEXT NOT NULL CHECK (LENGTH(title) BETWEEN 1 AND 120),
            body_text TEXT NOT NULL CHECK (LENGTH(body_text) BETWEEN 1 AND 5000),
            body_markdown TEXT NOT NULL CHECK (LENGTH(body_markdown) BETWEEN 1 AND 5000),
            type_id INTEGER NOT NULL REFERENCES UpdateType(id),
            author TEXT NOT NULL,
            pinned INTEGER NOT NULL DEFAULT 0 CHECK (pinned IN (0,1)),
            positions_asof TEXT NULL,
            total_value_chf REAL NULL,
            created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
            updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
            soft_delete INTEGER NOT NULL DEFAULT 0 CHECK (soft_delete IN (0,1)),
            deleted_at TEXT NULL,
            deleted_by TEXT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_ptu_theme_active_order ON PortfolioThemeUpdate(theme_id, soft_delete, pinned, created_at DESC);
        CREATE INDEX IF NOT EXISTS idx_ptu_theme_deleted_order ON PortfolioThemeUpdate(theme_id, soft_delete, deleted_at DESC);
        """
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            LoggingService.shared.log("ensurePortfolioThemeUpdateTable failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
    }

    func listThemeUpdates(themeId: Int, view: ThemeUpdateView = .active, type: UpdateType? = nil, searchQuery: String? = nil, pinnedFirst: Bool = true) -> [PortfolioThemeUpdate] {
        var items: [PortfolioThemeUpdate] = []
        var clauses: [String] = ["theme_id = ?", "soft_delete = \(view == .active ? 0 : 1)"]
        var binds: [Any] = [themeId]
        if let t = type { clauses.append("type_id = ?"); binds.append(t.id) }
        if let q = searchQuery, !q.isEmpty {
            clauses.append("(LOWER(title) LIKE '%' || LOWER(?) || '%' OR LOWER(COALESCE(body_markdown, body_text)) LIKE '%' || LOWER(?) || '%')")
            binds.append(q)
            binds.append(q)
        }
        let whereClause = clauses.joined(separator: " AND ")
        let order: String
        switch view {
        case .active:
            order = pinnedFirst ? "pinned DESC, created_at DESC" : "created_at DESC"
        case .deleted:
            order = "deleted_at DESC, created_at DESC"
        }
        let sql = "SELECT u.id, u.theme_id, u.title, u.body_markdown, u.type_id, t.code, t.name, u.author, u.pinned, u.positions_asof, u.total_value_chf, u.created_at, u.updated_at, u.soft_delete, u.deleted_at, u.deleted_by FROM PortfolioThemeUpdate u JOIN UpdateType t ON u.type_id = t.id WHERE \(whereClause) ORDER BY \(order)"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            var index: Int32 = 1
            for b in binds {
                if let i = b as? Int {
                    sqlite3_bind_int(stmt, index, Int32(i))
                } else if let s = b as? String {
                    let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                    sqlite3_bind_text(stmt, index, s, -1, SQLITE_TRANSIENT)
                }
                index += 1
            }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let themeId = Int(sqlite3_column_int(stmt, 1))
                let title = String(cString: sqlite3_column_text(stmt, 2))
                let body = String(cString: sqlite3_column_text(stmt, 3))
                let typeId = Int(sqlite3_column_int(stmt, 4))
                let code = String(cString: sqlite3_column_text(stmt, 5))
                let name = String(cString: sqlite3_column_text(stmt, 6))
                let author = String(cString: sqlite3_column_text(stmt, 7))
                let pinned = sqlite3_column_int(stmt, 8) == 1
                let posAsOf = sqlite3_column_text(stmt, 9).map { String(cString: $0) }
                let value = sqlite3_column_type(stmt, 10) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 10)
                let created = String(cString: sqlite3_column_text(stmt, 11))
                let updated = String(cString: sqlite3_column_text(stmt, 12))
                let softDel = sqlite3_column_int(stmt, 13) == 1
                let delAt = sqlite3_column_text(stmt, 14).map { String(cString: $0) }
                let delBy = sqlite3_column_text(stmt, 15).map { String(cString: $0) }
                let ut = UpdateType(id: typeId, code: code, name: name)
                let item = PortfolioThemeUpdate(id: id, themeId: themeId, title: title, bodyMarkdown: body, type: ut, author: author, pinned: pinned, positionsAsOf: posAsOf, totalValueChf: value, createdAt: created, updatedAt: updated, softDelete: softDel, deletedAt: delAt, deletedBy: delBy)
                items.append(item)
            }
        } else {
            LoggingService.shared.log("Failed to prepare listThemeUpdates: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return items
    }

    func createThemeUpdate(themeId: Int, title: String, bodyMarkdown: String, type: UpdateType, pinned: Bool, author: String, positionsAsOf: String?, totalValueChf: Double?, source: String? = nil) -> PortfolioThemeUpdate? {
        guard PortfolioThemeUpdate.isValidTitle(title), PortfolioThemeUpdate.isValidBody(bodyMarkdown) else {
            LoggingService.shared.log("Invalid title/body for theme update", type: .info, logger: .database)
            return nil
        }
        let sql = "INSERT INTO PortfolioThemeUpdate (theme_id, title, body_text, body_markdown, type_id, author, pinned, positions_asof, total_value_chf) VALUES (?,?,?,?,?,?,?,?,?)"
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
        sqlite3_bind_int(stmt, 5, Int32(type.id))
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
        var payload: [String: Any] = [
            "themeId": themeId,
            "updateId": id,
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

    func getThemeUpdate(id: Int) -> PortfolioThemeUpdate? {
        let sql = "SELECT u.id, u.theme_id, u.title, u.body_markdown, u.type_id, t.code, t.name, u.author, u.pinned, u.positions_asof, u.total_value_chf, u.created_at, u.updated_at, u.soft_delete, u.deleted_at, u.deleted_by FROM PortfolioThemeUpdate u JOIN UpdateType t ON u.type_id = t.id WHERE u.id = ?"
        var stmt: OpaquePointer?
        var item: PortfolioThemeUpdate?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let themeId = Int(sqlite3_column_int(stmt, 1))
                let title = String(cString: sqlite3_column_text(stmt, 2))
                let body = String(cString: sqlite3_column_text(stmt, 3))
                let typeId = Int(sqlite3_column_int(stmt, 4))
                let code = String(cString: sqlite3_column_text(stmt, 5))
                let name = String(cString: sqlite3_column_text(stmt, 6))
                let author = String(cString: sqlite3_column_text(stmt, 7))
                let pinned = sqlite3_column_int(stmt, 8) == 1
                let posAsOf = sqlite3_column_text(stmt, 9).map { String(cString: $0) }
                let value = sqlite3_column_type(stmt, 10) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 10)
                let created = String(cString: sqlite3_column_text(stmt, 11))
                let updated = String(cString: sqlite3_column_text(stmt, 12))
                let softDel = sqlite3_column_int(stmt, 13) == 1
                let delAt = sqlite3_column_text(stmt, 14).map { String(cString: $0) }
                let delBy = sqlite3_column_text(stmt, 15).map { String(cString: $0) }
                let ut = UpdateType(id: typeId, code: code, name: name)
                item = PortfolioThemeUpdate(id: id, themeId: themeId, title: title, bodyMarkdown: body, type: ut, author: author, pinned: pinned, positionsAsOf: posAsOf, totalValueChf: value, createdAt: created, updatedAt: updated, softDelete: softDel, deletedAt: delAt, deletedBy: delBy)
            }
        } else {
            LoggingService.shared.log("Failed to prepare getThemeUpdate: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return item
    }

    func updateThemeUpdate(id: Int, title: String?, bodyMarkdown: String?, type: UpdateType?, pinned: Bool?, actor: String, expectedUpdatedAt: String, source: String? = nil) -> PortfolioThemeUpdate? {
        var sets: [String] = []
        var bind: [Any] = []
        if let title = title { sets.append("title = ?"); bind.append(title) }
        if let body = bodyMarkdown {
            sets.append("body_text = ?"); bind.append(body)
            sets.append("body_markdown = ?"); bind.append(body)
        }
        if let type = type { sets.append("type_id = ?"); bind.append(type.id) }
        if let p = pinned { sets.append("pinned = ?"); bind.append(p ? 1 : 0) }
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
        if let p = pinned { op = p ? "pin" : "unpin" } else { op = "update" }
        var payload: [String: Any] = [
            "themeId": item.themeId,
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

    func softDeleteThemeUpdate(id: Int, actor: String, source: String? = nil) -> Bool {
        var themeId: Int = 0
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT theme_id FROM PortfolioThemeUpdate WHERE id = ?", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW { themeId = Int(sqlite3_column_int(stmt, 0)) }
        }
        sqlite3_finalize(stmt)
        let now = Self.isoDateFormatter.string(from: Date())
        let sql = "UPDATE PortfolioThemeUpdate SET soft_delete = 1, deleted_at = ?, deleted_by = ? WHERE id = ? AND soft_delete = 0"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare softDeleteThemeUpdate failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, now, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, actor, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 3, Int32(id))
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_DONE, sqlite3_changes(db) > 0 else { return false }
        var payload: [String: Any] = [
            "themeId": themeId,
            "updateId": id,
            "actor": actor,
            "op": "soft_delete",
            "deleted_at": now
        ]
        if let source = source { payload["source"] = source }
        if let data = try? JSONSerialization.data(withJSONObject: payload), let log = String(data: data, encoding: .utf8) {
            LoggingService.shared.log(log, logger: .database)
        }
        return true
    }

    func restoreThemeUpdate(id: Int, actor: String, source: String? = nil) -> Bool {
        var themeId: Int = 0
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT theme_id FROM PortfolioThemeUpdate WHERE id = ?", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW { themeId = Int(sqlite3_column_int(stmt, 0)) }
        }
        sqlite3_finalize(stmt)
        let sql = "UPDATE PortfolioThemeUpdate SET soft_delete = 0, deleted_at = NULL, deleted_by = NULL WHERE id = ? AND soft_delete = 1"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare restoreThemeUpdate failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        sqlite3_bind_int(stmt, 1, Int32(id))
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_DONE, sqlite3_changes(db) > 0 else { return false }
        var payload: [String: Any] = [
            "themeId": themeId,
            "updateId": id,
            "actor": actor,
            "op": "restore"
        ]
        if let source = source { payload["source"] = source }
        if let data = try? JSONSerialization.data(withJSONObject: payload), let log = String(data: data, encoding: .utf8) {
            LoggingService.shared.log(log, logger: .database)
        }
        return true
    }

    func deleteThemeUpdatePermanently(id: Int, actor: String, source: String? = nil) -> Bool {
        var themeId: Int = 0
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT theme_id FROM PortfolioThemeUpdate WHERE id = ?", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW { themeId = Int(sqlite3_column_int(stmt, 0)) }
        }
        sqlite3_finalize(stmt)
        let sql = "DELETE FROM PortfolioThemeUpdate WHERE id = ?"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare deleteThemeUpdatePermanently failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        sqlite3_bind_int(stmt, 1, Int32(id))
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_DONE else { return false }
        var payload: [String: Any] = [
            "themeId": themeId,
            "updateId": id,
            "actor": actor,
            "op": "delete_permanent"
        ]
        if let source = source { payload["source"] = source }
        if let data = try? JSONSerialization.data(withJSONObject: payload), let log = String(data: data, encoding: .utf8) {
            LoggingService.shared.log(log, logger: .database)
        }
        return true
    }
}
