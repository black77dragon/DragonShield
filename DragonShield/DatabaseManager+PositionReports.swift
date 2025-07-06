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
        var instrumentName: String
        var quantity: Double
        var purchasePrice: Double?
        var currentPrice: Double?
        var reportDate: Date
        var uploadedAt: Date
}

extension DatabaseManager {

    func fetchPositionReports() -> [PositionReportData] {
        var reports: [PositionReportData] = []
        let query = """
            SELECT pr.position_id, pr.import_session_id, a.account_name,
                   i.instrument_name, pr.quantity, pr.purchase_price,
                   pr.current_price, pr.report_date, pr.uploaded_at
            FROM PositionReports pr
            JOIN Accounts a ON pr.account_id = a.account_id
            JOIN Instruments i ON pr.instrument_id = i.instrument_id
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
                let instrumentName = String(cString: sqlite3_column_text(statement, 3))
                let quantity = sqlite3_column_double(statement, 4)
                var purchasePrice: Double?
                if sqlite3_column_type(statement, 5) != SQLITE_NULL {
                    purchasePrice = sqlite3_column_double(statement, 5)
                }
                var currentPrice: Double?
                if sqlite3_column_type(statement, 6) != SQLITE_NULL {
                    currentPrice = sqlite3_column_double(statement, 6)
                }
                let reportDateStr = String(cString: sqlite3_column_text(statement, 7))
                let uploadedAtStr = String(cString: sqlite3_column_text(statement, 8))
                let reportDate = DateFormatter.iso8601DateOnly.date(from: reportDateStr) ?? Date()
                let uploadedAt = DateFormatter.iso8601DateTime.date(from: uploadedAtStr) ?? Date()
                reports.append(PositionReportData(
                    id: id,
                    importSessionId: sessionId,
                    accountName: accountName,
                    instrumentName: instrumentName,
                    quantity: quantity,
                    purchasePrice: purchasePrice,
                    currentPrice: currentPrice,
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

    /// Deletes position reports where the associated account belongs to the given institution.
    /// - Parameter institution: The institution name to match (case-insensitive).
    /// - Returns: The number of deleted rows.
    func deletePositionReports(institutionName institution: String) -> Int {
        let sql = """
            DELETE FROM PositionReports
            WHERE account_id IN (
                SELECT a.account_id FROM Accounts a
                JOIN Institutions i ON a.institution_id = i.institution_id
                WHERE i.institution_name = ? COLLATE NOCASE
            );
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare deletePositionReports: \(String(cString: sqlite3_errmsg(db)))")
            return 0
        }
        sqlite3_bind_text(stmt, 1, institution, -1, nil)
        let stepResult = sqlite3_step(stmt)
        let deleted = sqlite3_changes(db)
        sqlite3_finalize(stmt)
        if stepResult == SQLITE_DONE {
            print("✅ Deleted \(deleted) position reports for institution \(institution)")
        } else {
            print("❌ Failed to delete position reports: \(String(cString: sqlite3_errmsg(db)))")
        }
        return Int(deleted)
    }
}
