import SQLite3
import Foundation

extension DatabaseManager {
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
        let sql = """
        CREATE TABLE IF NOT EXISTS ThemeAssetUpdateAttachment (
            id INTEGER PRIMARY KEY,
            theme_asset_update_id INTEGER NOT NULL
                REFERENCES PortfolioThemeAssetUpdate(id) ON DELETE CASCADE,
            attachment_id INTEGER NOT NULL
                REFERENCES Attachment(id) ON DELETE RESTRICT,
            created_at TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_taua_update ON ThemeAssetUpdateAttachment(theme_asset_update_id);
        CREATE INDEX IF NOT EXISTS idx_taua_attachment ON ThemeAssetUpdateAttachment(attachment_id);
        """
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            LoggingService.shared.log("ensureThemeAssetUpdateAttachmentTable failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
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
        let sql = "SELECT theme_asset_update_id, COUNT(*) FROM ThemeAssetUpdateAttachment WHERE theme_asset_update_id IN (\(placeholders)) GROUP BY theme_asset_update_id"
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
