// DragonShield/DatabaseManager+PortfolioThemeStatus.swift

// MARK: - Version 1.1

// MARK: - History

// - Initial creation: CRUD helpers for PortfolioThemeStatus with default enforcement.
// - 1.1: Return detailed errors and support deletion of unused statuses.

import Foundation
import SQLite3
import os

#if os(iOS)
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
            return "Code is invalid. Use A-Z, 0-9, _ (2-10), starting with a letter."
        case .duplicateCode:
            return "A status with this Code already exists."
        case .duplicateName:
            return "A status with this Name already exists."
        case .defaultConflict:
            return "Could not set default. Please retry."
        case .isDefault:
            return "Select a different default first."
        case let .inUse(count):
            return "Cannot delete status; in use by \(count) themes."
        case let .database(message):
            return "Database error: \(message)"
        }
    }
}
#endif

#if os(iOS)
extension DatabaseManager {
    func fetchPortfolioThemeStatuses() -> [PortfolioThemeStatus] {
        var items: [PortfolioThemeStatus] = []
        guard let db else { return items }
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
            LoggingService.shared.log("Failed to prepare fetchPortfolioThemeStatuses (iOS): \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return items
    }

    func insertPortfolioThemeStatus(code: String, name: String, colorHex: String, isDefault: Bool) -> Result<Void, ThemeStatusDBError> {
        .failure(.database(message: "Read-only on iOS"))
    }

    func updatePortfolioThemeStatus(id: Int, name: String, colorHex: String, isDefault: Bool) -> Result<Void, ThemeStatusDBError> {
        .failure(.database(message: "Read-only on iOS"))
    }

    func deletePortfolioThemeStatus(id: Int) -> Result<Void, ThemeStatusDBError> {
        .failure(.database(message: "Read-only on iOS"))
    }

    func setDefaultThemeStatus(id: Int) {}

    func ensurePortfolioThemeStatusDefault() {}
}
#else
extension DatabaseManager {
    func fetchPortfolioThemeStatuses() -> [PortfolioThemeStatus] {
        PortfolioThemeStatusRepository(connection: databaseConnection).fetchPortfolioThemeStatuses()
    }

    func insertPortfolioThemeStatus(code: String, name: String, colorHex: String, isDefault: Bool) -> Result<Void, ThemeStatusDBError> {
        PortfolioThemeStatusRepository(connection: databaseConnection)
            .insertPortfolioThemeStatus(code: code, name: name, colorHex: colorHex, isDefault: isDefault)
    }

    func updatePortfolioThemeStatus(id: Int, name: String, colorHex: String, isDefault: Bool) -> Result<Void, ThemeStatusDBError> {
        PortfolioThemeStatusRepository(connection: databaseConnection)
            .updatePortfolioThemeStatus(id: id, name: name, colorHex: colorHex, isDefault: isDefault)
    }

    func deletePortfolioThemeStatus(id: Int) -> Result<Void, ThemeStatusDBError> {
        PortfolioThemeStatusRepository(connection: databaseConnection).deletePortfolioThemeStatus(id: id)
    }

    func setDefaultThemeStatus(id: Int) {
        PortfolioThemeStatusRepository(connection: databaseConnection).setDefaultThemeStatus(id: id)
    }

    func ensurePortfolioThemeStatusDefault() {
        PortfolioThemeStatusRepository(connection: databaseConnection).ensurePortfolioThemeStatusDefault()
    }
}
#endif
