#if os(iOS)
    import Foundation
    import SQLite3

    extension DatabaseManager {
        /// Normalize a copied snapshot so it does not require a WAL file at runtime.
        /// - Sets journal_mode to DELETE and checkpoints WAL (TRUNCATE).
        /// - Returns true on success.
        static func normalizeSnapshot(at path: String) -> Bool {
            var handle: OpaquePointer?
            let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
            guard sqlite3_open_v2(path, &handle, flags, nil) == SQLITE_OK else {
                return false
            }
            defer { sqlite3_close_v2(handle) }
            // Switch journaling to DELETE so -wal is not expected
            sqlite3_exec(handle, "PRAGMA journal_mode=DELETE;", nil, nil, nil)
            // Ensure no pending WAL frames
            sqlite3_exec(handle, "PRAGMA wal_checkpoint(TRUNCATE);", nil, nil, nil)
            return true
        }
    }
#endif
