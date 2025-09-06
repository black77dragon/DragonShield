import Foundation
import SQLite3

extension DatabaseManager {
    func listTags(includeInactive: Bool = true) -> [TagRow] {
        var rows: [TagRow] = []
        guard let db else { return rows }
        let sql = includeInactive ?
        "SELECT id, code, display_name, color, sort_order, active FROM Tag ORDER BY sort_order, id" :
        "SELECT id, code, display_name, color, sort_order, active FROM Tag WHERE active = 1 ORDER BY sort_order, id"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let code = String(cString: sqlite3_column_text(stmt, 1))
                let name = String(cString: sqlite3_column_text(stmt, 2))
                let color = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
                let order = Int(sqlite3_column_int(stmt, 4))
                let active = sqlite3_column_int(stmt, 5) == 1
                rows.append(TagRow(id: id, code: code, displayName: name, color: color, sortOrder: order, active: active))
            }
        }
        return rows
    }

    func createTag(code: String, displayName: String, color: String?, sortOrder: Int, active: Bool) -> TagRow? {
        guard let db else { return nil }
        let sql = "INSERT INTO Tag(code, display_name, color, sort_order, active) VALUES(?,?,?,?,?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, code, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, displayName, -1, SQLITE_TRANSIENT)
        if let color { sqlite3_bind_text(stmt, 3, color, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 3) }
        sqlite3_bind_int(stmt, 4, Int32(sortOrder))
        sqlite3_bind_int(stmt, 5, active ? 1 : 0)
        guard sqlite3_step(stmt) == SQLITE_DONE else { return nil }
        let id = Int(sqlite3_last_insert_rowid(db))
        return TagRow(id: id, code: code, displayName: displayName, color: color, sortOrder: sortOrder, active: active)
    }

    func updateTag(id: Int, code: String?, displayName: String?, color: String?, sortOrder: Int?, active: Bool?) -> Bool {
        guard let db else { return false }
        var sets: [String] = []
        var bind: [Any?] = []
        if let code { sets.append("code = ?"); bind.append(code) }
        if let displayName { sets.append("display_name = ?"); bind.append(displayName) }
        if let color { sets.append("color = ?"); bind.append(color) }
        if let sortOrder { sets.append("sort_order = ?"); bind.append(sortOrder) }
        if let active { sets.append("active = ?"); bind.append(active ? 1 : 0) }
        guard !sets.isEmpty else { return true }
        let sql = "UPDATE Tag SET \(sets.joined(separator: ", ")), updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = ?"
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

    func deleteTag(id: Int) -> Bool {
        guard let db else { return false }
        var stmt: OpaquePointer?
        let sql = "UPDATE Tag SET active = 0, updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = ? AND active = 1"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        sqlite3_bind_int(stmt, 1, Int32(id))
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_DONE && sqlite3_changes(db) > 0
    }

    func reorderTags(idsInOrder: [Int]) -> Bool {
        guard let db else { return false }
        var ok = true
        var order = 1
        for id in idsInOrder {
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, "UPDATE Tag SET sort_order = ?, updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = ?", -1, &stmt, nil) == SQLITE_OK {
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
}

