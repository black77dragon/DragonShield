// DragonShield/DatabaseManager+PortfolioThemes.swift
// MARK: - Version 1.0
// MARK: - History
// - Initial creation: CRUD helpers for PortfolioTheme.

import SQLite3
import Foundation

extension DatabaseManager {
    private func defaultThemeStatusId() -> Int? {
        let sql = "SELECT id FROM PortfolioThemeStatus WHERE is_default = 1 LIMIT 1"
        var stmt: OpaquePointer?
        var result: Int?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                result = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    private func archivedThemeStatusId() -> Int? {
        let sql = "SELECT id FROM PortfolioThemeStatus WHERE code = 'ARCHIVED' LIMIT 1"
        var stmt: OpaquePointer?
        var result: Int?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                result = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    func fetchPortfolioThemes(includeArchived: Bool = true, includeSoftDeleted: Bool = false, search: String? = nil) -> [PortfolioTheme] {
        var themes: [PortfolioTheme] = []
        var sql = "SELECT id,name,code,status_id,created_at,updated_at,archived_at,soft_delete FROM PortfolioTheme WHERE 1=1"
        if !includeArchived { sql += " AND archived_at IS NULL" }
        if !includeSoftDeleted { sql += " AND soft_delete = 0" }
        if let s = search, !s.isEmpty {
            sql += " AND (name LIKE ? OR code LIKE ?)"
        }
        sql += " ORDER BY updated_at DESC"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if let s = search, !s.isEmpty {
                let like = "%" + s + "%"
                let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                sqlite3_bind_text(stmt, 1, like, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 2, like, -1, SQLITE_TRANSIENT)
            }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 1))
                let code = String(cString: sqlite3_column_text(stmt, 2))
                let statusId = Int(sqlite3_column_int(stmt, 3))
                let createdAt = String(cString: sqlite3_column_text(stmt, 4))
                let updatedAt = String(cString: sqlite3_column_text(stmt, 5))
                let archivedAt = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
                let softDelete = sqlite3_column_int(stmt, 7) == 1
                themes.append(PortfolioTheme(id: id, name: name, code: code, statusId: statusId, createdAt: createdAt, updatedAt: updatedAt, archivedAt: archivedAt, softDelete: softDelete))
            }
        } else {
            LoggingService.shared.log("Failed to prepare fetchPortfolioThemes: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return themes
    }

    func createPortfolioTheme(name: String, code: String, statusId: Int? = nil) -> PortfolioTheme? {
        guard PortfolioTheme.isValidName(name) else {
            LoggingService.shared.log("Invalid theme name", type: .info, logger: .database)
            return nil
        }
        guard PortfolioTheme.isValidCode(code) else {
            LoggingService.shared.log("Invalid theme code", type: .info, logger: .database)
            return nil
        }
        let status = statusId ?? defaultThemeStatusId()
        guard let status = status else {
            LoggingService.shared.log("No default Theme Status found", type: .error, logger: .database)
            return nil
        }
        let sql = "INSERT INTO PortfolioTheme (name, code, status_id) VALUES (?,?,?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare createPortfolioTheme failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return nil
        }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, code, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 3, Int32(status))
        if sqlite3_step(stmt) != SQLITE_DONE {
            LoggingService.shared.log("createPortfolioTheme failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            sqlite3_finalize(stmt)
            return nil
        }
        sqlite3_finalize(stmt)
        let id = Int(sqlite3_last_insert_rowid(db))
        LoggingService.shared.log("Created theme id=\(id)", type: .info, logger: .database)
        return getPortfolioTheme(id: id)
    }

    func getPortfolioTheme(id: Int) -> PortfolioTheme? {
        let sql = "SELECT id,name,code,status_id,created_at,updated_at,archived_at,soft_delete FROM PortfolioTheme WHERE id = ?"
        var stmt: OpaquePointer?
        var theme: PortfolioTheme?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 1))
                let code = String(cString: sqlite3_column_text(stmt, 2))
                let statusId = Int(sqlite3_column_int(stmt, 3))
                let createdAt = String(cString: sqlite3_column_text(stmt, 4))
                let updatedAt = String(cString: sqlite3_column_text(stmt, 5))
                let archivedAt = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
                let softDelete = sqlite3_column_int(stmt, 7) == 1
                theme = PortfolioTheme(id: id, name: name, code: code, statusId: statusId, createdAt: createdAt, updatedAt: updatedAt, archivedAt: archivedAt, softDelete: softDelete)
            }
        }
        sqlite3_finalize(stmt)
        return theme
    }

    func updatePortfolioTheme(id: Int, name: String, statusId: Int, archivedAt: String?) -> Bool {
        let sql = "UPDATE PortfolioTheme SET name = ?, status_id = ?, archived_at = ?, updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare updatePortfolioTheme failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 2, Int32(statusId))
        if let archivedAt = archivedAt {
            sqlite3_bind_text(stmt, 3, archivedAt, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 3)
        }
        sqlite3_bind_int(stmt, 4, Int32(id))
        let rc = sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        if rc == SQLITE_DONE {
            LoggingService.shared.log("Updated theme id=\(id)", type: .info, logger: .database)
            return true
        } else {
            LoggingService.shared.log("updatePortfolioTheme failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
    }

    func archivePortfolioTheme(id: Int) -> Bool {
        guard let archivedId = archivedThemeStatusId() else { return false }
        let sql = "UPDATE PortfolioTheme SET status_id = ?, archived_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'), updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        sqlite3_bind_int(stmt, 1, Int32(archivedId))
        sqlite3_bind_int(stmt, 2, Int32(id))
        let rc = sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        if rc == SQLITE_DONE {
            LoggingService.shared.log("Archived theme id=\(id)", type: .info, logger: .database)
            return true
        }
        LoggingService.shared.log("archivePortfolioTheme failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        return false
    }

    func unarchivePortfolioTheme(id: Int, statusId: Int) -> Bool {
        let sql = "UPDATE PortfolioTheme SET status_id = ?, archived_at = NULL, updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        sqlite3_bind_int(stmt, 1, Int32(statusId))
        sqlite3_bind_int(stmt, 2, Int32(id))
        let rc = sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        if rc == SQLITE_DONE {
            LoggingService.shared.log("Unarchived theme id=\(id)", type: .info, logger: .database)
            return true
        }
        LoggingService.shared.log("unarchivePortfolioTheme failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        return false
    }

    func softDeletePortfolioTheme(id: Int) -> Bool {
        let checkSql = "SELECT archived_at FROM PortfolioTheme WHERE id = ?"
        var checkStmt: OpaquePointer?
        var archived: Bool = false
        if sqlite3_prepare_v2(db, checkSql, -1, &checkStmt, nil) == SQLITE_OK {
            sqlite3_bind_int(checkStmt, 1, Int32(id))
            if sqlite3_step(checkStmt) == SQLITE_ROW {
                archived = sqlite3_column_text(checkStmt, 0) != nil
            }
        }
        sqlite3_finalize(checkStmt)
        if !archived {
            LoggingService.shared.log("Soft delete requires the theme to be Archived first.", type: .info, logger: .database)
            return false
        }
        let sql = "UPDATE PortfolioTheme SET soft_delete = 1, updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        sqlite3_bind_int(stmt, 1, Int32(id))
        let rc = sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        if rc == SQLITE_DONE {
            LoggingService.shared.log("Soft deleted theme id=\(id)", type: .info, logger: .database)
            return true
        }
        LoggingService.shared.log("softDeletePortfolioTheme failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        return false
    }
}
