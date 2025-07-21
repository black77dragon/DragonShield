// DragonShield/DatabaseManager+PositionReports.swift
// MARK: - Version 1.1 (2025-06-16)
// MARK: - History
// - 1.0 -> 1.1: Move PositionReportData struct to global scope for easier access.
// - Initial creation: Fetch position reports from PositionReports table joining Accounts and Instruments.

import SQLite3
import Foundation

struct PositionReportData: Identifiable {
        var id: Int
        var importSessionId: Int?
        var accountName: String
        var institutionName: String
        var instrumentName: String
        var instrumentCurrency: String
        var instrumentCountry: String?
        var instrumentSector: String?
        var assetClass: String?
        var assetSubClass: String?
        var quantity: Double
        var purchasePrice: Double?
        var currentPrice: Double?
        var instrumentUpdatedAt: Date?
        var notes: String?
        var reportDate: Date
        var uploadedAt: Date
}

extension DatabaseManager {

    func fetchPositionReports() -> [PositionReportData] {
        var reports: [PositionReportData] = []
        let query = """
            SELECT pr.position_id, pr.import_session_id, a.account_name,
                   ins.institution_name, i.instrument_name, i.currency,
                   i.country_code, i.sector, ac.class_name, asc.sub_class_name,
                   pr.quantity, pr.purchase_price, pr.current_price,
                   pr.instrument_updated_at,
                   pr.notes,
                   pr.report_date, pr.uploaded_at
            FROM PositionReports pr
            JOIN Accounts a ON pr.account_id = a.account_id
            JOIN Institutions ins ON pr.institution_id = ins.institution_id
            JOIN Instruments i ON pr.instrument_id = i.instrument_id
            JOIN AssetSubClasses asc ON i.sub_class_id = asc.sub_class_id
            JOIN AssetClasses ac ON asc.class_id = ac.class_id
            ORDER BY pr.position_id;
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let sessionId: Int?
                if sqlite3_column_type(statement, 1) != SQLITE_NULL {
                    sessionId = Int(sqlite3_column_int(statement, 1))
                } else {
                    sessionId = nil
                }
                let accountName = String(cString: sqlite3_column_text(statement, 2))
                let institutionName = String(cString: sqlite3_column_text(statement, 3))
                let instrumentName = String(cString: sqlite3_column_text(statement, 4))
                let instrumentCurrency = String(cString: sqlite3_column_text(statement, 5))
                let instrumentCountry = sqlite3_column_text(statement, 6).map { String(cString: $0) }
                let instrumentSector = sqlite3_column_text(statement, 7).map { String(cString: $0) }
                let assetClass = sqlite3_column_text(statement, 8).map { String(cString: $0) }
                let assetSubClass = sqlite3_column_text(statement, 9).map { String(cString: $0) }
                let quantity = sqlite3_column_double(statement, 10)
                var purchasePrice: Double?
                if sqlite3_column_type(statement, 11) != SQLITE_NULL {
                    purchasePrice = sqlite3_column_double(statement, 11)
                }
                var currentPrice: Double?
                if sqlite3_column_type(statement, 12) != SQLITE_NULL {
                    currentPrice = sqlite3_column_double(statement, 12)
                }
                var instrumentUpdatedAt: Date?
                if sqlite3_column_type(statement, 13) != SQLITE_NULL {
                    let str = String(cString: sqlite3_column_text(statement, 13))
                    instrumentUpdatedAt = DateFormatter.iso8601DateOnly.date(from: str)
                }
                let notes: String? = sqlite3_column_text(statement, 14).map { String(cString: $0) }
                let reportDateStr = String(cString: sqlite3_column_text(statement, 15))
                let uploadedAtStr = String(cString: sqlite3_column_text(statement, 16))
                let reportDate = DateFormatter.iso8601DateOnly.date(from: reportDateStr) ?? Date()
                let uploadedAt = DateFormatter.iso8601DateTime.date(from: uploadedAtStr) ?? Date()
                reports.append(PositionReportData(
                    id: id,
                    importSessionId: sessionId,
                    accountName: accountName,
                    institutionName: institutionName,
                    instrumentName: instrumentName,
                    instrumentCurrency: instrumentCurrency,
                    instrumentCountry: instrumentCountry,
                    instrumentSector: instrumentSector,
                    assetClass: assetClass,
                    assetSubClass: assetSubClass,
                    quantity: quantity,
                    purchasePrice: purchasePrice,
                    currentPrice: currentPrice,
                    instrumentUpdatedAt: instrumentUpdatedAt,
                    notes: notes,
                    reportDate: reportDate,
                    uploadedAt: uploadedAt
                ))
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to prepare fetchPositionReports: \(errmsg)")
        }
        sqlite3_finalize(statement)
        return reports
    }

    /// Deletes position reports where the associated account name contains the provided text.
    /// - Parameter substring: The case-insensitive text to match within account names.
    /// - Returns: The number of deleted rows.
    func deletePositionReports(accountNameContains substring: String) -> Int {
        let sql = """
            DELETE FROM PositionReports
            WHERE account_id IN (
                SELECT account_id FROM Accounts
                WHERE account_name LIKE '%' || ? || '%' COLLATE NOCASE
            );
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare deletePositionReports: \(String(cString: sqlite3_errmsg(db)))")
            return 0
        }
        sqlite3_bind_text(stmt, 1, substring, -1, nil)
        let stepResult = sqlite3_step(stmt)
        let deleted = sqlite3_changes(db)
        sqlite3_finalize(stmt)
        if stepResult == SQLITE_DONE {
            print("✅ Deleted \(deleted) position reports matching \(substring)")
        } else {
            print("❌ Failed to delete position reports: \(String(cString: sqlite3_errmsg(db)))")
        }
        return Int(deleted)
    }

    /// Deletes position reports linked to the specified institution IDs.
    /// - Parameter institutionIds: The identifiers to match.
    /// - Returns: The number of deleted rows.
    func deletePositionReports(institutionIds: [Int]) -> Int {
        guard !institutionIds.isEmpty else { return 0 }
        let placeholders = Array(repeating: "?", count: institutionIds.count).joined(separator: ", ")
        let sql = """
            DELETE FROM PositionReports
                  WHERE institution_id IN (\(placeholders))
                     OR account_id IN (
                        SELECT account_id FROM Accounts
                         WHERE institution_id IN (\(placeholders))
                  );
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare deletePositionReports: \(String(cString: sqlite3_errmsg(db)))")
            return 0
        }
        defer { sqlite3_finalize(stmt) }
        for (i, id) in institutionIds.enumerated() {
            sqlite3_bind_int(stmt, Int32(i + 1), Int32(id))
        }
        for (i, id) in institutionIds.enumerated() {
            sqlite3_bind_int(stmt, Int32(institutionIds.count + i + 1), Int32(id))
        }
        let stepResult = sqlite3_step(stmt)
        let deleted = sqlite3_changes(db)
        if stepResult == SQLITE_DONE {
            print("✅ Deleted \(deleted) position reports for institution ids \(institutionIds)")
        } else {
            print("❌ Failed to delete position reports: \(String(cString: sqlite3_errmsg(db)))")
        }
        return Int(deleted)
    }

    /// Deletes position reports for all institutions matching the given name.
    func deletePositionReports(institutionName: String) -> Int {
        let ids = findInstitutionIds(name: institutionName)
        if ids.isEmpty {
            print("⚠️ No institution found matching \(institutionName)")
            return 0
        }
        print("🗑️ Deleting positions for \(institutionName) institutions with ids: \(ids)")
        return deletePositionReports(institutionIds: ids)
    }

    /// Deletes position reports for all institutions matching the given BIC code.
    func deletePositionReports(institutionBic: String) -> Int {
        let ids = findInstitutionIds(bic: institutionBic)
        if ids.isEmpty {
            print("⚠️ No institution found with BIC \(institutionBic)")
            return 0
        }
        print("🗑️ Deleting positions for institutions with BIC \(institutionBic): \(ids)")
        return deletePositionReports(institutionIds: ids)
    }

    /// Deletes position reports for the specified account IDs.
    func deletePositionReports(accountIds: [Int]) -> Int {
        guard !accountIds.isEmpty else { return 0 }
        let placeholders = Array(repeating: "?", count: accountIds.count).joined(separator: ", ")
        let sql = "DELETE FROM PositionReports WHERE account_id IN (\(placeholders));"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare deletePositionReports(accountIds): \(String(cString: sqlite3_errmsg(db)))")
            return 0
        }
        defer { sqlite3_finalize(stmt) }
        for (i, id) in accountIds.enumerated() {
            sqlite3_bind_int(stmt, Int32(i + 1), Int32(id))
        }
        let step = sqlite3_step(stmt)
        let deleted = sqlite3_changes(db)
        if step == SQLITE_DONE {
            print("✅ Deleted \(deleted) position reports for account ids \(accountIds)")
        } else {
            print("❌ Failed to delete position reports: \(String(cString: sqlite3_errmsg(db)))")
        }
        return Int(deleted)
    }

    // MARK: - Single Position CRUD

    func addPositionReport(importSessionId: Int?, accountId: Int, institutionId: Int, instrumentId: Int, quantity: Double, purchasePrice: Double?, currentPrice: Double?, instrumentUpdatedAt: Date?, notes: String?, reportDate: Date) -> Int? {
        let sql = "INSERT INTO PositionReports (import_session_id, account_id, institution_id, instrument_id, quantity, purchase_price, current_price, instrument_updated_at, notes, report_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare insert position: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        if let s = importSessionId { sqlite3_bind_int(stmt, 1, Int32(s)) } else { sqlite3_bind_null(stmt, 1) }
        sqlite3_bind_int(stmt, 2, Int32(accountId))
        sqlite3_bind_int(stmt, 3, Int32(institutionId))
        sqlite3_bind_int(stmt, 4, Int32(instrumentId))
        sqlite3_bind_double(stmt, 5, quantity)
        if let p = purchasePrice { sqlite3_bind_double(stmt, 6, p) } else { sqlite3_bind_null(stmt, 6) }
        if let c = currentPrice { sqlite3_bind_double(stmt, 7, c) } else { sqlite3_bind_null(stmt, 7) }
        if let iu = instrumentUpdatedAt { sqlite3_bind_text(stmt, 8, DateFormatter.iso8601DateOnly.string(from: iu), -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 8) }
        if let n = notes { sqlite3_bind_text(stmt, 9, n, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 9) }
        sqlite3_bind_text(stmt, 10, DateFormatter.iso8601DateOnly.string(from: reportDate), -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            print("❌ Insert position failed: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        return Int(sqlite3_last_insert_rowid(db))
    }

    func updatePositionReport(id: Int, importSessionId: Int?, accountId: Int, institutionId: Int, instrumentId: Int, quantity: Double, purchasePrice: Double?, currentPrice: Double?, instrumentUpdatedAt: Date?, notes: String?, reportDate: Date) -> Bool {
        let sql = "UPDATE PositionReports SET import_session_id = ?, account_id = ?, institution_id = ?, instrument_id = ?, quantity = ?, purchase_price = ?, current_price = ?, instrument_updated_at = ?, notes = ?, report_date = ?, uploaded_at = CURRENT_TIMESTAMP WHERE position_id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare update position: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        if let s = importSessionId { sqlite3_bind_int(stmt, 1, Int32(s)) } else { sqlite3_bind_null(stmt, 1) }
        sqlite3_bind_int(stmt, 2, Int32(accountId))
        sqlite3_bind_int(stmt, 3, Int32(institutionId))
        sqlite3_bind_int(stmt, 4, Int32(instrumentId))
        sqlite3_bind_double(stmt, 5, quantity)
        if let p = purchasePrice { sqlite3_bind_double(stmt, 6, p) } else { sqlite3_bind_null(stmt, 6) }
        if let c = currentPrice { sqlite3_bind_double(stmt, 7, c) } else { sqlite3_bind_null(stmt, 7) }
        if let iu = instrumentUpdatedAt { sqlite3_bind_text(stmt, 8, DateFormatter.iso8601DateOnly.string(from: iu), -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 8) }
        if let n = notes { sqlite3_bind_text(stmt, 9, n, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 9) }
        sqlite3_bind_text(stmt, 10, DateFormatter.iso8601DateOnly.string(from: reportDate), -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 11, Int32(id))
        let result = sqlite3_step(stmt) == SQLITE_DONE
        if !result { print("❌ Update position failed: \(String(cString: sqlite3_errmsg(db)))") }
        return result
    }

    func deletePositionReport(id: Int) -> Bool {
        let sql = "DELETE FROM PositionReports WHERE position_id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare delete position: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(id))
        let result = sqlite3_step(stmt) == SQLITE_DONE
        if !result { print("❌ Delete position failed: \(String(cString: sqlite3_errmsg(db)))") }
        return result
    }
}
