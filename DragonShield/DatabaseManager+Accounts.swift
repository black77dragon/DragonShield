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
        var earliestInstrumentLastUpdatedAt: Date?
        var includeInPortfolio: Bool
        var isActive: Bool
        var notes: String?
    }

    func fetchAccounts() -> [AccountData] {
        var accounts: [AccountData] = []
        // MODIFIED: Join with AccountTypes and Institutions tables
        let query = """
            WITH account_freshness AS (
                SELECT pr.account_id AS account_id,
                       MIN(COALESCE(ipl.as_of, pr.instrument_updated_at)) AS min_as_of
                  FROM PositionReports pr
                  LEFT JOIN InstrumentPriceLatest ipl ON ipl.instrument_id = pr.instrument_id
                 GROUP BY pr.account_id
            )
            SELECT a.account_id, a.account_name,
                   i.institution_name, i.bic,
                   a.account_number, at.type_name AS account_type_name, a.currency_code,
                   a.opening_date, a.closing_date, af.min_as_of,
                   a.include_in_portfolio, a.is_active, a.notes,
                   a.account_type_id, a.institution_id
            FROM Accounts a
            JOIN AccountTypes at ON a.account_type_id = at.account_type_id
            JOIN Institutions i ON a.institution_id = i.institution_id
            LEFT JOIN account_freshness af ON af.account_id = a.account_id
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
                let earliestDate: Date? = sqlite3_column_text(statement, 9).map { String(cString: $0) }.flatMap { ISO8601DateParser.parse($0) }

                let includeInPortfolio = sqlite3_column_int(statement, 10) == 1
                let isActive = sqlite3_column_int(statement, 11) == 1
                let notes: String? = sqlite3_column_text(statement, 12).map { String(cString: $0) }
                let accountTypeId = Int(sqlite3_column_int(statement, 13))
                let institutionId = Int(sqlite3_column_int(statement, 14))
                
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
                    earliestInstrumentLastUpdatedAt: earliestDate,
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
                   a.opening_date, a.closing_date, a.earliest_instrument_last_updated_at,
                   a.include_in_portfolio, a.is_active, a.notes,
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
                let earliestDate: Date? = sqlite3_column_text(statement, 9).map { String(cString: $0) }.flatMap { ISO8601DateParser.parse($0) }
                let includeInPortfolio = sqlite3_column_int(statement, 10) == 1
                let isActive = sqlite3_column_int(statement, 11) == 1
                let notes: String? = sqlite3_column_text(statement, 12).map { String(cString: $0) }
                let accountTypeId = Int(sqlite3_column_int(statement, 13))
                let institutionId = Int(sqlite3_column_int(statement, 14))

                sqlite3_finalize(statement)
                return AccountData(
                    id: id, accountName: accountName, institutionId: institutionId,
                    institutionName: institutionName, institutionBic: institutionBic,
                    accountNumber: accountNumber, accountType: accountTypeName,
                    accountTypeId: accountTypeId, currencyCode: currencyCode, openingDate: openingDate,
                    closingDate: closingDate, earliestInstrumentLastUpdatedAt: earliestDate,
                    includeInPortfolio: includeInPortfolio, isActive: isActive, notes: notes
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

    /// Marks an account inactive without removing it from the database.
    func disableAccount(id: Int) -> Bool {
        let query = "UPDATE Accounts SET is_active = 0, updated_at = CURRENT_TIMESTAMP WHERE account_id = ?;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare disableAccount (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        sqlite3_bind_int(statement, 1, Int32(id))
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)

        if result {
            print("✅ Disabled account (ID: \(id))")
        } else {
            print("❌ Disable account failed (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
        }
        return result
    }

    /// Permanently removes an account if no dependent records exist.
    func deleteAccount(id: Int) -> Bool {
        let query = "DELETE FROM Accounts WHERE account_id = ?;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare deleteAccount (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        sqlite3_bind_int(statement, 1, Int32(id))
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)

        if result {
            print("✅ Deleted account (ID: \(id))")
        } else {
            print("❌ Delete account failed (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
        }
        return result
    }

    /// Checks whether an account can be deleted or disabled.
    /// Returns false if any transactions or position reports reference it.
    func canDeleteAccount(id: Int) -> (canDelete: Bool, dependencyCount: Int, message: String) {
        let query = """
            SELECT (SELECT COUNT(*) FROM Transactions WHERE account_id = ?) +
                   (SELECT COUNT(*) FROM PositionReports WHERE account_id = ?);
            """
        var statement: OpaquePointer?
        var count = 0
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(id))
            sqlite3_bind_int(statement, 2, Int32(id))
            if sqlite3_step(statement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(statement, 0))
            }
        } else {
            print("❌ Failed to prepare canDeleteAccount: \(String(cString: sqlite3_errmsg(db)))")
            sqlite3_finalize(statement)
            return (false, 0, "Error checking account dependencies.")
        }
        sqlite3_finalize(statement)

        if count > 0 {
            return (false, count, "Account is linked to \(count) record(s) and cannot be modified.")
        }
        return (true, 0, "Account can be deleted or disabled.")
    }

    /// Returns the account_id for a given account number, optionally matching
    /// part of the account name. The lookup strips all non\u{00A0}alphanumeric
    /// characters from the account number for a resilient comparison and is
    /// case-insensitive. This helps match numbers that may include various
    /// dashes or whitespace characters in the source data.
    func findAccountId(accountNumber: String, nameContains: String? = nil) -> Int? {
        let sanitizedSearch = accountNumber.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map { Character($0) }
            .map { String($0) }
            .joined()
            .lowercased()
        LoggingService.shared.log(
            "findAccountId search: number=\(accountNumber) sanitized=\(sanitizedSearch) nameFilter=\(nameContains ?? "nil")",
            type: .debug, logger: .database
        )

        var query = "SELECT account_id, account_number FROM Accounts"
        if let _ = nameContains {
            query += " WHERE account_name LIKE ? COLLATE NOCASE"
        }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            LoggingService.shared.log("Failed to prepare findAccountId: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return nil
        }
        defer { sqlite3_finalize(statement) }
        if let name = nameContains {
            let pattern = "%\(name)%"
            sqlite3_bind_text(statement, 1, pattern, -1, nil)
        }
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            let dbNumber = String(cString: sqlite3_column_text(statement, 1))
            let sanitizedDb = dbNumber.unicodeScalars
                .filter { CharacterSet.alphanumerics.contains($0) }
                .map { Character($0) }
                .map { String($0) }
                .joined()
                .lowercased()
            if sanitizedDb == sanitizedSearch {
                LoggingService.shared.log("findAccountId found id=\(id) for sanitized=\(sanitizedSearch)", type: .debug, logger: .database)
                return id
            }
        }
        LoggingService.shared.log("findAccountId no match for sanitized=\(sanitizedSearch)", type: .debug, logger: .database)
        return nil
    }

    /// Finds the `account_id` for the given valor/IBAN string.
    /// The valor corresponds to the `account_number` in the Accounts table.
    /// All non-alphanumeric characters are stripped for a resilient comparison.
    func findAccountId(valor: String) -> Int? {
        let sanitizedSearch = valor.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map { Character($0) }
            .map { String($0) }
            .joined()
            .lowercased()
        LoggingService.shared.log(
            "findAccountId(valor) search valor=\(valor) sanitized=\(sanitizedSearch)",
            type: .debug, logger: .database
        )

        let query = "SELECT account_id, account_number FROM Accounts;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            LoggingService.shared.log("Failed to prepare findAccountId(valor): \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return nil
        }
        defer { sqlite3_finalize(statement) }
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            guard let numPtr = sqlite3_column_text(statement, 1) else { continue }
            let dbNumber = String(cString: numPtr)
            let sanitizedDb = dbNumber.unicodeScalars
                .filter { CharacterSet.alphanumerics.contains($0) }
                .map { Character($0) }
                .map { String($0) }
                .joined()
                .lowercased()
            LoggingService.shared.log(
                "findAccountId(valor) check id=\(id) number=\(dbNumber) sanitized=\(sanitizedDb)",
                type: .debug, logger: .database
            )
            if sanitizedDb == sanitizedSearch {
                LoggingService.shared.log("findAccountId(valor) found id=\(id) for sanitized=\(sanitizedSearch)", type: .debug, logger: .database)
                return id
            }
        }
        LoggingService.shared.log("findAccountId(valor) no match for sanitized=\(sanitizedSearch)", type: .debug, logger: .database)
        return nil
    }

    /// Returns IDs and numbers of all accounts belonging to the given institution name.
    func fetchAccounts(institutionName: String) -> [(id: Int, number: String)] {
        let sql = """
            SELECT a.account_id, a.account_number
              FROM Accounts a
              JOIN Institutions i ON a.institution_id = i.institution_id
             WHERE i.institution_name = ? COLLATE NOCASE;
            """
        var stmt: OpaquePointer?
        var results: [(Int, String)] = []
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare fetchAccounts(institutionName): \(String(cString: sqlite3_errmsg(db)))")
            return []
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, institutionName, -1, nil)
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(stmt, 0))
            let number = String(cString: sqlite3_column_text(stmt, 1))
            results.append((id, number))
        }
        return results
    }

    /// Recalculates the earliest instrument update date for all accounts.
    /// - Parameter completion: Called on the main thread with the number of
    ///   rows updated or an error.
    func refreshEarliestInstrumentTimestamps(completion: @escaping (Result<Int, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else {
                DispatchQueue.main.async {
                    let error = NSError(domain: "DatabaseManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Database connection unavailable"])
                    completion(.failure(error))
                }
                return
            }

            let sql = """
                UPDATE Accounts
                   SET earliest_instrument_last_updated_at = (
                        SELECT MIN(instrument_updated_at)
                          FROM PositionReports pr
                         WHERE pr.account_id = Accounts.account_id
                   );
                """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else {
                let msg = String(cString: sqlite3_errmsg(self.db))
                DispatchQueue.main.async {
                    let error = NSError(domain: "DatabaseManager", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
                    completion(.failure(error))
                }
                return
            }

            defer { sqlite3_finalize(stmt) }

            let stepResult = sqlite3_step(stmt)
            let updatedRows = Int(sqlite3_changes(self.db))

            DispatchQueue.main.async {
                if stepResult == SQLITE_DONE {
                    completion(.success(updatedRows))
                } else {
                    let msg = String(cString: sqlite3_errmsg(self.db))
                    let error = NSError(domain: "DatabaseManager", code: 2, userInfo: [NSLocalizedDescriptionKey: msg])
                    completion(.failure(error))
                }
            }
        }
    }
}
