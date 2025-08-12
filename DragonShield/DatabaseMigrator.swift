import Foundation
import SQLite3

struct DatabaseMigrator {
    static func applyMigrations(db: OpaquePointer?, migrationsDirectory: URL) throws -> Int {
        guard let db else { return 0 }
        var currentVersion: Int32 = 0
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA user_version;", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                currentVersion = sqlite3_column_int(stmt, 0)
            }
        }
        sqlite3_finalize(stmt)

        let files = try FileManager.default.contentsOfDirectory(at: migrationsDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "sql" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        for file in files {
            guard let prefix = Int(file.lastPathComponent.prefix(3)) else { continue }
            if Int32(prefix) <= currentVersion { continue }
            let raw = try String(contentsOf: file, encoding: .utf8)
            guard let upRange = raw.range(of: "-- migrate:up") else { continue }
            let remainder = raw[upRange.upperBound...]
            let downRange = remainder.range(of: "-- migrate:down")
            let upSQL = downRange != nil ? String(remainder[..<downRange!.lowerBound]) : String(remainder)
            if sqlite3_exec(db, upSQL, nil, nil, nil) != SQLITE_OK {
                let msg = String(cString: sqlite3_errmsg(db))
                throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            sqlite3_exec(db, "PRAGMA user_version = \(prefix);", nil, nil, nil)
            currentVersion = Int32(prefix)
        }
        return Int(currentVersion)
    }
}
