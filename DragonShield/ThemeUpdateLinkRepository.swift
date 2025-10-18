import Foundation
import SQLite3

final class ThemeUpdateLinkRepository {
    private let dbManager: DatabaseManager
    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
        dbManager.ensureLinkTable()
        dbManager.ensureThemeUpdateLinkTable()
    }

    @discardableResult
    func link(updateId: Int, linkId: Int) -> Bool {
        guard let db = dbManager.db else { return false }
        let sql = """
        INSERT INTO ThemeUpdateLink (theme_update_id, link_id, created_at)
        VALUES (?, ?, STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare link failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(updateId))
        sqlite3_bind_int(stmt, 2, Int32(linkId))
        guard sqlite3_step(stmt) == SQLITE_DONE else { return false }
        return true
    }

    @discardableResult
    func unlink(updateId: Int, linkId: Int) -> Bool {
        guard let db = dbManager.db else { return false }
        let sql = "DELETE FROM ThemeUpdateLink WHERE theme_update_id = ? AND link_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare unlink failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(updateId))
        sqlite3_bind_int(stmt, 2, Int32(linkId))
        guard sqlite3_step(stmt) == SQLITE_DONE else { return false }
        return sqlite3_changes(db) > 0
    }

    func listLinks(updateId: Int) -> [Link] {
        guard let db = dbManager.db else { return [] }
        let sql = """
        SELECT l.id, l.normalized_url, l.raw_url, l.title, l.created_at, l.created_by
        FROM ThemeUpdateLink t
        JOIN Link l ON l.id = t.link_id
        WHERE t.theme_update_id = ?
        ORDER BY t.id
        """
        var stmt: OpaquePointer?
        var items: [Link] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(updateId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let normalized = String(cString: sqlite3_column_text(stmt, 1))
                let raw = String(cString: sqlite3_column_text(stmt, 2))
                let title = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
                let createdAt = String(cString: sqlite3_column_text(stmt, 4))
                let createdBy = String(cString: sqlite3_column_text(stmt, 5))
                let link = Link(id: id, normalizedURL: normalized, rawURL: raw, title: title, createdAt: createdAt, createdBy: createdBy)
                items.append(link)
            }
        } else {
            LoggingService.shared.log("prepare listLinks failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return items
    }
}
