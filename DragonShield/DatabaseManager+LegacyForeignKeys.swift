import Foundation
import OSLog
import SQLite3

extension DatabaseManager {
    func repairLegacyPortfolioThemeForeignKeys() {
        let tables = [
            "PortfolioThemeAsset",
            "PortfolioThemeUpdate",
            "PortfolioThemeAssetUpdate",
            "InstrumentNote",
        ]
        for table in tables {
            _ = rebuildTableIfNeeded(table: table, oldReference: "PortfolioTheme_old", newReference: "PortfolioTheme")
        }
    }

    private func rebuildTableIfNeeded(table: String, oldReference: String, newReference: String) -> Bool {
        guard let db else { return false }
        guard tableExists(table) else { return false }
        guard tableHasForeignKey(table, references: oldReference) else { return false }

        guard let createSQL = fetchCreateTableSQL(table) else {
            LoggingService.shared.log("legacy FK fix failed: missing create SQL for \(table)", type: .error, logger: .database)
            return false
        }

        let oldTable = "\(table)_fkfix_old"
        guard !tableExists(oldTable) else {
            LoggingService.shared.log("legacy FK fix skipped: temp table exists \(oldTable)", type: .warning, logger: .database)
            return false
        }

        let fixedCreateSQL = replaceTableReference(in: createSQL, from: oldReference, to: newReference)
        let indexSQLs = fetchIndexSQLs(table)
        let triggerSQLs = fetchTriggerSQLs(table)
        let columns = fetchTableColumns(table)
        guard !columns.isEmpty else {
            LoggingService.shared.log("legacy FK fix failed: no columns found for \(table)", type: .error, logger: .database)
            return false
        }

        if sqlite3_exec(db, "PRAGMA foreign_keys=OFF;", nil, nil, nil) != SQLITE_OK {
            LoggingService.shared.log("legacy FK fix failed: pragma OFF \(table): \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        if sqlite3_exec(db, "BEGIN IMMEDIATE;", nil, nil, nil) != SQLITE_OK {
            LoggingService.shared.log("legacy FK fix failed: begin \(table): \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            _ = sqlite3_exec(db, "PRAGMA foreign_keys=ON;", nil, nil, nil)
            return false
        }

        let renameSQL = "ALTER TABLE \"\(table)\" RENAME TO \"\(oldTable)\";"
        if sqlite3_exec(db, renameSQL, nil, nil, nil) != SQLITE_OK {
            LoggingService.shared.log("legacy FK fix failed: rename \(table): \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            _ = sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            _ = sqlite3_exec(db, "PRAGMA foreign_keys=ON;", nil, nil, nil)
            return false
        }

        if sqlite3_exec(db, fixedCreateSQL, nil, nil, nil) != SQLITE_OK {
            LoggingService.shared.log("legacy FK fix failed: recreate \(table): \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            _ = sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            _ = sqlite3_exec(db, "PRAGMA foreign_keys=ON;", nil, nil, nil)
            return false
        }

        let columnList = columns.map { "\"\($0)\"" }.joined(separator: ", ")
        let copySQL = "INSERT INTO \"\(table)\" (\(columnList)) SELECT \(columnList) FROM \"\(oldTable)\";"
        if sqlite3_exec(db, copySQL, nil, nil, nil) != SQLITE_OK {
            LoggingService.shared.log("legacy FK fix failed: copy \(table): \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            _ = sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            _ = sqlite3_exec(db, "PRAGMA foreign_keys=ON;", nil, nil, nil)
            return false
        }

        let dropSQL = "DROP TABLE \"\(oldTable)\";"
        if sqlite3_exec(db, dropSQL, nil, nil, nil) != SQLITE_OK {
            LoggingService.shared.log("legacy FK fix failed: drop \(table): \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            _ = sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            _ = sqlite3_exec(db, "PRAGMA foreign_keys=ON;", nil, nil, nil)
            return false
        }

        for sql in indexSQLs {
            if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
                LoggingService.shared.log("legacy FK fix failed: index \(table): \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
                _ = sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                _ = sqlite3_exec(db, "PRAGMA foreign_keys=ON;", nil, nil, nil)
                return false
            }
        }

        for sql in triggerSQLs {
            if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
                LoggingService.shared.log("legacy FK fix failed: trigger \(table): \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
                _ = sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                _ = sqlite3_exec(db, "PRAGMA foreign_keys=ON;", nil, nil, nil)
                return false
            }
        }

        if sqlite3_exec(db, "COMMIT;", nil, nil, nil) != SQLITE_OK {
            LoggingService.shared.log("legacy FK fix failed: commit \(table): \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            _ = sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            _ = sqlite3_exec(db, "PRAGMA foreign_keys=ON;", nil, nil, nil)
            return false
        }

        _ = sqlite3_exec(db, "PRAGMA foreign_keys=ON;", nil, nil, nil)
        LoggingService.shared.log("legacy FK fix applied: \(table)", type: .info, logger: .database)
        return true
    }

    private func fetchCreateTableSQL(_ table: String) -> String? {
        guard let db else { return nil }
        let sql = "SELECT sql FROM sqlite_master WHERE type='table' AND name=?;"
        var stmt: OpaquePointer?
        var result: String?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, table, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW, let text = sqlite3_column_text(stmt, 0) {
                result = String(cString: text)
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    private func fetchIndexSQLs(_ table: String) -> [String] {
        guard let db else { return [] }
        let sql = "SELECT sql FROM sqlite_master WHERE type='index' AND tbl_name=? AND sql IS NOT NULL;"
        var stmt: OpaquePointer?
        var rows: [String] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, table, -1, SQLITE_TRANSIENT)
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let text = sqlite3_column_text(stmt, 0) {
                    rows.append(String(cString: text))
                }
            }
        }
        sqlite3_finalize(stmt)
        return rows
    }

    private func fetchTriggerSQLs(_ table: String) -> [String] {
        guard let db else { return [] }
        let sql = "SELECT sql FROM sqlite_master WHERE type='trigger' AND tbl_name=? AND sql IS NOT NULL;"
        var stmt: OpaquePointer?
        var rows: [String] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, table, -1, SQLITE_TRANSIENT)
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let text = sqlite3_column_text(stmt, 0) {
                    rows.append(String(cString: text))
                }
            }
        }
        sqlite3_finalize(stmt)
        return rows
    }

    private func fetchTableColumns(_ table: String) -> [String] {
        guard let db else { return [] }
        let sql = "PRAGMA table_info(\(table));"
        var stmt: OpaquePointer?
        var columns: [String] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let nameC = sqlite3_column_text(stmt, 1) {
                    columns.append(String(cString: nameC))
                }
            }
        }
        sqlite3_finalize(stmt)
        return columns
    }

    private func replaceTableReference(in sql: String, from oldRef: String, to newRef: String) -> String {
        return sql
            .replacingOccurrences(of: "\"\(oldRef)\"", with: "\"\(newRef)\"")
            .replacingOccurrences(of: oldRef, with: newRef)
    }
}
