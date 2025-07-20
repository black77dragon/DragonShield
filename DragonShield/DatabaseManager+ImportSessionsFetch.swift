import SQLite3
import Foundation

extension DatabaseManager {
    struct ImportSessionData: Identifiable, Equatable {
        var id: Int
        var sessionName: String
        var fileName: String
        var filePath: String?
        var fileType: String
        var fileSize: Int
        var fileHash: String?
        var institutionId: Int?
        var importStatus: String
        var totalRows: Int
        var successfulRows: Int
        var failedRows: Int
        var duplicateRows: Int
        var errorLog: String?
        var processingNotes: String?
        var createdAt: Date
        var startedAt: Date?
        var completedAt: Date?
    }

    func fetchImportSessions() -> [ImportSessionData] {
        let sql = """
            SELECT import_session_id, session_name, file_name, file_path, file_type,
                   file_size, file_hash, institution_id, import_status, total_rows,
                   successful_rows, failed_rows, duplicate_rows, error_log,
                   processing_notes, created_at, started_at, completed_at
              FROM ImportSessions
             ORDER BY created_at DESC;
            """
        var stmt: OpaquePointer?
        var sessions: [ImportSessionData] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 1))
                let fileName = String(cString: sqlite3_column_text(stmt, 2))
                let filePath = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
                let fileType = String(cString: sqlite3_column_text(stmt, 4))
                let fileSize = Int(sqlite3_column_int(stmt, 5))
                let fileHash = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
                let instId = sqlite3_column_type(stmt, 7) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 7)) : nil
                let status = String(cString: sqlite3_column_text(stmt, 8))
                let totalRows = Int(sqlite3_column_int(stmt, 9))
                let successRows = Int(sqlite3_column_int(stmt, 10))
                let failedRows = Int(sqlite3_column_int(stmt, 11))
                let dupRows = Int(sqlite3_column_int(stmt, 12))
                let errorLog = sqlite3_column_text(stmt, 13).map { String(cString: $0) }
                let notes = sqlite3_column_text(stmt, 14).map { String(cString: $0) }
                let createdStr = String(cString: sqlite3_column_text(stmt, 15))
                let startedStr = sqlite3_column_text(stmt, 16).map { String(cString: $0) }
                let completedStr = sqlite3_column_text(stmt, 17).map { String(cString: $0) }
                let createdAt = DateFormatter.iso8601DateTime.date(from: createdStr) ?? Date()
                let startedAt = startedStr.flatMap { DateFormatter.iso8601DateTime.date(from: $0) }
                let completedAt = completedStr.flatMap { DateFormatter.iso8601DateTime.date(from: $0) }
                sessions.append(ImportSessionData(
                    id: id,
                    sessionName: name,
                    fileName: fileName,
                    filePath: filePath,
                    fileType: fileType,
                    fileSize: fileSize,
                    fileHash: fileHash,
                    institutionId: instId,
                    importStatus: status,
                    totalRows: totalRows,
                    successfulRows: successRows,
                    failedRows: failedRows,
                    duplicateRows: dupRows,
                    errorLog: errorLog,
                    processingNotes: notes,
                    createdAt: createdAt,
                    startedAt: startedAt,
                    completedAt: completedAt
                ))
            }
        } else {
            print("❌ Failed to prepare fetchImportSessions: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(stmt)
        return sessions
    }

    func totalReportValue(for sessionId: Int) -> Double {
        let sql = """
            SELECT SUM(pr.quantity * COALESCE(pr.current_price,0) *
                CASE WHEN instr.currency = 'CHF' THEN 1
                     ELSE COALESCE((SELECT rate_to_chf FROM ExchangeRates
                                      WHERE currency_code = instr.currency
                                      ORDER BY rate_date DESC LIMIT 1),1)
                END)
              FROM PositionReports pr
              JOIN Instruments instr ON pr.instrument_id = instr.instrument_id
             WHERE pr.import_session_id = ?;
            """
        var stmt: OpaquePointer?
        var total: Double = 0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(sessionId))
            if sqlite3_step(stmt) == SQLITE_ROW {
                total = sqlite3_column_double(stmt, 0)
            }
        } else {
            print("❌ Failed to prepare totalReportValue: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(stmt)
        return total
    }
}
