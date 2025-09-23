// DragonShield/DatabaseManager+Configuration.swift
// MARK: - Version 1.2
// MARK: - History
// - 1.0 -> 1.1: Enhanced loadConfiguration to populate new @Published vars. Added updateConfiguration method.
// - 1.1 -> 1.2: Load db_version configuration and expose via dbVersion property.
// - Initial creation: Refactored from DatabaseManager.swift.

import SQLite3
import Foundation

extension DatabaseManager {

    /// Returns whether the manager currently has an open SQLite connection.
    /// iOS views rely on this to decide if snapshot data can be read.
    func hasOpenConnection() -> Bool {
        db != nil
    }

    /// Returns the raw configuration value for the provided key, if it exists.
    /// Falls back to `nil` when the connection is missing or an error occurs.
    func configurationValue(for key: String) -> String? {
        guard let db else { return nil }
        let query = "SELECT value FROM Configuration WHERE key = ? LIMIT 1;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            #if DEBUG
            let message = String(cString: sqlite3_errmsg(db))
            print("❌ [config] Failed to prepare lookup for key \(key): \(message)")
            #endif
            return nil
        }
        defer { sqlite3_finalize(statement) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, (key as NSString).utf8String, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(statement) == SQLITE_ROW,
              let pointer = sqlite3_column_text(statement, 0) else {
            return nil
        }
        return String(cString: pointer)
    }

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
                'ios_snapshot_auto_enabled', 'ios_snapshot_frequency', 'ios_snapshot_target_path', 'ios_snapshot_target_bookmark',
                'institutions_table_font', 'institutions_table_column_fractions',
                'instruments_table_font', 'instruments_table_column_fractions',
                'currencies_table_font', 'currencies_table_column_fractions',
                'accounts_table_font', 'accounts_table_column_fractions',
                'portfolio_themes_table_font', 'portfolio_themes_table_column_fractions'
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
                                
                if key == "db_version" {
                    loadedVersion = value
                }

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
                        self.dbVersion = value
                        print("📦 Database version loaded: \(value)")
                    case "fx_auto_update_enabled":
                        self.fxAutoUpdateEnabled = value.lowercased() == "true" || value == "1"
                    case "fx_update_frequency":
                        let v = value.lowercased()
                        self.fxUpdateFrequency = (v == "weekly" ? "weekly" : "daily")
                    case "ios_snapshot_auto_enabled":
                        self.iosSnapshotAutoEnabled = value.lowercased() == "true" || value == "1"
                    case "ios_snapshot_frequency":
                        let v = value.lowercased()
                        self.iosSnapshotFrequency = (v == "weekly" ? "weekly" : "daily")
                    case "ios_snapshot_target_path":
                        self.iosSnapshotTargetPath = value
                    case "ios_snapshot_target_bookmark":
                        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            self.iosSnapshotTargetBookmark = nil
                        } else if let data = Data(base64Encoded: trimmed) {
                            self.iosSnapshotTargetBookmark = data
                        } else {
                            self.iosSnapshotTargetBookmark = nil
                            print("⚠️ [config] Failed to decode ios_snapshot_target_bookmark")
                        }
                    case "institutions_table_font":
                        print("ℹ️ [config] Loaded institutions_table_font=\(value)")
                        self.institutionsTableFontSize = value
                    case "institutions_table_column_fractions":
                        let parsed = DatabaseManager.decodeFractionDictionary(from: value)
                        print("ℹ️ [config] Loaded institutions_table_column_fractions=\(parsed)")
                        self.institutionsTableColumnFractions = parsed
                    case "instruments_table_font":
                        print("ℹ️ [config] Loaded instruments_table_font=\(value)")
                        self.instrumentsTableFontSize = value
                    case "instruments_table_column_fractions":
                        let parsed = DatabaseManager.decodeFractionDictionary(from: value)
                        print("ℹ️ [config] Loaded instruments_table_column_fractions=\(parsed)")
                        self.instrumentsTableColumnFractions = parsed
                    case "currencies_table_font":
                        print("ℹ️ [config] Loaded currencies_table_font=\(value)")
                        self.currenciesTableFontSize = value
                    case "currencies_table_column_fractions":
                        let parsed = DatabaseManager.decodeFractionDictionary(from: value)
                        print("ℹ️ [config] Loaded currencies_table_column_fractions=\(parsed)")
                        self.currenciesTableColumnFractions = parsed
                    case "accounts_table_font":
                        print("ℹ️ [config] Loaded accounts_table_font=\(value)")
                        self.accountsTableFontSize = value
                    case "portfolio_themes_table_font":
                        print("ℹ️ [config] Loaded portfolio_themes_table_font=\(value)")
                        self.portfolioThemesTableFontSize = value
                    case "accounts_table_column_fractions":
                        let parsed = DatabaseManager.decodeFractionDictionary(from: value)
                        print("ℹ️ [config] Loaded accounts_table_column_fractions=\(parsed)")
                        self.accountsTableColumnFractions = parsed
                    case "portfolio_themes_table_column_fractions":
                        let parsed = DatabaseManager.decodeFractionDictionary(from: value)
                        print("ℹ️ [config] Loaded portfolio_themes_table_column_fractions=\(parsed)")
                        self.portfolioThemesTableColumnFractions = parsed
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
            print("❌ [config] Failed to prepare update for key \(key): \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, (value as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, (key as NSString).utf8String, -1, SQLITE_TRANSIENT)
        
        let success = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        if success {
            let changeCount = sqlite3_changes(db)
            if changeCount > 0 {
                print("💾 [config] Updated key \(key) to value=\(value)")
                let version = loadConfiguration()
                DispatchQueue.main.async { self.dbVersion = version }
                return true
            } else {
                print("ℹ️ [config] No existing row for key \(key); update affected 0 rows")
                return false
            }
        } else {
            print("❌ [config] Failed to update key \(key): \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
    }

    /// Insert or update a configuration key with explicit data type and optional description.
    /// Uses an UPSERT to create the key if it doesn't exist.
    func upsertConfiguration(key: String, value: String, dataType: String, description: String? = nil) -> Bool {
        let query = """
            INSERT INTO Configuration (key, value, data_type, updated_at)
            VALUES (?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(key) DO UPDATE SET
                value = excluded.value,
                data_type = excluded.data_type,
                updated_at = CURRENT_TIMESTAMP;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("❌ [config] Failed to prepare upsert for key \(key): \(errorMessage)")
            return updateOrInsertConfigurationFallback(key: key, value: value, dataType: dataType)
        }
        defer { sqlite3_finalize(statement) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, (key as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, (value as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, (dataType as NSString).utf8String, -1, SQLITE_TRANSIENT)
        let success = sqlite3_step(statement) == SQLITE_DONE
        if success {
            print("💾 [config] Upserted key \(key) value=\(value)")
            let _ = loadConfiguration()
        } else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("❌ [config] upsertConfiguration failed for key \(key): \(errorMessage)")
        }
        return success
    }

    private func updateOrInsertConfigurationFallback(key: String, value: String, dataType: String) -> Bool {
        print("⚠️ [config] Falling back to manual update/insert for key \(key)")
        if updateConfiguration(key: key, value: value) {
            return true
        }
        let insertQuery = "INSERT INTO Configuration (key, value, data_type, updated_at) VALUES (?, ?, ?, CURRENT_TIMESTAMP);"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) == SQLITE_OK else {
            print("❌ [config] Fallback insert prepare failed for key \(key): \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        defer { sqlite3_finalize(statement) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, (key as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, (value as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, (dataType as NSString).utf8String, -1, SQLITE_TRANSIENT)
        let success = sqlite3_step(statement) == SQLITE_DONE
        if success {
            print("💾 [config] Inserted key \(key) via fallback")
            let _ = loadConfiguration()
        } else {
            print("❌ [config] Fallback insert failed for key \(key): \(String(cString: sqlite3_errmsg(db)))")
        }
        return success
    }

    func forceReloadData() { // This mainly reloads configuration currently
        print("🔄 Force reloading database configuration...")
        let version = loadConfiguration()
        DispatchQueue.main.async { self.dbVersion = version }
        NotificationCenter.default.post(name: NSNotification.Name("DatabaseForceReloaded"), object: nil)
    }

    // MARK: - Table Preference Helpers

    private static func decodeFractionDictionary(from json: String) -> [String: Double] {
        guard let data = json.data(using: .utf8),
              let raw = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return [:]
        }
        var result: [String: Double] = [:]
        for (key, value) in raw {
            if let number = value as? NSNumber {
                result[key] = number.doubleValue
            } else if let string = value as? String, let doubleValue = Double(string) {
                result[key] = doubleValue
            }
        }
        return result
    }

    private static func encodeFractionDictionary(_ dictionary: [String: Double]) -> String? {
        guard JSONSerialization.isValidJSONObject(dictionary) else { return nil }
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys]) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func normaliseFractionsForStorage(_ dictionary: [String: Double]) -> [String: Double] {
        dictionary.reduce(into: [String: Double]()) { partialResult, element in
            guard element.value.isFinite else { return }
            let clamped = max(0.0, element.value)
            let rounded = (clamped * 10_000).rounded() / 10_000
            partialResult[element.key] = rounded
        }
    }

    func setInstitutionsTableFontSize(_ value: String) {
        guard institutionsTableFontSize != value else { return }
        print("📝 [config] Request to store institutions_table_font=\(value)")
        _ = upsertConfiguration(key: "institutions_table_font",
                                value: value,
                                dataType: "string",
                                description: "Preferred font size for Institutions table")
    }

    func setInstitutionsTableColumnFractions(_ fractions: [String: Double]) {
        let cleaned = DatabaseManager.normaliseFractionsForStorage(fractions)
        guard institutionsTableColumnFractions != cleaned else { return }
        print("📝 [config] Request to store institutions_table_column_fractions=\(cleaned)")
        let payload = DatabaseManager.encodeFractionDictionary(cleaned) ?? "{}"
        _ = upsertConfiguration(key: "institutions_table_column_fractions",
                                value: payload,
                                dataType: "string",
                                description: "Column width fractions for Institutions table")
    }

    func setInstrumentsTableFontSize(_ value: String) {
        guard instrumentsTableFontSize != value else { return }
        print("📝 [config] Request to store instruments_table_font=\(value)")
        _ = upsertConfiguration(key: "instruments_table_font",
                                value: value,
                                dataType: "string",
                                description: "Preferred font size for Instruments table")
    }

    func setInstrumentsTableColumnFractions(_ fractions: [String: Double]) {
        let cleaned = DatabaseManager.normaliseFractionsForStorage(fractions)
        guard instrumentsTableColumnFractions != cleaned else { return }
        print("📝 [config] Request to store instruments_table_column_fractions=\(cleaned)")
        let payload = DatabaseManager.encodeFractionDictionary(cleaned) ?? "{}"
        _ = upsertConfiguration(key: "instruments_table_column_fractions",
                                value: payload,
                                dataType: "string",
                                description: "Column width fractions for Instruments table")
    }

    func setCurrenciesTableFontSize(_ value: String) {
        guard currenciesTableFontSize != value else { return }
        print("📝 [config] Request to store currencies_table_font=\(value)")
        _ = upsertConfiguration(key: "currencies_table_font",
                                value: value,
                                dataType: "string",
                                description: "Preferred font size for Currencies table")
    }

    func setCurrenciesTableColumnFractions(_ fractions: [String: Double]) {
        let cleaned = DatabaseManager.normaliseFractionsForStorage(fractions)
        guard currenciesTableColumnFractions != cleaned else { return }
        print("📝 [config] Request to store currencies_table_column_fractions=\(cleaned)")
        let payload = DatabaseManager.encodeFractionDictionary(cleaned) ?? "{}"
        _ = upsertConfiguration(key: "currencies_table_column_fractions",
                                value: payload,
                                dataType: "string",
                                description: "Column width fractions for Currencies table")
    }

    func setAccountsTableFontSize(_ value: String) {
        guard accountsTableFontSize != value else { return }
        print("📝 [config] Request to store accounts_table_font=\(value)")
        _ = upsertConfiguration(key: "accounts_table_font",
                                value: value,
                                dataType: "string",
                                description: "Preferred font size for Accounts table")
    }

    func setAccountsTableColumnFractions(_ fractions: [String: Double]) {
        let cleaned = DatabaseManager.normaliseFractionsForStorage(fractions)
        guard accountsTableColumnFractions != cleaned else { return }
        print("📝 [config] Request to store accounts_table_column_fractions=\(cleaned)")
        let payload = DatabaseManager.encodeFractionDictionary(cleaned) ?? "{}"
        _ = upsertConfiguration(key: "accounts_table_column_fractions",
                                value: payload,
                                dataType: "string",
                                description: "Column width fractions for Accounts table")
    }

    func setPortfolioThemesTableFontSize(_ value: String) {
        guard portfolioThemesTableFontSize != value else { return }
        print("📝 [config] Request to store portfolio_themes_table_font=\(value)")
        _ = upsertConfiguration(key: "portfolio_themes_table_font",
                                value: value,
                                dataType: "string",
                                description: "Preferred font size for New Portfolios table")
    }

    func setPortfolioThemesTableColumnFractions(_ fractions: [String: Double]) {
        let cleaned = DatabaseManager.normaliseFractionsForStorage(fractions)
        guard portfolioThemesTableColumnFractions != cleaned else { return }
        print("📝 [config] Request to store portfolio_themes_table_column_fractions=\(cleaned)")
        let payload = DatabaseManager.encodeFractionDictionary(cleaned) ?? "{}"
        _ = upsertConfiguration(key: "portfolio_themes_table_column_fractions",
                                value: payload,
                                dataType: "string",
                                description: "Column width fractions for New Portfolios table")
    }
}
