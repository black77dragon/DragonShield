import Foundation
import SQLite3

extension DatabaseManager {
    func ensureLinkTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS Link (
            id INTEGER PRIMARY KEY,
            normalized_url TEXT NOT NULL UNIQUE,
            raw_url TEXT NOT NULL,
            title TEXT NULL,
            created_at TEXT NOT NULL,
            created_by TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_link_normalized ON Link(normalized_url);
        """
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            LoggingService.shared.log("ensureLinkTable failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
    }

    func ensureThemeUpdateLinkTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS ThemeUpdateLink (
            id INTEGER PRIMARY KEY,
            theme_update_id INTEGER NOT NULL
                REFERENCES PortfolioThemeUpdate(id) ON DELETE CASCADE,
            link_id INTEGER NOT NULL
                REFERENCES Link(id) ON DELETE RESTRICT,
            created_at TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_tul_update ON ThemeUpdateLink(theme_update_id);
        CREATE INDEX IF NOT EXISTS idx_tul_link ON ThemeUpdateLink(link_id);
        """
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            LoggingService.shared.log("ensureThemeUpdateLinkTable failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
    }

    func getLinkCounts(for updateIds: [Int]) -> [Int: Int] {
        guard let db = db else { return [:] }
        guard !updateIds.isEmpty else { return [:] }
        let placeholders = Array(repeating: "?", count: updateIds.count).joined(separator: ",")
        let sql = "SELECT theme_update_id, COUNT(*) FROM ThemeUpdateLink WHERE theme_update_id IN (\(placeholders)) GROUP BY theme_update_id"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare getLinkCounts failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return [:]
        }
        defer { sqlite3_finalize(stmt) }
        for (idx, id) in updateIds.enumerated() {
            sqlite3_bind_int(stmt, Int32(idx + 1), Int32(id))
        }
        var result: [Int: Int] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let updateId = Int(sqlite3_column_int(stmt, 0))
            let count = Int(sqlite3_column_int(stmt, 1))
            result[updateId] = count
        }
        return result
    }
}
