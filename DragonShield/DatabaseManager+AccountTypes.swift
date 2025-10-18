// DragonShield/DatabaseManager+AccountTypes.swift
// MARK: - Version 1.2
// MARK: - History
// - 1.1 -> 1.2: Added updateAccountType method to support editing. Corrected var/let warning.
// - 1.0 -> 1.1: Added addAccountType, deleteAccountType, canDeleteAccountType methods.

import SQLite3
import Foundation

extension DatabaseManager {

    struct AccountTypeData: Identifiable, Equatable {
        let id: Int
        let code: String
        let name: String
        let description: String?
        let isActive: Bool
    }

    func fetchAccountTypes(activeOnly: Bool = true) -> [AccountTypeData] {
        var accountTypes: [AccountTypeData] = []
        var query = "SELECT account_type_id, type_code, type_name, type_description, is_active FROM AccountTypes"
        if activeOnly {
            query += " WHERE is_active = 1"
        }
        query += " ORDER BY type_name;"

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let code = String(cString: sqlite3_column_text(statement, 1))
                let name = String(cString: sqlite3_column_text(statement, 2))
                
                let description: String? = sqlite3_column_text(statement, 3).map { String(cString: $0) }
                let isActive = sqlite3_column_int(statement, 4) == 1
                
                accountTypes.append(AccountTypeData(
                    id: id, code: code, name: name, description: description, isActive: isActive
                ))
            }
        } else {
            print("❌ Failed to prepare fetchAccountTypes: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        return accountTypes
    }

    func addAccountType(code: String, name: String, description: String?, isActive: Bool) -> Bool {
        let query = "INSERT INTO AccountTypes (type_code, type_name, type_description, is_active) VALUES (?, ?, ?, ?);"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare addAccountType: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, (code as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, (name as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if let desc = description, !desc.isEmpty {
            sqlite3_bind_text(statement, 3, (desc as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 3)
        }
        sqlite3_bind_int(statement, 4, isActive ? 1 : 0)

        let success = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)

        if success {
            print("✅ AccountType '\(name)' added successfully.")
        } else {
            print("❌ Failed to add AccountType '\(name)': \(String(cString: sqlite3_errmsg(db)))")
        }
        return success
    }

    // NEW FUNCTION: updateAccountType
    func updateAccountType(id: Int, code: String, name: String, description: String?, isActive: Bool) -> Bool {
        let query = """
            UPDATE AccountTypes SET
                type_code = ?,
                type_name = ?,
                type_description = ?,
                is_active = ?,
                updated_at = CURRENT_TIMESTAMP
            WHERE account_type_id = ?;
        """
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare updateAccountType (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
            return false
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, (code as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, (name as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if let desc = description, !desc.isEmpty {
            sqlite3_bind_text(statement, 3, (desc as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 3)
        }
        sqlite3_bind_int(statement, 4, isActive ? 1 : 0)
        sqlite3_bind_int(statement, 5, Int32(id))

        let success = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)

        if success {
            print("✅ AccountType with ID \(id) updated successfully.")
        } else {
            print("❌ Failed to update AccountType with ID \(id): \(String(cString: sqlite3_errmsg(db)))")
        }
        return success
    }

    func deleteAccountType(id: Int) -> Bool {
        let query = "DELETE FROM AccountTypes WHERE account_type_id = ?;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare deleteAccountType: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        sqlite3_bind_int(statement, 1, Int32(id))

        let success = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)

        if success {
            print("✅ AccountType with ID \(id) deleted successfully.")
        } else {
            print("❌ Failed to delete AccountType with ID \(id): \(String(cString: sqlite3_errmsg(db)))")
        }
        return success
    }

    func canDeleteAccountType(id: Int) -> (canDelete: Bool, referencedByCount: Int, message: String) {
        let query = "SELECT COUNT(*) FROM Accounts WHERE account_type_id = ?;"
        var statement: OpaquePointer?
        var count = 0

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(id))
            if sqlite3_step(statement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(statement, 0))
            }
        } else {
            print("❌ Failed to prepare canDeleteAccountType check: \(String(cString: sqlite3_errmsg(db)))")
            sqlite3_finalize(statement)
            return (false, 0, "Error checking for dependencies.")
        }
        sqlite3_finalize(statement)

        if count > 0 {
            return (false, count, "This account type is used by \(count) account(s) and cannot be deleted directly. Please reassign or delete those accounts first.")
        }
        return (true, 0, "Account type can be deleted.")
    }
    
    func fetchAccountTypeDetails(id: Int) -> AccountTypeData? {
        // Corrected the var to let for the query string
        let query = "SELECT account_type_id, type_code, type_name, type_description, is_active FROM AccountTypes WHERE account_type_id = ?"
        var statement: OpaquePointer?
        var accountType: AccountTypeData? = nil

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(id))
            if sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let code = String(cString: sqlite3_column_text(statement, 1))
                let name = String(cString: sqlite3_column_text(statement, 2))
                let description: String? = sqlite3_column_text(statement, 3).map { String(cString: $0) }
                let isActive = sqlite3_column_int(statement, 4) == 1
                accountType = AccountTypeData(id: id, code: code, name: name, description: description, isActive: isActive)
            }
        } else {
            print("❌ Failed to prepare fetchAccountTypeDetails for ID \(id): \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        return accountType
    }

    /// Returns the account_type_id for the given type_code if present.
    func findAccountTypeId(code: String) -> Int? {
        let query = "SELECT account_type_id FROM AccountTypes WHERE type_code = ? COLLATE NOCASE LIMIT 1;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare findAccountTypeId: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, code, -1, nil)
        if sqlite3_step(statement) == SQLITE_ROW {
            return Int(sqlite3_column_int(statement, 0))
        }
        return nil
    }
}
