// DragonShield/DatabaseManager+Configuration.swift
// MARK: - Version 1.2
// MARK: - History
// - 1.0 -> 1.1: Enhanced loadConfiguration to populate new @Published vars. Added updateConfiguration method.
// - 1.1 -> 1.2: Load db_version configuration and expose via dbVersion property.
// - Initial creation: Refactored from DatabaseManager.swift.

import SQLite3
import Foundation

fileprivate let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

extension DatabaseManager {
    
    func loadConfiguration() {
        // Added new keys to fetch
        let query = """
            SELECT key, value, data_type FROM Configuration
            WHERE key IN (
                'base_currency', 'as_of_date', 'decimal_precision', 'auto_fx_update',
                'default_timezone', 'table_row_spacing', 'table_row_padding', 'db_version',
                'production_db_path', 'test_db_path'
            );
        """
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let keyPtr = sqlite3_column_text(statement, 0),
                      let valuePtr = sqlite3_column_text(statement, 1)
                      // let dataTypePtr = sqlite3_column_text(statement, 2) // For future use if needed
                else { continue }

                let key = String(cString: keyPtr)
                let value = String(cString: valuePtr)
                // let dataType = String(cString: dataTypePtr)
                                
                DispatchQueue.main.async { // Ensure @Published vars are updated on the main thread
                    switch key {
                    case "base_currency":
                        self.baseCurrency = value
                    case "as_of_date":
                        if let date = DateFormatter.iso8601DateOnly.date(from: value) {
                            self.asOfDate = date
                        }
                    case "decimal_precision":
                        self.decimalPrecision = Int(value) ?? 4
                    case "auto_fx_update":
                        self.autoFxUpdate = value.lowercased() == "true"
                    case "default_timezone":
                        self.defaultTimeZone = value
                    case "table_row_spacing":
                        self.tableRowSpacing = Double(value) ?? 1.0
                    case "table_row_padding":
                        self.tableRowPadding = Double(value) ?? 12.0
                    case "db_version":
                        self.dbVersion = value
                        print("📦 Database version loaded: \(value)")
                    case "production_db_path":
                        self.productionDBPath = value
                    case "test_db_path":
                        self.testDBPath = value
                    default:
                        print("ℹ️ Unhandled configuration key loaded: \(key)")
                    }
                }
            }
        } else {
            print("❌ Failed to prepare loadConfiguration: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        print("⚙️ Configuration loaded/reloaded.")
    }
    
    func updateConfiguration(key: String, value: String) -> Bool {
        let query = "UPDATE Configuration SET value = ?, updated_at = CURRENT_TIMESTAMP WHERE key = ?;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare updateConfiguration for key '\(key)': \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        
        sqlite3_bind_text(statement, 1, (value as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, (key as NSString).utf8String, -1, SQLITE_TRANSIENT)
        
        let success = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if success {
            print("✅ Configuration updated for key '\(key)' to value '\(value)'")
            // Reload configuration to update @Published properties
            // This ensures that if one part of the app updates config, others see it if observing DatabaseManager
            loadConfiguration()
        } else {
            print("❌ Failed to update configuration for key '\(key)': \(String(cString: sqlite3_errmsg(db)))")
        }
        return success
    }

    func updatePathConfiguration(key: String, value: String) -> Bool {
        guard sqlite3_exec(db, "BEGIN TRANSACTION;", nil, nil, nil) == SQLITE_OK else {
            print("❌ Failed to begin transaction: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }

        // Ensure a row exists for this configuration key
        var insert: OpaquePointer?
        let desc = key == "production_db_path" ? "Filesystem path for production DB" : "Filesystem path for test DB"
        if sqlite3_prepare_v2(db, "INSERT OR IGNORE INTO Configuration (key, value, data_type, description) VALUES (?, '', 'string', ?);", -1, &insert, nil) == SQLITE_OK {
            sqlite3_bind_text(insert, 1, (key as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(insert, 2, (desc as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_step(insert)
        }
        sqlite3_finalize(insert)

        let query = "UPDATE Configuration SET value = ?, updated_at = CURRENT_TIMESTAMP WHERE key = ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare path update for key '\(key)': \(String(cString: sqlite3_errmsg(db)))")
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            return false
        }

        sqlite3_bind_text(statement, 1, (value as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, (key as NSString).utf8String, -1, SQLITE_TRANSIENT)

        let stepResult = sqlite3_step(statement)
        sqlite3_finalize(statement)
        guard stepResult == SQLITE_DONE else {
            print("❌ Failed to update path for key '\(key)': \(String(cString: sqlite3_errmsg(db)))")
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            return false
        }

        if sqlite3_exec(db, "COMMIT;", nil, nil, nil) == SQLITE_OK {
            loadConfiguration()
            return true
        } else {
            print("❌ Failed to commit path update for key '\(key)': \(String(cString: sqlite3_errmsg(db)))")
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            return false
        }
    }

    func forceReloadData() { // This mainly reloads configuration currently
        print("🔄 Force reloading database configuration...")
        loadConfiguration()
        NotificationCenter.default.post(name: NSNotification.Name("DatabaseForceReloaded"), object: nil)
    }
}
