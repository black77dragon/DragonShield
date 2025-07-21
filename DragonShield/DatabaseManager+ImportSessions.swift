import Foundation
import SQLite3
import CryptoKit

extension DatabaseManager {
    /// Creates a new import session and returns its id.
    func startImportSession(sessionName: String, fileName: String, filePath: String, fileType: String, fileSize: Int, fileHash: String, institutionId: Int?) -> Int? {
        let sql = """
            INSERT INTO ImportSessions (session_name, file_name, file_path, file_type, file_size, file_hash, institution_id, import_status, started_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, 'PROCESSING', datetime('now'));
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare startImportSession: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, sessionName, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, fileName, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, filePath, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, fileType, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 5, Int32(fileSize))
        sqlite3_bind_text(stmt, 6, fileHash, -1, SQLITE_TRANSIENT)
        if let inst = institutionId {
            sqlite3_bind_int(stmt, 7, Int32(inst))
        } else {
            sqlite3_bind_null(stmt, 7)
        }
        var result = sqlite3_step(stmt)
        if result != SQLITE_DONE {
            let code = sqlite3_errcode(db)
            let msg = String(cString: sqlite3_errmsg(db))
            if code == SQLITE_CONSTRAINT && msg.contains("file_hash") {
                sqlite3_reset(stmt)
                let newHash = fileHash + "-" + UUID().uuidString
                sqlite3_bind_text(stmt, 6, newHash, -1, SQLITE_TRANSIENT)
                result = sqlite3_step(stmt)
            }
            if result != SQLITE_DONE {
                print("❌ Failed to insert ImportSession: \(msg)")
                return nil
            }
        }
        return Int(sqlite3_last_insert_rowid(db))
    }

    /// Returns true if a session with the given name already exists.
    private func importSessionExists(name: String) -> Bool {
        let query = "SELECT 1 FROM ImportSessions WHERE session_name=? LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare importSessionExists: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, name, -1, nil)
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    /// Generates a unique session name by appending an incrementing suffix if needed.
    func nextImportSessionName(base: String) -> String {
        var name = base
        var counter = 0
        while importSessionExists(name: name) {
            counter += 1
            name = "\(base) (\(counter))"
        }
        return name
    }

    func completeImportSession(id: Int, totalRows: Int, successRows: Int, failedRows: Int, duplicateRows: Int, notes: String?) {
        let sql = """
            UPDATE ImportSessions
               SET import_status='COMPLETED', total_rows=?, successful_rows=?, failed_rows=?, duplicate_rows=?, processing_notes=?, completed_at=datetime('now')
             WHERE import_session_id=?;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare completeImportSession: \(String(cString: sqlite3_errmsg(db)))")
            return
        }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_int(stmt, 1, Int32(totalRows))
        sqlite3_bind_int(stmt, 2, Int32(successRows))
        sqlite3_bind_int(stmt, 3, Int32(failedRows))
        sqlite3_bind_int(stmt, 4, Int32(duplicateRows))
        if let notes = notes {
            sqlite3_bind_text(stmt, 5, notes, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 5)
        }
        sqlite3_bind_int(stmt, 6, Int32(id))
        if sqlite3_step(stmt) != SQLITE_DONE {
            print("❌ Failed to update ImportSession: \(String(cString: sqlite3_errmsg(db)))")
        }
    }

    struct ImportSessionData: Identifiable, Equatable {
        var id: Int
        var sessionName: String
        var fileName: String
        var fileType: String
        var fileSize: Int
        var fileHash: String
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
        var sessions: [ImportSessionData] = []
        let query = """
            SELECT import_session_id, session_name, file_name, file_type, file_size, file_hash,
                   institution_id, import_status, total_rows, successful_rows, failed_rows,
                   duplicate_rows, error_log, processing_notes, created_at, started_at, completed_at
              FROM ImportSessions
             ORDER BY created_at DESC;
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let sessionName = String(cString: sqlite3_column_text(stmt, 1))
                let fileName = String(cString: sqlite3_column_text(stmt, 2))
                let fileType = String(cString: sqlite3_column_text(stmt, 3))
                let fileSize = Int(sqlite3_column_int(stmt, 4))
                let fileHash = String(cString: sqlite3_column_text(stmt, 5))
                let institutionId: Int?
                if sqlite3_column_type(stmt, 6) != SQLITE_NULL {
                    institutionId = Int(sqlite3_column_int(stmt, 6))
                } else { institutionId = nil }
                let status = String(cString: sqlite3_column_text(stmt, 7))
                let totalRows = Int(sqlite3_column_int(stmt, 8))
                let success = Int(sqlite3_column_int(stmt, 9))
                let failed = Int(sqlite3_column_int(stmt, 10))
                let dup = Int(sqlite3_column_int(stmt, 11))
                let errorLog = sqlite3_column_text(stmt, 12).map { String(cString: $0) }
                let notes = sqlite3_column_text(stmt, 13).map { String(cString: $0) }
                let createdStr = String(cString: sqlite3_column_text(stmt, 14))
                let startedStr = sqlite3_column_text(stmt, 15).map { String(cString: $0) }
                let completedStr = sqlite3_column_text(stmt, 16).map { String(cString: $0) }
                let created = DateFormatter.iso8601DateTime.date(from: createdStr) ?? Date()
                let started = startedStr.flatMap { DateFormatter.iso8601DateTime.date(from: $0) }
                let completed = completedStr.flatMap { DateFormatter.iso8601DateTime.date(from: $0) }
                sessions.append(ImportSessionData(id: id, sessionName: sessionName, fileName: fileName,
                                                 fileType: fileType, fileSize: fileSize, fileHash: fileHash,
                                                 institutionId: institutionId, importStatus: status,
                                                 totalRows: totalRows, successfulRows: success,
                                                 failedRows: failed, duplicateRows: dup,
                                                 errorLog: errorLog, processingNotes: notes,
                                                 createdAt: created, startedAt: started,
                                                 completedAt: completed))
            }
        } else {
            print("❌ Failed to prepare fetchImportSessions: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(stmt)
        return sessions
    }

    func totalReportValueForSession(_ id: Int) -> Double {
        var total: Double = 0
        var rateCache: [String: Double] = [:]
        let query = """
            SELECT pr.quantity, pr.current_price, i.currency, pr.report_date
              FROM PositionReports pr
              JOIN Instruments i ON pr.instrument_id = i.instrument_id
             WHERE pr.import_session_id = ?;
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let qty = sqlite3_column_double(stmt, 0)
                if sqlite3_column_type(stmt, 1) == SQLITE_NULL { continue }
                let price = sqlite3_column_double(stmt, 1)
                var value = qty * price
                let currency = String(cString: sqlite3_column_text(stmt, 2)).uppercased()
                if currency != "CHF" {
                    let dateStr = String(cString: sqlite3_column_text(stmt, 3))
                    let date = DateFormatter.iso8601DateOnly.date(from: dateStr)
                    var rate = rateCache[currency]
                    if rate == nil {
                        rate = fetchExchangeRates(currencyCode: currency, upTo: date).first?.rateToChf
                        if let r = rate { rateCache[currency] = r }
                    }
                    if let r = rate { value *= r } else { continue }
                }
                total += value
            }
        }
        sqlite3_finalize(stmt)
        return total
    }

    func positionValuesForSession(_ id: Int) -> [(instrument: String, currency: String, valueOrig: Double, valueChf: Double)] {
        var items: [(String, String, Double, Double)] = []
        var rateCache: [String: Double] = [:]
        let query = """
            SELECT i.instrument_name, i.currency, pr.quantity, pr.current_price, pr.report_date
              FROM PositionReports pr
              JOIN Instruments i ON pr.instrument_id = i.instrument_id
             WHERE pr.import_session_id = ?;
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let name = String(cString: sqlite3_column_text(stmt, 0))
                let currency = String(cString: sqlite3_column_text(stmt, 1)).uppercased()
                let qty = sqlite3_column_double(stmt, 2)
                guard sqlite3_column_type(stmt, 3) != SQLITE_NULL else { continue }
                let price = sqlite3_column_double(stmt, 3)
                var value = qty * price
                let dateStr = String(cString: sqlite3_column_text(stmt, 4))
                let date = DateFormatter.iso8601DateOnly.date(from: dateStr)
                var rate = 1.0
                if currency != "CHF" {
                    if let cached = rateCache[currency] {
                        rate = cached
                    } else {
                        if let r = fetchExchangeRates(currencyCode: currency, upTo: date).first?.rateToChf {
                            rateCache[currency] = r
                            rate = r
                        } else {
                            continue
                        }
                    }
                }
                items.append((name, currency, value, value * rate))
            }
        }
        sqlite3_finalize(stmt)
        return items
    }
}

extension URL {
    /// Computes the SHA256 hash of a file at this URL.
    func sha256() -> String? {
        guard let data = try? Data(contentsOf: self) else { return nil }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
