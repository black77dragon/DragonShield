// DragonShield/DatabaseManager+PositionReports.swift
// MARK: - Version 1.2 (2025-06-16)
// MARK: - History
// - 1.1 -> 1.2: Minor clean up and documentation tweaks.
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
        var reportDate: Date
        var uploadedAt: Date
}

extension DatabaseManager {

    func fetchPositionReports() -> [PositionReportData] {
        var reports: [PositionReportData] = []
        let query = """
            SELECT pr.position_id, pr.import_session_id, a.account_name,
                   i.instrument_name, pr.quantity, pr.report_date, pr.uploaded_at
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
                let reportDateStr = String(cString: sqlite3_column_text(statement, 5))
                let uploadedAtStr = String(cString: sqlite3_column_text(statement, 6))
                let reportDate = DateFormatter.iso8601DateOnly.date(from: reportDateStr) ?? Date()
                let uploadedAt = DateFormatter.iso8601DateTime.date(from: uploadedAtStr) ?? Date()
                reports.append(PositionReportData(
                    id: id,
                    importSessionId: sessionId,
                    accountName: accountName,
                    instrumentName: instrumentName,
                    quantity: quantity,
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
}
