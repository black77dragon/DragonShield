#if os(iOS)
import SQLite3
import Foundation

extension DatabaseManager {
    func tableExistsIOS(_ name: String) -> Bool {
        var stmt: OpaquePointer?
        let sql = "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1"
        var exists = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, name, -1, SQLITE_TRANSIENT)
            exists = (sqlite3_step(stmt) == SQLITE_ROW)
        }
        sqlite3_finalize(stmt)
        return exists
    }

    func fetchPositionReportsSafe() -> [PositionReportData] {
        // If snapshot lacks any of these tables, return an empty set gracefully
        let required = [
            "PositionReports", "Accounts", "Institutions", "Instruments", "AssetSubClasses", "AssetClasses"
        ]
        for t in required {
            if !tableExistsIOS(t) {
                #if DEBUG
                LoggingService.shared.log("[iOS] Skipping fetchPositionReports — missing table: \(t)", type: .info, logger: .database)
                #endif
                return []
            }
        }
        return fetchPositionReports()
    }
}
#endif

