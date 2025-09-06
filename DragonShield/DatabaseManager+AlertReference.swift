import SQLite3
import Foundation

extension DatabaseManager {
    func ensureAlertReferenceTables() {
        guard let db else { return }
        let sql = """
        CREATE TABLE IF NOT EXISTS AlertTriggerType (
          id           INTEGER PRIMARY KEY,
          code         TEXT    NOT NULL UNIQUE,
          display_name TEXT    NOT NULL,
          description  TEXT    NULL,
          sort_order   INTEGER NOT NULL DEFAULT 0,
          active       INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
          created_at   TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
          updated_at   TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
        );
        CREATE UNIQUE INDEX IF NOT EXISTS idx_alert_trigger_type_code ON AlertTriggerType(code);
        CREATE INDEX IF NOT EXISTS idx_alert_trigger_type_active ON AlertTriggerType(active, sort_order);

        CREATE TABLE IF NOT EXISTS Tag (
          id           INTEGER PRIMARY KEY,
          code         TEXT    NOT NULL UNIQUE,
          display_name TEXT    NOT NULL,
          color        TEXT    NULL,
          sort_order   INTEGER NOT NULL DEFAULT 0,
          active       INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
          created_at   TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
          updated_at   TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
        );
        CREATE UNIQUE INDEX IF NOT EXISTS idx_tag_code ON Tag(code);
        CREATE INDEX IF NOT EXISTS idx_tag_active ON Tag(active, sort_order);
        """
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            LoggingService.shared.log("ensureAlertReferenceTables failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }

        // Seed defaults if empty
        var countStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM AlertTriggerType", -1, &countStmt, nil) == SQLITE_OK {
            if sqlite3_step(countStmt) == SQLITE_ROW {
                let count = Int(sqlite3_column_int(countStmt, 0))
                sqlite3_finalize(countStmt)
                if count == 0 {
                    let seed = "INSERT OR IGNORE INTO AlertTriggerType (code, display_name, description, sort_order, active) VALUES (?,?,?,?,?)"
                    let types: [(String,String,String,Int,Int)] = [
                        ("date","Date","Fires on a specific date; supports warnings and recurrence (later).",1,1),
                        ("price","Price Level","Fires when price crosses a threshold or exits a band.",2,1),
                        ("holding_abs","Holding Value (Abs)","Fires when exposure exceeds/falls below an absolute value.",3,1),
                        ("holding_pct","Holding Share (%)","Fires when holding share (%) crosses a threshold.",4,1)
                    ]
                    for t in types {
                        var stmt: OpaquePointer?
                        if sqlite3_prepare_v2(db, seed, -1, &stmt, nil) == SQLITE_OK {
                            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                            sqlite3_bind_text(stmt, 1, t.0, -1, SQLITE_TRANSIENT)
                            sqlite3_bind_text(stmt, 2, t.1, -1, SQLITE_TRANSIENT)
                            sqlite3_bind_text(stmt, 3, t.2, -1, SQLITE_TRANSIENT)
                            sqlite3_bind_int(stmt, 4, Int32(t.3))
                            sqlite3_bind_int(stmt, 5, Int32(t.4))
                            _ = sqlite3_step(stmt)
                        }
                        sqlite3_finalize(stmt)
                    }
                }
            } else {
                sqlite3_finalize(countStmt)
            }
        }
    }
}

