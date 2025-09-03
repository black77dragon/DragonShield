import Foundation
import SQLite3

extension DatabaseManager {
    /// Reopens the manager to point at an external database file in read-only mode.
    /// Useful for the iOS app to open a snapshot exported from macOS.
    /// - Returns: true on success
    @discardableResult
    func openReadOnly(at externalPath: String) -> Bool {
        closeConnection()
        self.dbFilePath = externalPath
        self.dbCreated = nil
        self.dbModified = nil
        self.dbPath = externalPath
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(dbPath, &db, flags, nil) == SQLITE_OK {
            // Foreign keys pragma is harmless if ignored in RO mode
            sqlite3_exec(db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
            let version = loadConfiguration()
            DispatchQueue.main.async { self.dbVersion = version }
            // Update file metadata for display
            do {
                let attrs = try FileManager.default.attributesOfItem(atPath: dbPath)
                DispatchQueue.main.async {
                    self.dbFilePath = self.dbPath
                    if let size = attrs[.size] as? NSNumber { self.dbFileSize = size.int64Value }
                    self.dbCreated = attrs[.creationDate] as? Date
                    self.dbModified = attrs[.modificationDate] as? Date
                }
            } catch { }
            return true
        } else {
            let msg = db != nil ? String(cString: sqlite3_errmsg(db)) : "Unknown error"
            print("❌ Failed to open read-only DB at \(dbPath): \(msg)")
            return false
        }
    }
}

