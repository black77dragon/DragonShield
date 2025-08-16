import Foundation
import SQLite3

final class ReportDB {
    private var db: OpaquePointer?

    init(path: String) throws {
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(path, &db, flags, nil) != SQLITE_OK {
            let message = db != nil ? String(cString: sqlite3_errmsg(db)) : "Unknown error"
            throw NSError(domain: "ReportDB", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    func fetchRows(sql: String) throws -> [[String]] {
        guard let db else { return [] }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "ReportDB", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
        }
        var rows: [[String]] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String] = []
            let columnCount = sqlite3_column_count(stmt)
            for i in 0..<columnCount {
                if let cString = sqlite3_column_text(stmt, i) {
                    row.append(String(cString: cString))
                } else {
                    row.append("")
                }
            }
            rows.append(row)
        }
        return rows
    }

    func count(table: String) throws -> Int {
        let rows = try fetchRows(sql: "SELECT COUNT(*) FROM \(table)")
        if let first = rows.first, let value = Int(first.first ?? "0") {
            return value
        }
        return 0
    }
}

