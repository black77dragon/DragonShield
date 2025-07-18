// DragonShield/DatabaseManager+Configuration.swift
// MARK: - Version 1.2
// MARK: - History
// - 1.0 -> 1.1: Enhanced loadConfiguration to populate new @Published vars. Added updateConfiguration method.
// - 1.1 -> 1.2: Load db_version configuration and expose via dbVersion property.
// - Initial creation: Refactored from DatabaseManager.swift.

import SQLite3
import Foundation

extension DatabaseManager {

    /// Loads configuration values from the database and returns the db_version.
    /// The db_version is also applied to the `dbVersion` property.
    func loadConfiguration() -> String {
        // Added new keys to fetch
        let query = """
            SELECT key, value, data_type FROM Configuration
            WHERE key IN (
                'base_currency', 'as_of_date', 'decimal_precision', 'auto_fx_update',
                'default_timezone', 'table_row_spacing', 'table_row_padding',
                'include_direct_re', 'direct_re_target_chf', 'db_version'
            );
        """
        var statement: OpaquePointer?
        var loadedVersion = ""
        
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
                    case "include_direct_re":
                        self.includeDirectRealEstate = value.lowercased() == "true"
                    case "direct_re_target_chf":
                        self.directRealEstateTargetCHF = Double(value) ?? 0
                    case "db_version":
                        loadedVersion = value
                        self.dbVersion = value
                        print("📦 Database version loaded: \(value)")
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
        return loadedVersion
    }
    
    func updateConfiguration(key: String, value: String) -> Bool {
        let query = "UPDATE Configuration SET value = ?, updated_at = CURRENT_TIMESTAMP WHERE key = ?;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare updateConfiguration for key '\(key)': \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, (value as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, (key as NSString).utf8String, -1, SQLITE_TRANSIENT)
        
        let success = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if success {
            print("✅ Configuration updated for key '\(key)' to value '\(value)'")
            // Reload configuration to update @Published properties
            // This ensures that if one part of the app updates config, others see it if observing DatabaseManager
            self.dbVersion = loadConfiguration()
        } else {
            print("❌ Failed to update configuration for key '\(key)': \(String(cString: sqlite3_errmsg(db)))")
        }
        return success
    }

    func forceReloadData() { // This mainly reloads configuration currently
        print("🔄 Force reloading database configuration...")
        self.dbVersion = loadConfiguration()
        NotificationCenter.default.post(name: NSNotification.Name("DatabaseForceReloaded"), object: nil)
    }
}
