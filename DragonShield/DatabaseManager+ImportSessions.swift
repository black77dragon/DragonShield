import Foundation
import SQLite3
import CryptoKit

extension DatabaseManager {
    /// Creates a new import session and returns its id.
    func startImportSession(sessionName: String, fileName: String, filePath: String, fileType: String, fileSize: Int, fileHash: String, accountId: Int?) -> Int? {
        let sql = """
            INSERT INTO ImportSessions (session_name, file_name, file_path, file_type, file_size, file_hash, account_id, import_status, started_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, 'PROCESSING', datetime('now'));
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare startImportSession: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, sessionName, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, fileName, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, filePath, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, fileType, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 5, Int32(fileSize))
        sqlite3_bind_text(stmt, 6, fileHash, -1, SQLITE_TRANSIENT)
        if let acc = accountId {
            sqlite3_bind_int(stmt, 7, Int32(acc))
        } else {
            sqlite3_bind_null(stmt, 7)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            print("❌ Failed to insert ImportSession: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        return Int(sqlite3_last_insert_rowid(db))
    }

    func completeImportSession(id: Int, totalRows: Int, successRows: Int, failedRows: Int, notes: String?) {
        let sql = """
            UPDATE ImportSessions
               SET import_status='COMPLETED', total_rows=?, successful_rows=?, failed_rows=?, processing_notes=?, completed_at=datetime('now')
             WHERE import_session_id=?;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare completeImportSession: \(String(cString: sqlite3_errmsg(db)))")
            return
        }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_int(stmt, 1, Int32(totalRows))
        sqlite3_bind_int(stmt, 2, Int32(successRows))
        sqlite3_bind_int(stmt, 3, Int32(failedRows))
        if let notes = notes {
            sqlite3_bind_text(stmt, 4, notes, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 4)
        }
        sqlite3_bind_int(stmt, 5, Int32(id))
        if sqlite3_step(stmt) != SQLITE_DONE {
            print("❌ Failed to update ImportSession: \(String(cString: sqlite3_errmsg(db)))")
        }
    }
}

extension URL {
    /// Computes the SHA256 hash of a file at this URL.
    func sha256() -> String? {
        guard let data = try? Data(contentsOf: self) else { return nil }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
