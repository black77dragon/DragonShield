import Foundation
import SQLite3
import CryptoKit

extension DatabaseManager {
    /// Creates a new import session and returns its id.
    func startImportSession(sessionName: String, fileName: String, filePath: String, fileType: String, fileSize: Int, fileHash: String, institutionId: Int?) -> Int? {
        let sql = """
            INSERT INTO ImportSessions (session_name, file_name, file_path, file_type, file_size, file_hash, institution_id, import_status, started_at)
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
        if let inst = institutionId {
            sqlite3_bind_int(stmt, 7, Int32(inst))
        } else {
            sqlite3_bind_null(stmt, 7)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            print("❌ Failed to insert ImportSession: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        return Int(sqlite3_last_insert_rowid(db))
    }

    /// Returns true if a session with the given name already exists.
    private func importSessionExists(name: String) -> Bool {
        let query = "SELECT 1 FROM ImportSessions WHERE session_name=? LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare importSessionExists: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, name, -1, nil)
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    /// Generates a unique session name by appending an incrementing suffix if needed.
    func nextImportSessionName(base: String) -> String {
        var name = base
        var counter = 0
        while importSessionExists(name: name) {
            counter += 1
            name = "\(base) (\(counter))"
        }
        return name
    }

    func completeImportSession(id: Int, totalRows: Int, successRows: Int, failedRows: Int, duplicateRows: Int, notes: String?) {
        let sql = """
            UPDATE ImportSessions
               SET import_status='COMPLETED', total_rows=?, successful_rows=?, failed_rows=?, duplicate_rows=?, processing_notes=?, completed_at=datetime('now')
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
        sqlite3_bind_int(stmt, 4, Int32(duplicateRows))
        if let notes = notes {
            sqlite3_bind_text(stmt, 5, notes, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 5)
        }
        sqlite3_bind_int(stmt, 6, Int32(id))
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
