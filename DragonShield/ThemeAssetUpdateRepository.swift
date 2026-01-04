import Foundation
import OSLog
import SQLite3

final class ThemeAssetUpdateRepository {
    private let dbManager: DatabaseManager
    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
        dbManager.ensureAttachmentTable()
        dbManager.ensureThemeAssetUpdateAttachmentTable()
    }

    @discardableResult
    func linkAttachment(updateId: Int, attachmentId: Int) -> Bool {
        guard let db = dbManager.db else { return false }
        let sql = """
        INSERT INTO InstrumentNoteAttachment (instrument_note_id, attachment_id, created_at)
        VALUES (?, ?, STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare linkAttachment failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(updateId))
        sqlite3_bind_int(stmt, 2, Int32(attachmentId))
        guard sqlite3_step(stmt) == SQLITE_DONE else { return false }
        return true
    }

    @discardableResult
    func unlinkAttachment(updateId: Int, attachmentId: Int) -> Bool {
        guard let db = dbManager.db else { return false }
        let sql = "DELETE FROM InstrumentNoteAttachment WHERE instrument_note_id = ? AND attachment_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare unlinkAttachment failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(updateId))
        sqlite3_bind_int(stmt, 2, Int32(attachmentId))
        guard sqlite3_step(stmt) == SQLITE_DONE else { return false }
        return sqlite3_changes(db) > 0
    }

    func listAttachments(updateId: Int) -> [Attachment] {
        guard let db = dbManager.db else { return [] }
        let sql = """
        SELECT a.id, a.sha256, a.original_filename, a.mime, a.byte_size, a.ext, a.created_at, a.created_by
        FROM InstrumentNoteAttachment t
        JOIN Attachment a ON a.id = t.attachment_id
        WHERE t.instrument_note_id = ?
        ORDER BY t.id
        """
        var stmt: OpaquePointer?
        var items: [Attachment] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(updateId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let sha = String(cString: sqlite3_column_text(stmt, 1))
                let name = String(cString: sqlite3_column_text(stmt, 2))
                let mime = String(cString: sqlite3_column_text(stmt, 3))
                let size = Int(sqlite3_column_int(stmt, 4))
                let ext = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
                let createdAt = String(cString: sqlite3_column_text(stmt, 6))
                let createdBy = String(cString: sqlite3_column_text(stmt, 7))
                let att = Attachment(id: id, sha256: sha, originalFilename: name, mime: mime, byteSize: size, ext: ext, createdAt: createdAt, createdBy: createdBy)
                items.append(att)
            }
        } else {
            LoggingService.shared.log("prepare listAttachments failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return items
    }
}
