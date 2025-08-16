import Foundation
import SQLite3

final class ReportDB {
    private var handle: OpaquePointer?

    init(path: String) throws {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let uri = "file:\(encodedPath)?mode=ro&immutable=1"
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_URI
        if sqlite3_open_v2(uri, &handle, flags, nil) != SQLITE_OK {
            let message = handle != nil ? String(cString: sqlite3_errmsg(handle)) : "Unknown error"
            throw NSError(domain: "ReportDB", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
        sqlite3_exec(handle, "PRAGMA query_only = ON;", nil, nil, nil)
    }

    deinit {
        close()
    }

    func close() {
        if let h = handle {
            sqlite3_close_v2(h)
        }
        handle = nil
    }

    func count(table: String) throws -> Int {
        guard let db = handle else {
            throw NSError(domain: "ReportDB", code: 2, userInfo: [NSLocalizedDescriptionKey: "Database not open"])
        }
        let query = "SELECT COUNT(*) FROM \(table);"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) != SQLITE_OK {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "ReportDB", code: 3, userInfo: [NSLocalizedDescriptionKey: message])
        }
        if sqlite3_step(stmt) != SQLITE_ROW {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "ReportDB", code: 4, userInfo: [NSLocalizedDescriptionKey: message])
        }
        let count = sqlite3_column_int(stmt, 0)
        return Int(count)
    }
}
