import Foundation
import SQLite3

extension DatabaseManager {
    func listAlertTriggerTypes(includeInactive: Bool = true) -> [AlertTriggerTypeRow] {
        var rows: [AlertTriggerTypeRow] = []
        guard let db else { return rows }
        let hasRequiresDate = hasRequiresDateColumn()
        let column = hasRequiresDate ? "requires_date" : "0 AS requires_date"
        let sql = includeInactive ?
        "SELECT id, code, display_name, description, sort_order, active, \(column) FROM AlertTriggerType ORDER BY sort_order, id" :
        "SELECT id, code, display_name, description, sort_order, active, \(column) FROM AlertTriggerType WHERE active = 1 ORDER BY sort_order, id"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let code = String(cString: sqlite3_column_text(stmt, 1))
                let name = String(cString: sqlite3_column_text(stmt, 2))
                let desc = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
                let order = Int(sqlite3_column_int(stmt, 4))
                let active = sqlite3_column_int(stmt, 5) == 1
                let requiresDate = sqlite3_column_int(stmt, 6) == 1
                rows.append(AlertTriggerTypeRow(id: id, code: code, displayName: name, description: desc, sortOrder: order, active: active, requiresDate: requiresDate))
            }
        }
        return rows
    }

    func createAlertTriggerType(code: String, displayName: String, description: String?, sortOrder: Int, active: Bool, requiresDate: Bool) -> AlertTriggerTypeRow? {
        guard let db else { return nil }
        let sql = "INSERT INTO AlertTriggerType(code, display_name, description, sort_order, active, requires_date) VALUES(?,?,?,?,?,?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, code, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, displayName, -1, SQLITE_TRANSIENT)
        if let description { sqlite3_bind_text(stmt, 3, description, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 3) }
        sqlite3_bind_int(stmt, 4, Int32(sortOrder))
        sqlite3_bind_int(stmt, 5, active ? 1 : 0)
        sqlite3_bind_int(stmt, 6, requiresDate ? 1 : 0)
        guard sqlite3_step(stmt) == SQLITE_DONE else { return nil }
        let id = Int(sqlite3_last_insert_rowid(db))
        return AlertTriggerTypeRow(id: id, code: code, displayName: displayName, description: description, sortOrder: sortOrder, active: active, requiresDate: requiresDate)
    }

    func updateAlertTriggerType(id: Int, code: String?, displayName: String?, description: String?, sortOrder: Int?, active: Bool?, requiresDate: Bool? = nil) -> Bool {
        guard let db else { return false }
        var sets: [String] = []
        var bind: [Any?] = []
        if let code { sets.append("code = ?"); bind.append(code) }
        if let displayName { sets.append("display_name = ?"); bind.append(displayName) }
        if let description { sets.append("description = ?"); bind.append(description) }
        if let sortOrder { sets.append("sort_order = ?"); bind.append(sortOrder) }
        if let active { sets.append("active = ?"); bind.append(active ? 1 : 0) }
        if let requiresDate { sets.append("requires_date = ?"); bind.append(requiresDate ? 1 : 0) }
        guard !sets.isEmpty else { return true }
        let sql = "UPDATE AlertTriggerType SET \(sets.joined(separator: ", ")), updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        var idx: Int32 = 1
        for v in bind {
            if let s = v as? String { sqlite3_bind_text(stmt, idx, s, -1, SQLITE_TRANSIENT) }
            else if let i = v as? Int { sqlite3_bind_int(stmt, idx, Int32(i)) }
            else if let i = v as? Int32 { sqlite3_bind_int(stmt, idx, i) }
            else if let i = v as? Int64 { sqlite3_bind_int64(stmt, idx, i) }
            else { sqlite3_bind_null(stmt, idx) }
            idx += 1
        }
        sqlite3_bind_int(stmt, idx, Int32(id))
        return sqlite3_step(stmt) == SQLITE_DONE && sqlite3_changes(db) > 0
    }

    func deleteAlertTriggerType(id: Int) -> Bool {
        guard let db else { return false }
        var stmt: OpaquePointer?
        let sql = "UPDATE AlertTriggerType SET active = 0, updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = ? AND active = 1"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        sqlite3_bind_int(stmt, 1, Int32(id))
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_DONE && sqlite3_changes(db) > 0
    }

    func reorderAlertTriggerTypes(idsInOrder: [Int]) -> Bool {
        guard let db else { return false }
        var ok = true
        var order = 1
        for id in idsInOrder {
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, "UPDATE AlertTriggerType SET sort_order = ?, updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = ?", -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(order))
                sqlite3_bind_int(stmt, 2, Int32(id))
                ok = ok && (sqlite3_step(stmt) == SQLITE_DONE)
            } else {
                ok = false
            }
            sqlite3_finalize(stmt)
            order += 1
        }
        return ok
    }

    private func hasRequiresDateColumn() -> Bool {
        guard let db else { return false }
        var stmt: OpaquePointer?
        var found = false
        if sqlite3_prepare_v2(db, "PRAGMA table_info(AlertTriggerType)", -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let namePtr = sqlite3_column_text(stmt, 1) {
                    let name = String(cString: namePtr)
                    if name == "requires_date" {
                        found = true
                        break
                    }
                }
            }
        }
        sqlite3_finalize(stmt)
        return found
    }
}
