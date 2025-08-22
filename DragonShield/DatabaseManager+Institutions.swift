// DragonShield/DatabaseManager+Institutions.swift
// MARK: - Version 1.2
// MARK: - History
// - 1.0 -> 1.1: Added Hashable conformance to InstitutionData for use in Lists
//                and Picker tags.
// - 1.1 -> 1.2: deleteInstitution now performs a hard delete instead of
//                deactivating the entry.
// - Initial creation: Provides CRUD operations for Institutions table.

import SQLite3
import Foundation

extension DatabaseManager {

    struct InstitutionData: Identifiable, Equatable, Hashable {
        let id: Int
        var name: String
        var bic: String?
        var type: String?
        var website: String?
        var contactInfo: String?
        var defaultCurrency: String?
        var countryCode: String?
        var notes: String?
        var isActive: Bool
    }

    func fetchInstitutions(activeOnly: Bool = true) -> [InstitutionData] {
        var institutions: [InstitutionData] = []
        var query = "SELECT institution_id, institution_name, bic, institution_type, website, contact_info, default_currency, country_code, notes, is_active FROM Institutions"
        if activeOnly { query += " WHERE is_active = 1" }
        query += " ORDER BY institution_name COLLATE NOCASE;"

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 1))
                let bic = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
                let type = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
                let website = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
                let contactInfo = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
                let defaultCurrency = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
                let countryCode = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
                let notes = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
                let isActive = sqlite3_column_int(stmt, 9) == 1
                institutions.append(InstitutionData(id: id, name: name, bic: bic, type: type, website: website, contactInfo: contactInfo, defaultCurrency: defaultCurrency, countryCode: countryCode, notes: notes, isActive: isActive))
            }
        } else {
            print("❌ Failed to prepare fetchInstitutions: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(stmt)
        return institutions
    }

    func fetchInstitutionDetails(id: Int) -> InstitutionData? {
        let query = "SELECT institution_id, institution_name, bic, institution_type, website, contact_info, default_currency, country_code, notes, is_active FROM Institutions WHERE institution_id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 1))
                let bic = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
                let type = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
                let website = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
                let contactInfo = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
                let defaultCurrency = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
                let countryCode = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
                let notes = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
                let isActive = sqlite3_column_int(stmt, 9) == 1
                sqlite3_finalize(stmt)
                return InstitutionData(id: id, name: name, bic: bic, type: type, website: website, contactInfo: contactInfo, defaultCurrency: defaultCurrency, countryCode: countryCode, notes: notes, isActive: isActive)
            }
        } else {
            print("❌ Failed to prepare fetchInstitutionDetails: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(stmt)
        return nil
    }

    func addInstitution(name: String, bic: String?, type: String?, website: String?, contactInfo: String?, defaultCurrency: String?, countryCode: String?, notes: String?, isActive: Bool) -> Int? {
        let query = "INSERT INTO Institutions (institution_name, bic, institution_type, website, contact_info, default_currency, country_code, notes, is_active) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare addInstitution: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, (name as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if let b = bic, !b.isEmpty { sqlite3_bind_text(stmt, 2, (b as NSString).utf8String, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 2) }
        if let t = type, !t.isEmpty { sqlite3_bind_text(stmt, 3, (t as NSString).utf8String, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 3) }
        if let w = website, !w.isEmpty { sqlite3_bind_text(stmt, 4, (w as NSString).utf8String, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 4) }
        if let cInfo = contactInfo, !cInfo.isEmpty { sqlite3_bind_text(stmt, 5, (cInfo as NSString).utf8String, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 5) }
        if let dCurr = defaultCurrency, !dCurr.isEmpty { sqlite3_bind_text(stmt, 6, (dCurr as NSString).utf8String, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 6) }
        if let cCode = countryCode, !cCode.isEmpty { sqlite3_bind_text(stmt, 7, (cCode as NSString).utf8String, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 7) }
        if let n = notes, !n.isEmpty { sqlite3_bind_text(stmt, 8, (n as NSString).utf8String, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 8) }
        sqlite3_bind_int(stmt, 9, isActive ? 1 : 0)
        let result = sqlite3_step(stmt) == SQLITE_DONE
        let newId = result ? Int(sqlite3_last_insert_rowid(db)) : nil
        sqlite3_finalize(stmt)
        if result { print("✅ Inserted institution '\(name)'") } else { print("❌ Insert institution failed: \(String(cString: sqlite3_errmsg(db)))") }
        return newId
    }

    func updateInstitution(id: Int, name: String, bic: String?, type: String?, website: String?, contactInfo: String?, defaultCurrency: String?, countryCode: String?, notes: String?, isActive: Bool) -> Bool {
        let query = "UPDATE Institutions SET institution_name = ?, bic = ?, institution_type = ?, website = ?, contact_info = ?, default_currency = ?, country_code = ?, notes = ?, is_active = ?, updated_at = CURRENT_TIMESTAMP WHERE institution_id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare updateInstitution: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, (name as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if let b = bic, !b.isEmpty { sqlite3_bind_text(stmt, 2, (b as NSString).utf8String, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 2) }
        if let t = type, !t.isEmpty { sqlite3_bind_text(stmt, 3, (t as NSString).utf8String, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 3) }
        if let w = website, !w.isEmpty { sqlite3_bind_text(stmt, 4, (w as NSString).utf8String, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 4) }
        if let cInfo = contactInfo, !cInfo.isEmpty { sqlite3_bind_text(stmt, 5, (cInfo as NSString).utf8String, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 5) }
        if let dCurr = defaultCurrency, !dCurr.isEmpty { sqlite3_bind_text(stmt, 6, (dCurr as NSString).utf8String, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 6) }
        if let cCode = countryCode, !cCode.isEmpty { sqlite3_bind_text(stmt, 7, (cCode as NSString).utf8String, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 7) }
        if let n = notes, !n.isEmpty { sqlite3_bind_text(stmt, 8, (n as NSString).utf8String, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 8) }
        sqlite3_bind_int(stmt, 9, isActive ? 1 : 0)
        sqlite3_bind_int(stmt, 10, Int32(id))
        let result = sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_finalize(stmt)
        if result { print("✅ Updated institution (ID: \(id))") } else { print("❌ Update institution failed: \(String(cString: sqlite3_errmsg(db)))") }
        return result
    }

    func deleteInstitution(id: Int) -> Bool {
        let query = "DELETE FROM Institutions WHERE institution_id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare deleteInstitution: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        sqlite3_bind_int(stmt, 1, Int32(id))
        let result = sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_finalize(stmt)
        if result { print("✅ Deleted institution (ID: \(id))") } else { print("❌ Delete institution failed: \(String(cString: sqlite3_errmsg(db)))") }
        return result
    }

    func canDeleteInstitution(id: Int) -> (Bool, Int, String) {
        let query = "SELECT COUNT(*) FROM Accounts WHERE institution_id = ?;"
        var stmt: OpaquePointer?
        var count = 0
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW { count = Int(sqlite3_column_int(stmt, 0)) }
        } else {
            print("❌ Failed dependency check for institution: \(String(cString: sqlite3_errmsg(db)))")
            sqlite3_finalize(stmt)
            return (false, 0, "Error checking dependencies.")
        }
        sqlite3_finalize(stmt)
        if count > 0 { return (false, count, "Institution used by \(count) account(s).") }
        return (true, 0, "Institution can be deleted.")
    }

    /// Returns the institution_id for a given institution name if it exists.
    func findInstitutionId(name: String) -> Int? {
        let query = "SELECT institution_id FROM Institutions WHERE institution_name = ? COLLATE NOCASE LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare findInstitutionId: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, name, -1, nil)
        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }
        return nil
    }

    /// Returns all institution IDs for a given institution name. Useful when
    /// duplicates exist with the same name.
    func findInstitutionIds(name: String) -> [Int] {
        let query = "SELECT institution_id FROM Institutions WHERE institution_name = ? COLLATE NOCASE;"
        var stmt: OpaquePointer?
        var ids: [Int] = []
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare findInstitutionIds: \(String(cString: sqlite3_errmsg(db)))")
            return []
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, name, -1, nil)
        while sqlite3_step(stmt) == SQLITE_ROW {
            ids.append(Int(sqlite3_column_int(stmt, 0)))
        }
        return ids
    }

    /// Returns all institution IDs whose BIC matches the given prefix.
    /// The comparison is case-insensitive and allows partial branch codes.
    func findInstitutionIds(bic: String) -> [Int] {
        let query = "SELECT institution_id FROM Institutions WHERE bic LIKE ? COLLATE NOCASE;"
        var stmt: OpaquePointer?
        var ids: [Int] = []
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare findInstitutionIds(bic): \(String(cString: sqlite3_errmsg(db)))")
            return []
        }
        defer { sqlite3_finalize(stmt) }
        let pattern = "\(bic)%"
        sqlite3_bind_text(stmt, 1, pattern, -1, nil)
        while sqlite3_step(stmt) == SQLITE_ROW {
            ids.append(Int(sqlite3_column_int(stmt, 0)))
        }
        return ids
    }
}

