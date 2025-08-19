// DragonShield/DatabaseManager+PortfolioThemeStatus.swift
// MARK: - Version 1.0
// MARK: - History
// - Initial creation: CRUD helpers for PortfolioThemeStatus with default enforcement.

import SQLite3
import Foundation

extension DatabaseManager {
    func fetchPortfolioThemeStatuses() -> [PortfolioThemeStatus] {
        var items: [PortfolioThemeStatus] = []
        let sql = "SELECT id, code, name, color_hex, is_default FROM PortfolioThemeStatus ORDER BY id"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let code = String(cString: sqlite3_column_text(stmt, 1))
                let name = String(cString: sqlite3_column_text(stmt, 2))
                let color = String(cString: sqlite3_column_text(stmt, 3))
                let isDefault = sqlite3_column_int(stmt, 4) == 1
                items.append(PortfolioThemeStatus(id: id, code: code, name: name, colorHex: color, isDefault: isDefault))
            }
        } else {
            LoggingService.shared.log("Failed to prepare fetchPortfolioThemeStatuses: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return items
    }

    func insertPortfolioThemeStatus(code: String, name: String, colorHex: String, isDefault: Bool) -> Bool {
        let beginRc = sqlite3_exec(db, "BEGIN IMMEDIATE", nil, nil, nil)
        guard beginRc == SQLITE_OK else {
            LoggingService.shared.log("BEGIN insertPortfolioThemeStatus failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }

        var success = false
        defer {
            let endRc = sqlite3_exec(db, success ? "COMMIT" : "ROLLBACK", nil, nil, nil)
            if endRc != SQLITE_OK {
                LoggingService.shared.log("Transaction \(success ? "COMMIT" : "ROLLBACK") failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            }
        }

        if isDefault {
            let rc = sqlite3_exec(db, "UPDATE PortfolioThemeStatus SET is_default = 0 WHERE is_default = 1", nil, nil, nil)
            if rc != SQLITE_OK {
                LoggingService.shared.log("Failed to clear existing default: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
                return false
            }
        }

        let sql = "INSERT INTO PortfolioThemeStatus (code, name, color_hex, is_default) VALUES (?,?,?,?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare insertPortfolioThemeStatus failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, code, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, colorHex, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 4, isDefault ? 1 : 0)
        if sqlite3_step(stmt) == SQLITE_DONE {
            LoggingService.shared.log("Inserted theme status \(code)", type: .info, logger: .database)
            success = true
            return true
        } else {
            LoggingService.shared.log("Insert theme status failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
    }

    func updatePortfolioThemeStatus(id: Int, name: String, colorHex: String, isDefault: Bool) -> Bool {
        let beginRc = sqlite3_exec(db, "BEGIN IMMEDIATE", nil, nil, nil)
        guard beginRc == SQLITE_OK else {
            LoggingService.shared.log("BEGIN updatePortfolioThemeStatus failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }

        var success = false
        defer {
            let endRc = sqlite3_exec(db, success ? "COMMIT" : "ROLLBACK", nil, nil, nil)
            if endRc != SQLITE_OK {
                LoggingService.shared.log("Transaction \(success ? "COMMIT" : "ROLLBACK") failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            }
        }

        if isDefault {
            let rc = sqlite3_exec(db, "UPDATE PortfolioThemeStatus SET is_default = 0 WHERE is_default = 1", nil, nil, nil)
            if rc != SQLITE_OK {
                LoggingService.shared.log("Failed to clear existing default: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
                return false
            }
        }

        let sql = "UPDATE PortfolioThemeStatus SET name = ?, color_hex = ?, is_default = ? WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare updatePortfolioThemeStatus failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, colorHex, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 3, isDefault ? 1 : 0)
        sqlite3_bind_int(stmt, 4, Int32(id))
        if sqlite3_step(stmt) == SQLITE_DONE {
            LoggingService.shared.log("Updated theme status id=\(id)", type: .info, logger: .database)
            success = true
            return true
        } else {
            LoggingService.shared.log("Update theme status failed id=\(id): \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
    }

    func setDefaultThemeStatus(id: Int) {
        let sql = "UPDATE PortfolioThemeStatus SET is_default = CASE WHEN id = ? THEN 1 ELSE 0 END"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_DONE {
                LoggingService.shared.log("Set default theme status id=\(id)", type: .info, logger: .database)
            } else {
                LoggingService.shared.log("Failed to set default theme status: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            }
        } else {
            LoggingService.shared.log("prepare setDefaultThemeStatus failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
    }

    func ensurePortfolioThemeStatusDefault() {
        let sql = "SELECT COUNT(*) FROM PortfolioThemeStatus WHERE is_default = 1"
        var stmt: OpaquePointer?
        var count = 0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        if count == 0 {
            sqlite3_exec(db, "UPDATE PortfolioThemeStatus SET is_default = 1 WHERE code = 'DRAFT'", nil, nil, nil)
            LoggingService.shared.log("Default theme status was missing and restored to Draft", type: .error, logger: .database)
        }
    }
}
