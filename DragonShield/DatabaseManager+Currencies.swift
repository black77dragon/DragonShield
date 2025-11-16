// DragonShield/DatabaseManager+Currencies.swift

// MARK: - Version 1.1

// MARK: - History

// - 1.0 -> 1.1: Corrected string binding in fetchCurrencyDetails to fix data loading bug.
// - Initial creation: Refactored from DatabaseManager.swift.

import Foundation
import SQLite3

extension DatabaseManager {
    func fetchActiveCurrencies() -> [(code: String, name: String, symbol: String)] {
        var currencies: [(code: String, name: String, symbol: String)] = []
        let query = """
            SELECT currency_code, currency_name, currency_symbol
            FROM Currencies
            WHERE is_active = 1
            ORDER BY
                CASE currency_code
                    WHEN 'CHF' THEN 1
                    WHEN 'USD' THEN 2
                    WHEN 'EUR' THEN 3
                    ELSE 4
                END,
                currency_code
        """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let code = String(cString: sqlite3_column_text(statement, 0))
                let name = String(cString: sqlite3_column_text(statement, 1))
                let symbol = sqlite3_column_text(statement, 2).map { String(cString: $0) } ?? code

                currencies.append((code: code, name: name, symbol: symbol))
            }
        } else {
            print("❌ Failed to prepare fetchActiveCurrencies: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        return currencies
    }

    func fetchCurrencies() -> [(code: String, name: String, symbol: String, isActive: Bool, apiSupported: Bool)] {
        var currencies: [(code: String, name: String, symbol: String, isActive: Bool, apiSupported: Bool)] = []
        let query = """
            SELECT currency_code, currency_name, currency_symbol, is_active, api_supported
            FROM Currencies
            ORDER BY currency_code
        """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let code = String(cString: sqlite3_column_text(statement, 0))
                let name = String(cString: sqlite3_column_text(statement, 1))
                let symbol = sqlite3_column_text(statement, 2).map { String(cString: $0) } ?? code
                let isActive = sqlite3_column_int(statement, 3) == 1
                let apiSupported = sqlite3_column_int(statement, 4) == 1

                currencies.append((code: code, name: name, symbol: symbol, isActive: isActive, apiSupported: apiSupported))
            }
        } else {
            print("❌ Failed to prepare fetchCurrencies: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        return currencies
    }

    func debugListAllCurrencies() {
        print("🔍 DEBUG: Listing ALL currencies in database:")
        let query = "SELECT currency_code, currency_name, currency_symbol, is_active, api_supported FROM Currencies ORDER BY currency_code"
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let code = String(cString: sqlite3_column_text(statement, 0))
                let name = String(cString: sqlite3_column_text(statement, 1))
                let symbol = sqlite3_column_text(statement, 2).map { String(cString: $0) } ?? "NULL"
                let isActive = sqlite3_column_int(statement, 3) == 1
                let apiSupported = sqlite3_column_int(statement, 4) == 1
                print("   Currency: '\(code)' | Name: '\(name)' | Symbol: '\(symbol)' | Active: \(isActive) | API: \(apiSupported)")
            }
        } else {
            print("❌ Error listing currencies for debug: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
    }

    func fetchCurrencyDetails(code: String) -> (code: String, name: String, symbol: String, isActive: Bool, apiSupported: Bool)? {
        let query = """
            SELECT currency_code, currency_name, currency_symbol, is_active, api_supported
            FROM Currencies
            WHERE currency_code = ? COLLATE NOCASE
        """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            // --- THIS IS THE FIX ---
            // Using SQLITE_TRANSIENT tells SQLite to make its own copy of the string, which is safer.
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(statement, 1, (code as NSString).utf8String, -1, SQLITE_TRANSIENT)
            // --- END OF FIX ---

            if sqlite3_step(statement) == SQLITE_ROW {
                let currencyCode = String(cString: sqlite3_column_text(statement, 0))
                let currencyName = String(cString: sqlite3_column_text(statement, 1))
                let currencySymbol = sqlite3_column_text(statement, 2).map { String(cString: $0) } ?? currencyCode
                let isActive = sqlite3_column_int(statement, 3) == 1
                let apiSupported = sqlite3_column_int(statement, 4) == 1

                sqlite3_finalize(statement)
                return (code: currencyCode, name: currencyName, symbol: currencySymbol, isActive: isActive, apiSupported: apiSupported)
            } else {
                print("ℹ️ No currency details found for code: '\(code)'")
            }
        } else {
            print("❌ Failed to prepare fetchCurrencyDetails (Code: \(code)): \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        return nil
    }

    func addCurrency(code: String, name: String, symbol: String, isActive: Bool, apiSupported: Bool) -> Bool {
        let query = """
            INSERT INTO Currencies (currency_code, currency_name, currency_symbol, is_active, api_supported)
            VALUES (?, ?, ?, ?, ?)
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare addCurrency: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        _ = code.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        _ = name.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        _ = symbol.withCString { sqlite3_bind_text(statement, 3, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int(statement, 4, isActive ? 1 : 0)
        sqlite3_bind_int(statement, 5, apiSupported ? 1 : 0)

        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)

        if result {
            print("✅ Inserted currency: \(code)")
        } else {
            print("❌ Insert currency '\(code)' failed: \(String(cString: sqlite3_errmsg(db)))")
        }
        return result
    }

    func updateCurrency(code: String, name: String, symbol: String, isActive: Bool, apiSupported: Bool) -> Bool {
        let query = """
            UPDATE Currencies
            SET currency_name = ?, currency_symbol = ?, is_active = ?, api_supported = ?, updated_at = CURRENT_TIMESTAMP
            WHERE currency_code = ? COLLATE NOCASE
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare updateCurrency (Code: \(code)): \(String(cString: sqlite3_errmsg(db)))")
            return false
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        _ = name.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        _ = symbol.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int(statement, 3, isActive ? 1 : 0)
        sqlite3_bind_int(statement, 4, apiSupported ? 1 : 0)
        _ = code.withCString { sqlite3_bind_text(statement, 5, $0, -1, SQLITE_TRANSIENT) }

        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)

        if result {
            print("✅ Updated currency: \(code)")
        } else {
            print("❌ Update currency '\(code)' failed: \(String(cString: sqlite3_errmsg(db)))")
        }
        return result
    }

    func deleteCurrency(code: String) -> Bool { // Soft delete
        let query = "UPDATE Currencies SET is_active = 0, updated_at = CURRENT_TIMESTAMP WHERE currency_code = ? COLLATE NOCASE"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare deleteCurrency (Code: \(code)): \(String(cString: sqlite3_errmsg(db)))")
            return false
        }

        _ = code.withCString { sqlite3_bind_text(statement, 1, $0, -1, nil) } // SQLITE_STATIC
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)

        if result {
            print("✅ Soft deleted currency: \(code)")
        } else {
            print("❌ Soft delete currency '\(code)' failed: \(String(cString: sqlite3_errmsg(db)))")
        }
        return result
    }
}
