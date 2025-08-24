// DragonShield/DatabaseManager+PortfolioThemeStatus.swift
// MARK: - Version 1.1
// MARK: - History
// - Initial creation: CRUD helpers for PortfolioThemeStatus with default enforcement.
// - 1.1: Return detailed errors and support deletion of unused statuses.

import SQLite3
import Foundation

enum ThemeStatusDBError: Error, Equatable, LocalizedError {
    case invalidCode
    case duplicateCode
    case duplicateName
    case defaultConflict
    case isDefault
    case inUse(count: Int)
    case database(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidCode:
            return "Code is invalid. Use A–Z, 0–9, _ (2–10), starting with a letter."
        case .duplicateCode:
            return "A status with this Code already exists."
        case .duplicateName:
            return "A status with this Name already exists."
        case .defaultConflict:
            return "Could not set default. Please retry."
        case .isDefault:
            return "Select a different default first."
        case .inUse(let count):
            return "Cannot delete status; in use by \(count) themes."
        case .database(let message):
            return "Database error: \(message)"
        }
    }
}

extension DatabaseManager {
    private func mapThemeStatusError(_ message: String) -> ThemeStatusDBError {
        if message.contains("CHECK constraint failed: code") {
            return .invalidCode
        } else if message.contains("UNIQUE constraint failed: PortfolioThemeStatus.code") {
            return .duplicateCode
        } else if message.contains("UNIQUE constraint failed: PortfolioThemeStatus.name") {
            return .duplicateName
        } else if message.contains("UNIQUE constraint failed: idx_portfolio_theme_status_default") {
            return .defaultConflict
        } else {
            return .database(message: message)
        }
    }

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

    func insertPortfolioThemeStatus(code: String, name: String, colorHex: String, isDefault: Bool) -> Result<Void, ThemeStatusDBError> {
        guard sqlite3_exec(db, "BEGIN IMMEDIATE", nil, nil, nil) == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(db))
            LoggingService.shared.log("BEGIN insertPortfolioThemeStatus failed: \(msg)", type: .error, logger: .database)
            return .failure(.database(message: msg))
        }

        if isDefault {
            let rc = sqlite3_exec(db, "UPDATE PortfolioThemeStatus SET is_default = 0 WHERE is_default = 1", nil, nil, nil)
            if rc != SQLITE_OK {
                let msg = String(cString: sqlite3_errmsg(db))
                LoggingService.shared.log("Failed to clear existing default: \(msg)", type: .error, logger: .database)
                sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
                return .failure(.database(message: msg))
            }
        }

        let sql = "INSERT INTO PortfolioThemeStatus (code, name, color_hex, is_default) VALUES (?,?,?,?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(db))
            LoggingService.shared.log("prepare insertPortfolioThemeStatus failed: \(msg)", type: .error, logger: .database)
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            return .failure(.database(message: msg))
        }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, code, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, colorHex, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 4, isDefault ? 1 : 0)

        if sqlite3_step(stmt) != SQLITE_DONE {
            let msg = String(cString: sqlite3_errmsg(db))
            LoggingService.shared.log("Insert theme status failed: \(msg)", type: .error, logger: .database)
            sqlite3_finalize(stmt)
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            return .failure(mapThemeStatusError(msg))
        }
        sqlite3_finalize(stmt)

        if sqlite3_exec(db, "COMMIT", nil, nil, nil) != SQLITE_OK {
            let msg = String(cString: sqlite3_errmsg(db))
            LoggingService.shared.log("COMMIT insertPortfolioThemeStatus failed: \(msg)", type: .error, logger: .database)
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            return .failure(mapThemeStatusError(msg))
        }

        LoggingService.shared.log("Inserted theme status \(code)", type: .info, logger: .database)
        return .success(())
    }

    func updatePortfolioThemeStatus(id: Int, name: String, colorHex: String, isDefault: Bool) -> Result<Void, ThemeStatusDBError> {
        guard sqlite3_exec(db, "BEGIN IMMEDIATE", nil, nil, nil) == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(db))
            LoggingService.shared.log("BEGIN updatePortfolioThemeStatus failed: \(msg)", type: .error, logger: .database)
            return .failure(.database(message: msg))
        }

        if isDefault {
            let rc = sqlite3_exec(db, "UPDATE PortfolioThemeStatus SET is_default = 0 WHERE is_default = 1", nil, nil, nil)
            if rc != SQLITE_OK {
                let msg = String(cString: sqlite3_errmsg(db))
                LoggingService.shared.log("Failed to clear existing default: \(msg)", type: .error, logger: .database)
                sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
                return .failure(.database(message: msg))
            }
        }

        let sql = "UPDATE PortfolioThemeStatus SET name = ?, color_hex = ?, is_default = ? WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(db))
            LoggingService.shared.log("prepare updatePortfolioThemeStatus failed: \(msg)", type: .error, logger: .database)
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            return .failure(.database(message: msg))
        }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, colorHex, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 3, isDefault ? 1 : 0)
        sqlite3_bind_int(stmt, 4, Int32(id))

        if sqlite3_step(stmt) != SQLITE_DONE {
            let msg = String(cString: sqlite3_errmsg(db))
            LoggingService.shared.log("Update theme status failed id=\(id): \(msg)", type: .error, logger: .database)
            sqlite3_finalize(stmt)
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            return .failure(mapThemeStatusError(msg))
        }
        sqlite3_finalize(stmt)

        if sqlite3_exec(db, "COMMIT", nil, nil, nil) != SQLITE_OK {
            let msg = String(cString: sqlite3_errmsg(db))
            LoggingService.shared.log("COMMIT updatePortfolioThemeStatus failed: \(msg)", type: .error, logger: .database)
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            return .failure(mapThemeStatusError(msg))
        }

        LoggingService.shared.log("Updated theme status id=\(id)", type: .info, logger: .database)
        return .success(())
    }

    func deletePortfolioThemeStatus(id: Int) -> Result<Void, ThemeStatusDBError> {
        var stmt: OpaquePointer?

        var sql = "SELECT is_default FROM PortfolioThemeStatus WHERE id = ?"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW {
                if sqlite3_column_int(stmt, 0) == 1 {
                    sqlite3_finalize(stmt)
                    return .failure(.isDefault)
                }
            }
        }
        sqlite3_finalize(stmt)

        sql = "SELECT COUNT(*) FROM PortfolioTheme WHERE status_id = ?"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW {
                let count = Int(sqlite3_column_int(stmt, 0))
                if count > 0 {
                    sqlite3_finalize(stmt)
                    return .failure(.inUse(count: count))
                }
            }
        }
        sqlite3_finalize(stmt)

        sql = "DELETE FROM PortfolioThemeStatus WHERE id = ?"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_DONE {
                sqlite3_finalize(stmt)
                LoggingService.shared.log("Deleted theme status id=\(id)", type: .info, logger: .database)
                return .success(())
            } else {
                let msg = String(cString: sqlite3_errmsg(db))
                sqlite3_finalize(stmt)
                LoggingService.shared.log("Delete theme status failed: \(msg)", type: .error, logger: .database)
                return .failure(mapThemeStatusError(msg))
            }
        } else {
            let msg = String(cString: sqlite3_errmsg(db))
            sqlite3_finalize(stmt)
            LoggingService.shared.log("prepare deletePortfolioThemeStatus failed: \(msg)", type: .error, logger: .database)
            return .failure(.database(message: msg))
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
            let rc = sqlite3_exec(db, "UPDATE PortfolioThemeStatus SET is_default = 1 WHERE code = 'DRAFT'", nil, nil, nil)
            if rc == SQLITE_OK {
                LoggingService.shared.log("Default theme status was missing and restored to Draft", type: .info, logger: .database)
            } else {
                LoggingService.shared.log("Failed to restore default theme status: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            }
        }
    }
}
