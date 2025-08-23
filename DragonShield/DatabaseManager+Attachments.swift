import SQLite3
import Foundation

extension DatabaseManager {
    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    func ensureAttachmentTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS Attachment (
            id INTEGER PRIMARY KEY,
            sha256 TEXT NOT NULL UNIQUE,
            original_filename TEXT NOT NULL,
            mime TEXT NOT NULL,
            byte_size INTEGER NOT NULL,
            ext TEXT NULL,
            created_at TEXT NOT NULL,
            created_by TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_attachment_sha ON Attachment(sha256);
        """
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            LoggingService.shared.log("ensureAttachmentTable failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
    }

    func ensureThemeUpdateAttachmentTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS ThemeUpdateAttachment (
            id INTEGER PRIMARY KEY,
            theme_update_id INTEGER NOT NULL
                REFERENCES PortfolioThemeUpdate(id) ON DELETE CASCADE,
            attachment_id INTEGER NOT NULL
                REFERENCES Attachment(id) ON DELETE RESTRICT,
            created_at TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_tua_update ON ThemeUpdateAttachment(theme_update_id);
        CREATE INDEX IF NOT EXISTS idx_tua_attachment ON ThemeUpdateAttachment(attachment_id);
        """
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            LoggingService.shared.log("ensureThemeUpdateAttachmentTable failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
    }

    func upsertAttachment(sha256: String, originalFilename: String, mime: String, byteSize: Int, ext: String?, actor: String) -> Attachment? {
        guard let db = db else { return nil }
        let insertSQL = """
        INSERT OR IGNORE INTO Attachment (sha256, original_filename, mime, byte_size, ext, created_at, created_by)
        VALUES (?, ?, ?, ?, ?, STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'), ?);
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, sha256, -1, Self.sqliteTransient)
            sqlite3_bind_text(stmt, 2, originalFilename, -1, Self.sqliteTransient)
            sqlite3_bind_text(stmt, 3, mime, -1, Self.sqliteTransient)
            sqlite3_bind_int(stmt, 4, Int32(byteSize))
            if let ext = ext {
                sqlite3_bind_text(stmt, 5, ext, -1, Self.sqliteTransient)
            } else {
                sqlite3_bind_null(stmt, 5)
            }
            sqlite3_bind_text(stmt, 6, actor, -1, Self.sqliteTransient)
            if sqlite3_step(stmt) != SQLITE_DONE {
                LoggingService.shared.log("insert attachment failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            }
        }
        let selectSQL = "SELECT id, sha256, original_filename, mime, byte_size, ext, created_at, created_by FROM Attachment WHERE sha256 = ?"
        var selectStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, selectSQL, -1, &selectStmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(selectStmt) }
        sqlite3_bind_text(selectStmt, 1, sha256, -1, Self.sqliteTransient)
        guard sqlite3_step(selectStmt) == SQLITE_ROW else { return nil }
        let id = Int(sqlite3_column_int(selectStmt, 0))
        let sha = String(cString: sqlite3_column_text(selectStmt, 1))
        let name = String(cString: sqlite3_column_text(selectStmt, 2))
        let mimeOut = String(cString: sqlite3_column_text(selectStmt, 3))
        let size = Int(sqlite3_column_int(selectStmt, 4))
        let extOut = sqlite3_column_text(selectStmt, 5).map { String(cString: $0) }
        let createdAt = String(cString: sqlite3_column_text(selectStmt, 6))
        let createdBy = String(cString: sqlite3_column_text(selectStmt, 7))
        return Attachment(id: id, sha256: sha, originalFilename: name, mime: mimeOut, byteSize: size, ext: extOut, createdAt: createdAt, createdBy: createdBy)
    }
}
