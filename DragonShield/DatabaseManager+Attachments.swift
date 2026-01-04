import Foundation
import OSLog
import SQLite3

extension DatabaseManager {
    private func ensureInstrumentNoteAttachmentTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS InstrumentNoteAttachment (
            id INTEGER PRIMARY KEY,
            instrument_note_id INTEGER NOT NULL
                REFERENCES InstrumentNote(id) ON DELETE CASCADE,
            attachment_id INTEGER NOT NULL
                REFERENCES Attachment(id) ON DELETE RESTRICT,
            created_at TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_ina_note ON InstrumentNoteAttachment(instrument_note_id);
        CREATE INDEX IF NOT EXISTS idx_ina_attachment ON InstrumentNoteAttachment(attachment_id);
        """
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            LoggingService.shared.log("ensureInstrumentNoteAttachmentTable failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        migrateLegacyAttachmentsIfNeeded()
    }

    private func migrateLegacyAttachmentsIfNeeded() {
        guard tableExists("ThemeAssetUpdateAttachment") else { return }
        guard let pending = singleIntQuery("SELECT COUNT(*) FROM InstrumentNoteAttachment"), pending == 0 else { return }
        let sql = "INSERT INTO InstrumentNoteAttachment (id, instrument_note_id, attachment_id, created_at) SELECT id, theme_asset_update_id, attachment_id, created_at FROM ThemeAssetUpdateAttachment"
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            LoggingService.shared.log("migrateLegacyAttachmentsIfNeeded failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
    }

    private func singleIntQuery(_ sql: String) -> Int? {
        guard let db else { return nil }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }
        return nil
    }

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

    func ensureThemeAssetUpdateAttachmentTable() {
        ensureInstrumentNoteAttachmentTable()
    }

    func getAttachmentCounts(for updateIds: [Int]) -> [Int: Int] {
        guard let db = db else { return [:] }
        guard !updateIds.isEmpty else { return [:] }
        let placeholders = Array(repeating: "?", count: updateIds.count).joined(separator: ",")
        let sql = "SELECT theme_update_id, COUNT(*) FROM ThemeUpdateAttachment WHERE theme_update_id IN (\(placeholders)) GROUP BY theme_update_id"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare getAttachmentCounts failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
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

    func getInstrumentAttachmentCounts(for updateIds: [Int]) -> [Int: Int] {
        guard let db = db else { return [:] }
        guard !updateIds.isEmpty else { return [:] }
        let placeholders = Array(repeating: "?", count: updateIds.count).joined(separator: ",")
        let sql = "SELECT instrument_note_id, COUNT(*) FROM InstrumentNoteAttachment WHERE instrument_note_id IN (\(placeholders)) GROUP BY instrument_note_id"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare getInstrumentAttachmentCounts failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
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
