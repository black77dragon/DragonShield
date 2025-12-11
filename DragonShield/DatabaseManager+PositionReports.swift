// DragonShield/DatabaseManager+PositionReports.swift

// MARK: - Version 1.1 (2025-06-16)

// MARK: - History

// - 1.0 -> 1.1: Move PositionReportData struct to global scope for easier access.
// - Initial creation: Fetch position reports from PositionReports table joining Accounts and Instruments.

import Foundation
import SQLite3

struct PositionReportData: Identifiable {
    var id: Int
    var instrumentId: Int? = nil
    var importSessionId: Int?
    var accountName: String
    var institutionName: String
    var instrumentName: String
    var instrumentCurrency: String
    var instrumentCountry: String?
    var instrumentSector: String?
    var assetClass: String?
    var assetClassCode: String? = nil
    var assetSubClass: String?
    var assetSubClassCode: String? = nil
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
            SELECT pr.position_id, pr.instrument_id, pr.import_session_id, a.account_name,
                   ins.institution_name, i.instrument_name, i.currency,
                   i.country_code, i.sector, ac.class_name, ac.class_code, asc.sub_class_name, asc.sub_class_code,
                   pr.quantity, pr.purchase_price, pr.current_price,
                   COALESCE(ipl.as_of, pr.instrument_updated_at) AS price_as_of,
                   pr.notes,
                   pr.report_date, pr.uploaded_at
            FROM PositionReports pr
            JOIN Accounts a ON pr.account_id = a.account_id
            JOIN Institutions ins ON pr.institution_id = ins.institution_id
            JOIN Instruments i ON pr.instrument_id = i.instrument_id
            JOIN AssetSubClasses asc ON i.sub_class_id = asc.sub_class_id
            JOIN AssetClasses ac ON asc.class_id = ac.class_id
            LEFT JOIN InstrumentPriceLatest ipl ON ipl.instrument_id = pr.instrument_id
            ORDER BY pr.position_id;
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let instrId = Int(sqlite3_column_int(statement, 1))
                let sessionId: Int?
                if sqlite3_column_type(statement, 2) != SQLITE_NULL {
                    sessionId = Int(sqlite3_column_int(statement, 2))
                } else {
                    sessionId = nil
                }
                let accountName = String(cString: sqlite3_column_text(statement, 3))
                let institutionName = String(cString: sqlite3_column_text(statement, 4))
                let instrumentName = String(cString: sqlite3_column_text(statement, 5))
                let instrumentCurrency = String(cString: sqlite3_column_text(statement, 6))
                let instrumentCountry = sqlite3_column_text(statement, 7).map { String(cString: $0) }
                let instrumentSector = sqlite3_column_text(statement, 8).map { String(cString: $0) }
                let assetClass = sqlite3_column_text(statement, 9).map { String(cString: $0) }
                let assetClassCode = sqlite3_column_text(statement, 10).map { String(cString: $0) }
                let assetSubClass = sqlite3_column_text(statement, 11).map { String(cString: $0) }
                let assetSubClassCode = sqlite3_column_text(statement, 12).map { String(cString: $0) }
                let quantity = sqlite3_column_double(statement, 13)
                var purchasePrice: Double?
                if sqlite3_column_type(statement, 14) != SQLITE_NULL {
                    purchasePrice = sqlite3_column_double(statement, 14)
                }
                var currentPrice: Double?
                if sqlite3_column_type(statement, 15) != SQLITE_NULL {
                    currentPrice = sqlite3_column_double(statement, 15)
                }
                var instrumentUpdatedAt: Date?
                if sqlite3_column_type(statement, 16) != SQLITE_NULL {
                    let str = String(cString: sqlite3_column_text(statement, 16))
                    instrumentUpdatedAt = ISO8601DateParser.parse(str)
                }
                let notes: String? = sqlite3_column_text(statement, 17).map { String(cString: $0) }
                let reportDateStr = String(cString: sqlite3_column_text(statement, 18))
                let uploadedAtStr = String(cString: sqlite3_column_text(statement, 19))
                let reportDate = DateFormatter.iso8601DateOnly.date(from: reportDateStr) ?? Date()
                let uploadedAt = DateFormatter.iso8601DateTime.date(from: uploadedAtStr) ?? Date()
                reports.append(PositionReportData(
                    id: id,
                    instrumentId: instrId,
                    importSessionId: sessionId,
                    accountName: accountName,
                    institutionName: institutionName,
                    instrumentName: instrumentName,
                    instrumentCurrency: instrumentCurrency,
                    instrumentCountry: instrumentCountry,
                    instrumentSector: instrumentSector,
                    assetClass: assetClass,
                    assetClassCode: assetClassCode,
                    assetSubClass: assetSubClass,
                    assetSubClassCode: assetSubClassCode,
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

    func listPositionsForInstrument(id: Int) -> [PositionReportData] {
        var reports: [PositionReportData] = []
        let query = """
            SELECT pr.position_id, pr.instrument_id, pr.import_session_id, a.account_name,
                   ins.institution_name, i.instrument_name, i.currency,
                   i.country_code, i.sector, ac.class_name, ac.class_code, asc.sub_class_name, asc.sub_class_code,
                   pr.quantity, pr.purchase_price, pr.current_price,
                   COALESCE(ipl.as_of, pr.instrument_updated_at) AS price_as_of,
                   pr.notes,
                   pr.report_date, pr.uploaded_at
            FROM PositionReports pr
            JOIN Accounts a ON pr.account_id = a.account_id
            JOIN Institutions ins ON pr.institution_id = ins.institution_id
            JOIN Instruments i ON pr.instrument_id = i.instrument_id
            JOIN AssetSubClasses asc ON i.sub_class_id = asc.sub_class_id
            JOIN AssetClasses ac ON asc.class_id = ac.class_id
            LEFT JOIN InstrumentPriceLatest ipl ON ipl.instrument_id = pr.instrument_id
            WHERE pr.instrument_id = ?
            ORDER BY pr.position_id;
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(id))
            while sqlite3_step(statement) == SQLITE_ROW {
                let positionId = Int(sqlite3_column_int(statement, 0))
                let instrumentId: Int?
                if sqlite3_column_type(statement, 1) != SQLITE_NULL {
                    instrumentId = Int(sqlite3_column_int(statement, 1))
                } else {
                    instrumentId = nil
                }
                let sessionId: Int?
                if sqlite3_column_type(statement, 2) != SQLITE_NULL {
                    sessionId = Int(sqlite3_column_int(statement, 2))
                } else {
                    sessionId = nil
                }
                let accountName = String(cString: sqlite3_column_text(statement, 3))
                let institutionName = String(cString: sqlite3_column_text(statement, 4))
                let instrumentName = String(cString: sqlite3_column_text(statement, 5))
                let instrumentCurrency = String(cString: sqlite3_column_text(statement, 6))
                let instrumentCountry = sqlite3_column_text(statement, 7).map { String(cString: $0) }
                let instrumentSector = sqlite3_column_text(statement, 8).map { String(cString: $0) }
                let assetClass = sqlite3_column_text(statement, 9).map { String(cString: $0) }
                let assetClassCode = sqlite3_column_text(statement, 10).map { String(cString: $0) }
                let assetSubClass = sqlite3_column_text(statement, 11).map { String(cString: $0) }
                let assetSubClassCode = sqlite3_column_text(statement, 12).map { String(cString: $0) }
                let quantity = sqlite3_column_double(statement, 13)
                var purchasePrice: Double?
                if sqlite3_column_type(statement, 14) != SQLITE_NULL {
                    purchasePrice = sqlite3_column_double(statement, 14)
                } else {
                    purchasePrice = nil
                }
                var currentPrice: Double?
                if sqlite3_column_type(statement, 15) != SQLITE_NULL {
                    currentPrice = sqlite3_column_double(statement, 15)
                } else {
                    currentPrice = nil
                }
                var instrumentUpdatedAt: Date?
                if sqlite3_column_type(statement, 16) != SQLITE_NULL {
                    let str = String(cString: sqlite3_column_text(statement, 16))
                    instrumentUpdatedAt = ISO8601DateParser.parse(str)
                } else {
                    instrumentUpdatedAt = nil
                }
                let notes = sqlite3_column_text(statement, 17).map { String(cString: $0) }
                let reportDateStr = String(cString: sqlite3_column_text(statement, 18))
                let uploadedAtStr = String(cString: sqlite3_column_text(statement, 19))
                let reportDate = DateFormatter.iso8601DateOnly.date(from: reportDateStr) ?? Date()
                let uploadedAt = DateFormatter.iso8601DateTime.date(from: uploadedAtStr) ?? Date()

                reports.append(PositionReportData(
                    id: positionId,
                    instrumentId: instrumentId,
                    importSessionId: sessionId,
                    accountName: accountName,
                    institutionName: institutionName,
                    instrumentName: instrumentName,
                    instrumentCurrency: instrumentCurrency,
                    instrumentCountry: instrumentCountry,
                    instrumentSector: instrumentSector,
                    assetClass: assetClass,
                    assetClassCode: assetClassCode,
                    assetSubClass: assetSubClass,
                    assetSubClassCode: assetSubClassCode,
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
            print("❌ Failed to prepare listPositionsForInstrument: \(errmsg)")
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

    /// Counts position reports matching the provided institution and account type IDs.
    func countPositionReports(institutionIds: [Int], accountTypeIds: [Int]) -> Int {
        guard !institutionIds.isEmpty, !accountTypeIds.isEmpty else { return 0 }
        let instPlaceholders = Array(repeating: "?", count: institutionIds.count).joined(separator: ", ")
        let typePlaceholders = Array(repeating: "?", count: accountTypeIds.count).joined(separator: ", ")
        let sql = """
        SELECT COUNT(*)
          FROM PositionReports pr
          JOIN Accounts a ON pr.account_id = a.account_id
         WHERE pr.institution_id IN (\(instPlaceholders))
           AND a.account_type_id IN (\(typePlaceholders));
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare countPositionReports: \(String(cString: sqlite3_errmsg(db)))")
            return 0
        }
        defer { sqlite3_finalize(stmt) }
        var index: Int32 = 1
        for id in institutionIds {
            sqlite3_bind_int(stmt, index, Int32(id)); index += 1
        }
        for id in accountTypeIds {
            sqlite3_bind_int(stmt, index, Int32(id)); index += 1
        }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    /// Deletes position reports matching the given institution and account type IDs.
    func deletePositionReports(institutionIds: [Int], accountTypeIds: [Int]) -> Int {
        guard !institutionIds.isEmpty, !accountTypeIds.isEmpty else { return 0 }
        let instPlaceholders = Array(repeating: "?", count: institutionIds.count).joined(separator: ", ")
        let typePlaceholders = Array(repeating: "?", count: accountTypeIds.count).joined(separator: ", ")
        let sql = """
        DELETE FROM PositionReports
              WHERE institution_id IN (\(instPlaceholders))
                AND account_id IN (
                    SELECT account_id FROM Accounts
                     WHERE account_type_id IN (\(typePlaceholders))
              );
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare deletePositionReports: \(String(cString: sqlite3_errmsg(db)))")
            return 0
        }
        defer { sqlite3_finalize(stmt) }
        var index: Int32 = 1
        for id in institutionIds {
            sqlite3_bind_int(stmt, index, Int32(id)); index += 1
        }
        for id in accountTypeIds {
            sqlite3_bind_int(stmt, index, Int32(id)); index += 1
        }
        let step = sqlite3_step(stmt)
        let deleted = sqlite3_changes(db)
        if step == SQLITE_DONE {
            print("✅ Deleted \(deleted) position reports for institutions \(institutionIds) and account types \(accountTypeIds)")
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

    /// Purges position reports linked to instruments under the specified subclass.
    /// - Parameter subClassId: The subclass whose instrument positions should be removed.
    /// - Returns: The number of deleted rows.
    func purgePositionReports(subClassId: Int) -> Int {
        let sql = """
        DELETE FROM PositionReports
              WHERE instrument_id IN (
                    SELECT instrument_id FROM Instruments WHERE sub_class_id = ?
              );
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare purgePositionReports: \(String(cString: sqlite3_errmsg(db)))")
            return 0
        }
        sqlite3_bind_int(stmt, 1, Int32(subClassId))
        let step = sqlite3_step(stmt)
        let deleted = sqlite3_changes(db)
        sqlite3_finalize(stmt)
        if step == SQLITE_DONE {
            print("🗑️ Purged \(deleted) position reports for subclass \(subClassId)")
        } else {
            print("❌ Failed to purge position reports for subclass \(subClassId): \(String(cString: sqlite3_errmsg(db)))")
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

    /// Updates only the quantity for a single position and refreshes the uploaded timestamp.
    /// - Parameters:
    ///   - id: The primary key of the position.
    ///   - quantity: The new quantity value to persist.
    /// - Returns: True when the update succeeds.
    func updatePositionQuantity(id: Int, quantity: Double) -> Bool {
        let sql = "UPDATE PositionReports SET quantity = ?, uploaded_at = CURRENT_TIMESTAMP WHERE position_id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare quantity update: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_double(stmt, 1, quantity)
        sqlite3_bind_int(stmt, 2, Int32(id))
        let result = sqlite3_step(stmt) == SQLITE_DONE
        if !result {
            print("❌ Quantity update failed for position \(id): \(String(cString: sqlite3_errmsg(db)))")
        }
        return result
    }

    /// Deletes multiple position reports by their primary keys.
    /// - Parameter ids: The `position_id` values to delete.
    /// - Returns: The number of rows deleted.
    func deletePositionReports(ids: [Int]) -> Int {
        guard !ids.isEmpty else { return 0 }
        let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ", ")
        let sql = "DELETE FROM PositionReports WHERE position_id IN (\(placeholders));"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare bulk delete positions: \(String(cString: sqlite3_errmsg(db)))")
            return 0
        }
        defer { sqlite3_finalize(stmt) }
        for (i, id) in ids.enumerated() {
            sqlite3_bind_int(stmt, Int32(i + 1), Int32(id))
        }
        let step = sqlite3_step(stmt)
        let deleted = sqlite3_changes(db)
        if step == SQLITE_DONE {
            print("🗑️ Deleted \(deleted) position reports (ids: count=\(ids.count))")
        } else {
            print("❌ Failed to bulk delete positions: \(String(cString: sqlite3_errmsg(db)))")
        }
        return Int(deleted)
    }

    struct EditablePositionData: Identifiable {
        var id: Int
        var accountId: Int
        var institutionId: Int
        var instrumentId: Int
        var instrumentName: String
        var instrumentCurrency: String
        var quantity: Double
        var purchasePrice: Double?
        var currentPrice: Double?
        var instrumentUpdatedAt: Date?
        var notes: String?
        var reportDate: Date
        var importSessionId: Int?
    }

    func fetchEditablePositions(accountId: Int) -> [EditablePositionData] {
        var rows: [EditablePositionData] = []
        let sql = """
        SELECT pr.position_id, pr.account_id, pr.institution_id, pr.instrument_id,
               i.instrument_name, i.currency,
               pr.quantity, pr.purchase_price, pr.current_price,
               ipl.price AS latest_price,
               COALESCE(ipl.as_of, pr.instrument_updated_at) AS price_as_of,
               pr.notes, pr.report_date, pr.import_session_id
         FROM PositionReports pr
         JOIN Instruments i ON pr.instrument_id = i.instrument_id
          LEFT JOIN InstrumentPriceLatest ipl ON ipl.instrument_id = pr.instrument_id
         WHERE pr.account_id = ?
         ORDER BY (price_as_of IS NULL), price_as_of ASC, i.instrument_name COLLATE NOCASE ASC;
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(accountId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let accId = Int(sqlite3_column_int(stmt, 1))
                let instId = Int(sqlite3_column_int(stmt, 2))
                let instrId = Int(sqlite3_column_int(stmt, 3))
                let name = String(cString: sqlite3_column_text(stmt, 4))
                let instrumentCurrency = String(cString: sqlite3_column_text(stmt, 5))
                let qty = sqlite3_column_double(stmt, 6)
                var pPrice: Double?
                if sqlite3_column_type(stmt, 7) != SQLITE_NULL {
                    pPrice = sqlite3_column_double(stmt, 7)
                }
                var cPrice: Double?
                if sqlite3_column_type(stmt, 8) != SQLITE_NULL {
                    cPrice = sqlite3_column_double(stmt, 8)
                }
                var latestPrice: Double?
                if sqlite3_column_type(stmt, 9) != SQLITE_NULL {
                    latestPrice = sqlite3_column_double(stmt, 9)
                }
                var updated: Date?
                if sqlite3_column_type(stmt, 10) != SQLITE_NULL {
                    let str = String(cString: sqlite3_column_text(stmt, 10))
                    updated = ISO8601DateParser.parse(str)
                }
                let notes = sqlite3_column_text(stmt, 11).map { String(cString: $0) }
                let reportStr = String(cString: sqlite3_column_text(stmt, 12))
                let reportDate = DateFormatter.iso8601DateOnly.date(from: reportStr) ?? Date()
                let sess: Int?
                if sqlite3_column_type(stmt, 13) != SQLITE_NULL {
                    sess = Int(sqlite3_column_int(stmt, 13))
                } else { sess = nil }
                rows.append(EditablePositionData(
                    id: id,
                    accountId: accId,
                    institutionId: instId,
                    instrumentId: instrId,
                    instrumentName: name,
                    instrumentCurrency: instrumentCurrency,
                    quantity: qty,
                    purchasePrice: pPrice,
                    currentPrice: cPrice ?? latestPrice,
                    instrumentUpdatedAt: updated,
                    notes: notes,
                    reportDate: reportDate,
                    importSessionId: sess
                ))
            }
        } else {
            print("❌ Failed to prepare fetchEditablePositions: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(stmt)
        return rows
    }
}
