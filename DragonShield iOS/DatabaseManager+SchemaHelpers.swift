import Foundation
import SQLite3

extension DatabaseManager {
    func tableHasColumn(_ table: String, column: String) -> Bool {
        guard let db else { return false }
        let sql = "PRAGMA table_info(\(table));"
        var stmt: OpaquePointer?
        var has = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let nameC = sqlite3_column_text(stmt, 1) {
                    let name = String(cString: nameC)
                    if name.caseInsensitiveCompare(column) == .orderedSame { has = true; break }
                }
            }
        }
        sqlite3_finalize(stmt)
        return has
    }
}
