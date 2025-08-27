import Foundation
import SQLite3

extension DatabaseManager {
    func ensureUpdateTypeTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS UpdateType (
            id INTEGER PRIMARY KEY,
            code TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL
        );
        """
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            LoggingService.shared.log("ensureUpdateTypeTable failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
    }

    func fetchUpdateTypes() -> [UpdateType] {
        var items: [UpdateType] = []
        let sql = "SELECT id, code, name FROM UpdateType ORDER BY id"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let code = String(cString: sqlite3_column_text(stmt, 1))
                let name = String(cString: sqlite3_column_text(stmt, 2))
                items.append(UpdateType(id: id, code: code, name: name))
            }
        } else {
            LoggingService.shared.log("fetchUpdateTypes prepare failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return items
    }

    func getUpdateType(id: Int) -> UpdateType? {
        let sql = "SELECT id, code, name FROM UpdateType WHERE id = ?"
        var stmt: OpaquePointer?
        var item: UpdateType?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let code = String(cString: sqlite3_column_text(stmt, 1))
                let name = String(cString: sqlite3_column_text(stmt, 2))
                item = UpdateType(id: id, code: code, name: name)
            }
        } else {
            LoggingService.shared.log("getUpdateType prepare failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return item
    }

    func createUpdateType(code: String, name: String) -> UpdateType? {
        let sql = "INSERT INTO UpdateType (code, name) VALUES (?, ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("createUpdateType prepare failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return nil
        }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, code, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, name, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            LoggingService.shared.log("createUpdateType step failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            sqlite3_finalize(stmt)
            return nil
        }
        sqlite3_finalize(stmt)
        let newId = Int(sqlite3_last_insert_rowid(db))
        return UpdateType(id: newId, code: code, name: name)
    }

    func updateUpdateType(id: Int, code: String?, name: String?) -> UpdateType? {
        var sets: [String] = []
        if code != nil { sets.append("code = ?") }
        if name != nil { sets.append("name = ?") }
        guard !sets.isEmpty else { return getUpdateType(id: id) }
        let sql = "UPDATE UpdateType SET \(sets.joined(separator: ", ")) WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("updateUpdateType prepare failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return nil
        }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        var idx: Int32 = 1
        if let c = code {
            sqlite3_bind_text(stmt, idx, c, -1, SQLITE_TRANSIENT); idx += 1
        }
        if let n = name {
            sqlite3_bind_text(stmt, idx, n, -1, SQLITE_TRANSIENT); idx += 1
        }
        sqlite3_bind_int(stmt, idx, Int32(id))
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            LoggingService.shared.log("updateUpdateType step failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            sqlite3_finalize(stmt)
            return nil
        }
        sqlite3_finalize(stmt)
        return getUpdateType(id: id)
    }

    func deleteUpdateType(id: Int) -> Bool {
        let sql = "DELETE FROM UpdateType WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("deleteUpdateType prepare failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        sqlite3_bind_int(stmt, 1, Int32(id))
        let ok = sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_finalize(stmt)
        return ok
    }
}
