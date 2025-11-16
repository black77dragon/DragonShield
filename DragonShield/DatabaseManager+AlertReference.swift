import Foundation
import SQLite3

extension DatabaseManager {
    func ensureAlertReferenceTables() {
        guard let db else { return }
        let sql = """
        CREATE TABLE IF NOT EXISTS AlertTriggerType (
          id             INTEGER PRIMARY KEY,
          code           TEXT    NOT NULL UNIQUE,
          display_name   TEXT    NOT NULL,
          description    TEXT    NULL,
          sort_order     INTEGER NOT NULL DEFAULT 0,
          active         INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
          requires_date  INTEGER NOT NULL DEFAULT 0 CHECK (requires_date IN (0,1)),
          created_at     TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
          updated_at     TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
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
        ensureRequiresDateColumn()
        var countStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM AlertTriggerType", -1, &countStmt, nil) == SQLITE_OK {
            if sqlite3_step(countStmt) == SQLITE_ROW {
                sqlite3_finalize(countStmt)
                let seed = "INSERT OR IGNORE INTO AlertTriggerType (code, display_name, description, sort_order, active, requires_date) VALUES (?,?,?,?,?,?)"
                let types: [(String, String, String, Int, Int, Int)] = [
                    ("date", "Date", "Fires on a specific date; supports warnings and recurrence (later).", 1, 1, 1),
                    ("price", "Price Level", "Fires when price crosses a threshold or exits a band.", 2, 1, 0),
                    ("holding_abs", "Holding Value (Abs)", "Fires when exposure exceeds/falls below an absolute value.", 3, 1, 0),
                    ("holding_pct", "Holding Share (%)", "Fires when holding share (%) crosses a threshold.", 4, 1, 0),
                    ("calendar_event", "Calendar Event", "Fires around scheduled macro/company events (earnings, meetings).", 5, 1, 1),
                    ("macro_indicator_threshold", "Macro Indicator Threshold", "Fires when a macro series crosses a configured threshold.", 6, 1, 1),
                    ("news_keyword", "News Keyword", "Fires when tagged news mentions configured keywords or entities.", 7, 1, 0),
                    ("volatility", "Volatility", "Fires when realised vs implied volatility deviates from bounds.", 8, 1, 0),
                    ("liquidity", "Liquidity", "Fires when liquidity metrics drop below configured levels.", 9, 1, 0),
                    ("scripted", "Scripted", "Runs custom expressions over data series and fires on true results.", 10, 1, 0),
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
                        sqlite3_bind_int(stmt, 6, Int32(t.5))
                        _ = sqlite3_step(stmt)
                    }
                    sqlite3_finalize(stmt)
                }
            } else {
                sqlite3_finalize(countStmt)
            }
        }
    }

    private func ensureRequiresDateColumn() {
        guard let db else { return }
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA table_info(AlertTriggerType)", -1, &stmt, nil) == SQLITE_OK {
            var hasColumn = false
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let namePtr = sqlite3_column_text(stmt, 1) {
                    let name = String(cString: namePtr)
                    if name == "requires_date" {
                        hasColumn = true
                        break
                    }
                }
            }
            sqlite3_finalize(stmt)
            if !hasColumn {
                if sqlite3_exec(db, "ALTER TABLE AlertTriggerType ADD COLUMN requires_date INTEGER NOT NULL DEFAULT 0 CHECK (requires_date IN (0,1))", nil, nil, nil) == SQLITE_OK {
                    _ = sqlite3_exec(db, "UPDATE AlertTriggerType SET requires_date = 1 WHERE code IN ('date','calendar_event','macro_indicator_threshold')", nil, nil, nil)
                }
            }
        } else {
            sqlite3_finalize(stmt)
        }
    }
}
