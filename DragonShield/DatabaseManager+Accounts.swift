// DragonShield/DatabaseManager+Accounts.swift
// MARK: - Version 1.4
// MARK: - History
// - 1.2 -> 1.3: Accounts now reference Institutions table via institution_id.
//                Queries updated accordingly.
// - 1.3 -> 1.4: Fixed duplicate variable and added missing institutionId
//                retrieval in fetchAccountDetails.
// - 1.1 -> 1.2: Modified to use account_type_id and join with AccountTypes table. Updated CRUD methods.
// - 1.0 -> 1.1: Updated AccountData struct and CRUD methods to include institution_bic, closing_date,
//               and handle opening_date as optional, aligning with the definitive DB schema.

import SQLite3
import Foundation

extension DatabaseManager {

    // AccountData struct remains the same for holding the type name for UI purposes.
    // The underlying database interaction will use account_type_id.
    struct AccountData: Identifiable, Equatable {
        var id: Int
        var accountName: String
        var institutionId: Int
        var institutionName: String
        var institutionBic: String?
        var accountNumber: String
        var accountType: String          // This will be the AccountType.name
        var accountTypeId: Int           // Store the ID for updates
        var currencyCode: String
        var openingDate: Date?
        var closingDate: Date?
        var includeInPortfolio: Bool
        var isActive: Bool
        var notes: String?
    }

    func fetchAccounts() -> [AccountData] {
        var accounts: [AccountData] = []
        // MODIFIED: Join with AccountTypes and Institutions tables
        let query = """
            SELECT a.account_id, a.account_name,
                   i.institution_name, i.bic,
                   a.account_number, at.type_name AS account_type_name, a.currency_code,
                   a.opening_date, a.closing_date, a.include_in_portfolio, a.is_active, a.notes,
                   a.account_type_id, a.institution_id
            FROM Accounts a
            JOIN AccountTypes at ON a.account_type_id = at.account_type_id
            JOIN Institutions i ON a.institution_id = i.institution_id
            ORDER BY a.account_name COLLATE NOCASE;
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let accountName = String(cString: sqlite3_column_text(statement, 1))
                let institutionName = String(cString: sqlite3_column_text(statement, 2))
                
                let institutionBic: String? = sqlite3_column_text(statement, 3).map { String(cString: $0) }

                let accountNumber = String(cString: sqlite3_column_text(statement, 4))
                let accountTypeName = String(cString: sqlite3_column_text(statement, 5))
                let currencyCode = String(cString: sqlite3_column_text(statement, 6))

                let openingDate: Date? = sqlite3_column_text(statement, 7).map { String(cString: $0) }.flatMap { DateFormatter.iso8601DateOnly.date(from: $0) }
                let closingDate: Date? = sqlite3_column_text(statement, 8).map { String(cString: $0) }.flatMap { DateFormatter.iso8601DateOnly.date(from: $0) }

                let includeInPortfolio = sqlite3_column_int(statement, 9) == 1
                let isActive = sqlite3_column_int(statement, 10) == 1
                let notes: String? = sqlite3_column_text(statement, 11).map { String(cString: $0) }
                let accountTypeId = Int(sqlite3_column_int(statement, 12))
                let institutionId = Int(sqlite3_column_int(statement, 13))
                
                accounts.append(AccountData(
                    id: id,
                    accountName: accountName,
                    institutionId: institutionId,
                    institutionName: institutionName,
                    institutionBic: institutionBic,
                    accountNumber: accountNumber,
                    accountType: accountTypeName, // Use fetched name
                    accountTypeId: accountTypeId, // Store the ID
                    currencyCode: currencyCode,
                    openingDate: openingDate,
                    closingDate: closingDate,
                    includeInPortfolio: includeInPortfolio,
                    isActive: isActive,
                    notes: notes
                ))
            }
        } else {
            print("❌ Failed to prepare fetchAccounts: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        return accounts
    }

    func fetchAccountDetails(id: Int) -> AccountData? {
        // MODIFIED: Join with AccountTypes and Institutions tables
        let query = """
            SELECT a.account_id, a.account_name,
                   i.institution_name, i.bic,
                   a.account_number, at.type_name AS account_type_name, a.currency_code,
                   a.opening_date, a.closing_date, a.include_in_portfolio, a.is_active, a.notes,
                   a.account_type_id, a.institution_id
            FROM Accounts a
            JOIN AccountTypes at ON a.account_type_id = at.account_type_id
            JOIN Institutions i ON a.institution_id = i.institution_id
            WHERE a.account_id = ?;
        """
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(id))
            
            if sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let accountName = String(cString: sqlite3_column_text(statement, 1))
                let institutionName = String(cString: sqlite3_column_text(statement, 2))
                let institutionBic: String? = sqlite3_column_text(statement, 3).map { String(cString: $0) }
                let accountNumber = String(cString: sqlite3_column_text(statement, 4))
                let accountTypeName = String(cString: sqlite3_column_text(statement, 5)) // Fetched type_name
                let currencyCode = String(cString: sqlite3_column_text(statement, 6))
                let openingDate: Date? = sqlite3_column_text(statement, 7).map { String(cString: $0) }.flatMap { DateFormatter.iso8601DateOnly.date(from: $0) }
                let closingDate: Date? = sqlite3_column_text(statement, 8).map { String(cString: $0) }.flatMap { DateFormatter.iso8601DateOnly.date(from: $0) }
                let includeInPortfolio = sqlite3_column_int(statement, 9) == 1
                let isActive = sqlite3_column_int(statement, 10) == 1
                let notes: String? = sqlite3_column_text(statement, 11).map { String(cString: $0) }
                let accountTypeId = Int(sqlite3_column_int(statement, 12))
                let institutionId = Int(sqlite3_column_int(statement, 13))

                sqlite3_finalize(statement)
                return AccountData(
                    id: id, accountName: accountName, institutionId: institutionId,
                    institutionName: institutionName, institutionBic: institutionBic,
                    accountNumber: accountNumber, accountType: accountTypeName,
                    accountTypeId: accountTypeId, currencyCode: currencyCode, openingDate: openingDate,
                    closingDate: closingDate, includeInPortfolio: includeInPortfolio, isActive: isActive, notes: notes
                )
            } else {
                print("ℹ️ No account details found for ID: \(id)")
            }
        } else {
            print("❌ Failed to prepare fetchAccountDetails (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        return nil
    }

    func addAccount(
        accountName: String, institutionId: Int,
        accountNumber: String, accountTypeId: Int,
        currencyCode: String, openingDate: Date?, closingDate: Date?,
        includeInPortfolio: Bool, isActive: Bool, notes: String?
    ) -> Bool {
        // MODIFIED: Use institution_id and account_type_id in INSERT query
        let query = """
            INSERT INTO Accounts (account_name, institution_id, account_number,
                                  account_type_id, currency_code, opening_date, closing_date,
                                  include_in_portfolio, is_active, notes)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare addAccount: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        
        sqlite3_bind_text(statement, 1, (accountName as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 2, Int32(institutionId))
        sqlite3_bind_text(statement, 3, (accountNumber as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 4, Int32(accountTypeId))
        sqlite3_bind_text(statement, 5, (currencyCode as NSString).utf8String, -1, SQLITE_TRANSIENT)
        
        if let oDate = openingDate {
            sqlite3_bind_text(statement, 6, (DateFormatter.iso8601DateOnly.string(from: oDate) as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 6)
        }

        if let cDate = closingDate {
            sqlite3_bind_text(statement, 7, (DateFormatter.iso8601DateOnly.string(from: cDate) as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 7)
        }
        sqlite3_bind_int(statement, 8, includeInPortfolio ? 1 : 0)
        sqlite3_bind_int(statement, 9, isActive ? 1 : 0)

        if let notesText = notes, !notesText.isEmpty {
            sqlite3_bind_text(statement, 10, (notesText as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 10)
        }
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if result {
            print("✅ Inserted account '\(accountName)' with ID: \(sqlite3_last_insert_rowid(db))")
        } else {
            print("❌ Insert account '\(accountName)' failed: \(String(cString: sqlite3_errmsg(db)))")
        }
        return result
    }

    func updateAccount(
        id: Int, accountName: String, institutionId: Int,
        accountNumber: String, accountTypeId: Int,
        currencyCode: String, openingDate: Date?, closingDate: Date?,
        includeInPortfolio: Bool, isActive: Bool, notes: String?
    ) -> Bool {
        // MODIFIED: Use institution_id and account_type_id in UPDATE query
        let query = """
            UPDATE Accounts SET
                account_name = ?, institution_id = ?, account_number = ?,
                account_type_id = ?, currency_code = ?, opening_date = ?, closing_date = ?,
                include_in_portfolio = ?, is_active = ?, notes = ?, updated_at = CURRENT_TIMESTAMP
            WHERE account_id = ?;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare updateAccount (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        sqlite3_bind_text(statement, 1, (accountName as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 2, Int32(institutionId))
        sqlite3_bind_text(statement, 3, (accountNumber as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 4, Int32(accountTypeId))
        sqlite3_bind_text(statement, 5, (currencyCode as NSString).utf8String, -1, SQLITE_TRANSIENT)
        
        if let oDate = openingDate {
            sqlite3_bind_text(statement, 6, (DateFormatter.iso8601DateOnly.string(from: oDate) as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 6)
        }
        if let cDate = closingDate {
            sqlite3_bind_text(statement, 7, (DateFormatter.iso8601DateOnly.string(from: cDate) as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 7)
        }

        sqlite3_bind_int(statement, 8, includeInPortfolio ? 1 : 0)
        sqlite3_bind_int(statement, 9, isActive ? 1 : 0)
        if let notesText = notes, !notesText.isEmpty {
            sqlite3_bind_text(statement, 10, (notesText as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 10)
        }
        sqlite3_bind_int(statement, 11, Int32(id))
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)

        if result {
            print("✅ Updated account (ID: \(id))")
        } else {
            print("❌ Update account failed (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
        }
        return result
    }

    // deleteAccount and canDeleteAccount remain unchanged as they don't directly use account_type
    func deleteAccount(id: Int) -> Bool {
        let query = "UPDATE accounts SET is_active = 0, updated_at = CURRENT_TIMESTAMP WHERE account_id = ?;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare deleteAccount (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        sqlite3_bind_int(statement, 1, Int32(id))
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if result {
            print("✅ Soft deleted account (ID: \(id))")
        } else {
            print("❌ Soft delete account failed (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
        }
        return result
    }

    func canDeleteAccount(id: Int) -> (canDelete: Bool, dependencyCount: Int, message: String) {
        return (canDelete: true, dependencyCount: 0, message: "Soft delete allowed. No dependency check implemented yet.")
    }

    /// Returns the account_id for a given account number if it exists.
    func findAccountId(accountNumber: String) -> Int? {
        let query = "SELECT account_id FROM Accounts WHERE account_number = ? LIMIT 1;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare findAccountId: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, accountNumber, -1, nil)
        if sqlite3_step(statement) == SQLITE_ROW {
            return Int(sqlite3_column_int(statement, 0))
        }
        return nil
    }
}
