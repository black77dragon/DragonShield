// DragonShield/DatabaseManager+Configuration.swift
// MARK: - Version 1.2
// MARK: - History
// - 1.0 -> 1.1: Enhanced loadConfiguration to populate new @Published vars. Added updateConfiguration method.
// - 1.1 -> 1.2: Load db_version configuration and expose via dbVersion property.
// - Initial creation: Refactored from DatabaseManager.swift.

import SQLite3
import Foundation

// Cache to avoid repeating PRAGMA lookups each call
private var configHasDescriptionColumn: Bool? = nil

private func detectConfigDescriptionColumn(db: OpaquePointer?) -> Bool {
    if let cached = configHasDescriptionColumn { return cached }
    guard let db else { configHasDescriptionColumn = false; return false }
    var stmt: OpaquePointer?
    defer { sqlite3_finalize(stmt) }
    if sqlite3_prepare_v2(db, "PRAGMA table_info(Configuration);", -1, &stmt, nil) == SQLITE_OK {
        var found = false
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let namePtr = sqlite3_column_text(stmt, 1) {
                let name = String(cString: namePtr)
                if name.lowercased() == "description" { found = true; break }
            }
        }
        configHasDescriptionColumn = found
        return found
    }
    configHasDescriptionColumn = false
    return false
}

extension DatabaseManager {

    /// Loads configuration values from the database and returns the db_version.
    /// The db_version is also applied to the `dbVersion` property.
    func loadConfiguration() -> String {
        // Added new keys to fetch
        let query = """
            SELECT key, value, data_type FROM Configuration
            WHERE key IN (
                'base_currency', 'as_of_date', 'decimal_precision',
                'default_timezone', 'table_row_spacing', 'table_row_padding',
                'include_direct_re', 'direct_re_target_chf', 'db_version',
                'fx_auto_update_enabled', 'fx_update_frequency',
                'ios_snapshot_auto_enabled', 'ios_snapshot_frequency', 'ios_snapshot_target_path'
            );
        """
        var statement: OpaquePointer?
        var loadedVersion = ""
        
        // Collect values locally first to avoid publishing from inside view updates.
        var baseCurrencyLocal: String? = nil
        var asOfDateLocal: Date? = nil
        var decimalPrecisionLocal: Int? = nil
        var defaultTimeZoneLocal: String? = nil
        var tableRowSpacingLocal: Double? = nil
        var tableRowPaddingLocal: Double? = nil
        var includeDirectRELocal: Bool? = nil
        var directRETargetLocal: Double? = nil
        var fxAutoLocal: Bool? = nil
        var fxFreqLocal: String? = nil
        var iosAutoLocal: Bool? = nil
        var iosFreqLocal: String? = nil
        var iosPathLocal: String? = nil

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let keyPtr = sqlite3_column_text(statement, 0),
                      let valuePtr = sqlite3_column_text(statement, 1)
                else { continue }

                let key = String(cString: keyPtr)
                let value = String(cString: valuePtr)

                if key == "db_version" { loadedVersion = value }

                switch key {
                case "base_currency": baseCurrencyLocal = value
                case "as_of_date": asOfDateLocal = DateFormatter.iso8601DateOnly.date(from: value)
                case "decimal_precision": decimalPrecisionLocal = Int(value) ?? 4
                case "default_timezone": defaultTimeZoneLocal = value
                case "table_row_spacing": tableRowSpacingLocal = Double(value) ?? 1.0
                case "table_row_padding": tableRowPaddingLocal = Double(value) ?? 12.0
                case "include_direct_re": includeDirectRELocal = (value.lowercased() == "true" || value == "1")
                case "direct_re_target_chf": directRETargetLocal = Double(value) ?? 0
                case "db_version": /* handled via loadedVersion */ print("📦 Database version loaded: \(value)")
                case "fx_auto_update_enabled": fxAutoLocal = (value.lowercased() == "true" || value == "1")
                case "fx_update_frequency": let v = value.lowercased(); fxFreqLocal = (v == "weekly" ? "weekly" : "daily")
                case "ios_snapshot_auto_enabled": iosAutoLocal = (value.lowercased() == "true" || value == "1")
                case "ios_snapshot_frequency": let v = value.lowercased(); iosFreqLocal = (v == "weekly" ? "weekly" : "daily")
                case "ios_snapshot_target_path": iosPathLocal = value
                default: print("ℹ️ Unhandled configuration key loaded: \(key)")
                }
            }
        } else {
            print("❌ Failed to prepare loadConfiguration: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        // Publish on next runloop turn to avoid 'Publishing during view updates' warnings
        DispatchQueue.main.async { [
            baseCurrencyLocal,
            asOfDateLocal,
            decimalPrecisionLocal,
            defaultTimeZoneLocal,
            tableRowSpacingLocal,
            tableRowPaddingLocal,
            includeDirectRELocal,
            directRETargetLocal,
            fxAutoLocal,
            fxFreqLocal,
            iosAutoLocal,
            iosFreqLocal,
            iosPathLocal,
            loadedVersion
        ] in
            if let v = baseCurrencyLocal { self.baseCurrency = v }
            if let v = asOfDateLocal { self.asOfDate = v }
            if let v = decimalPrecisionLocal { self.decimalPrecision = v }
            if let v = defaultTimeZoneLocal { self.defaultTimeZone = v }
            if let v = tableRowSpacingLocal { self.tableRowSpacing = v }
            if let v = tableRowPaddingLocal { self.tableRowPadding = v }
            if let v = includeDirectRELocal { self.includeDirectRealEstate = v }
            if let v = directRETargetLocal { self.directRealEstateTargetCHF = v }
            if let v = fxAutoLocal { self.fxAutoUpdateEnabled = v }
            if let v = fxFreqLocal { self.fxUpdateFrequency = v }
            if let v = iosAutoLocal { self.iosSnapshotAutoEnabled = v }
            if let v = iosFreqLocal { self.iosSnapshotFrequency = v }
            if let v = iosPathLocal { self.iosSnapshotTargetPath = v }
            self.dbVersion = loadedVersion
        }
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
            let version = loadConfiguration()
            DispatchQueue.main.async { self.dbVersion = version }
        } else {
            print("❌ Failed to update configuration for key '\(key)': \(String(cString: sqlite3_errmsg(db)))")
        }
        return success
    }

    /// Insert or update a configuration key with explicit data type and optional description.
    /// Uses an UPSERT to create the key if it doesn't exist. Falls back if 'description' column is absent.
    func upsertConfiguration(key: String, value: String, dataType: String, description: String? = nil) -> Bool {
        let queryNoDesc = """
            INSERT INTO Configuration (key, value, data_type, updated_at)
            VALUES (?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(key) DO UPDATE SET
                value = excluded.value,
                data_type = excluded.data_type,
                updated_at = CURRENT_TIMESTAMP;
        """

        func prepareAndRun(sql: String, bindDescription: Bool) -> (ok: Bool, err: String?) {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                let err = db != nil ? String(cString: sqlite3_errmsg(db)) : "database pointer is nil"
                return (false, err)
            }
            defer { sqlite3_finalize(statement) }
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(statement, 1, (key as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, (value as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 3, (dataType as NSString).utf8String, -1, SQLITE_TRANSIENT)
            if bindDescription {
                if let d = description { sqlite3_bind_text(statement, 4, (d as NSString).utf8String, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(statement, 4) }
            }
            let ok = sqlite3_step(statement) == SQLITE_DONE
            let err = ok ? nil : String(cString: sqlite3_errmsg(db))
            return (ok, err)
        }

        // Always use compatibility path without description column to avoid schema variance issues.
        let r = prepareAndRun(sql: queryNoDesc, bindDescription: false)
        if r.ok { let _ = loadConfiguration(); return true }
        if let e = r.err { print("❌ upsertConfiguration failed for key '\(key)': \(e)") }
        return false
    }

    func forceReloadData() { // This mainly reloads configuration currently
        print("🔄 Force reloading database configuration...")
        let version = loadConfiguration()
        DispatchQueue.main.async { self.dbVersion = version }
        NotificationCenter.default.post(name: NSNotification.Name("DatabaseForceReloaded"), object: nil)
    }

    /// Fetch a configuration value by key (raw string). Returns nil if not found.
    func fetchConfigurationValue(key: String) -> String? {
        let sql = "SELECT value FROM Configuration WHERE key = ? LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, (key as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) == SQLITE_ROW, let cstr = sqlite3_column_text(stmt, 0) {
            return String(cString: cstr)
        }
        return nil
    }
}
