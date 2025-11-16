import Foundation
import SQLite3

extension DatabaseManager {
    enum SystemJobKey: String {
        case fxUpdate = "fx_update"
        case iosSnapshotExport = "ios_snapshot_export"
    }

    enum SystemJobStatus: String {
        case success = "SUCCESS"
        case partial = "PARTIAL"
        case failed = "FAILED"

        var displayName: String {
            switch self {
            case .success: return "Success"
            case .partial: return "Partial"
            case .failed: return "Failed"
            }
        }
    }

    struct SystemJobRun: Identifiable {
        let id: Int
        let jobKey: String
        let status: SystemJobStatus
        let message: String?
        let metadata: [String: Any]?
        let startedAt: Date
        let finishedAt: Date
        let durationMs: Int?

        var finishedOrStarted: Date { finishedAt }
        var recognizedJobKey: SystemJobKey? { SystemJobKey(rawValue: jobKey) }
    }

    @discardableResult
    func recordSystemJobRun(jobKey: SystemJobKey,
                            status: SystemJobStatus,
                            message: String?,
                            metadata: [String: Any]? = nil,
                            startedAt: Date = Date(),
                            finishedAt: Date? = nil,
                            durationMs: Int? = nil) -> Bool
    {
        let sql = """
            INSERT INTO SystemJobRuns (job_key, status, message, metadata_json, started_at, finished_at, duration_ms)
            VALUES (?, ?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare recordSystemJobRun: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        defer { sqlite3_finalize(stmt) }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let finish = finishedAt ?? startedAt
        let startStr = DateFormatter.iso8601DateTime.string(from: startedAt)
        let finishStr = DateFormatter.iso8601DateTime.string(from: finish)
        let metadataJSON = metadata.flatMap { metadataDict -> String? in
            guard JSONSerialization.isValidJSONObject(metadataDict) else { return nil }
            if let data = try? JSONSerialization.data(withJSONObject: metadataDict, options: []),
               let s = String(data: data, encoding: .utf8)
            {
                return s
            }
            return nil
        }

        sqlite3_bind_text(stmt, 1, (jobKey.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, (status.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if let msg = message { sqlite3_bind_text(stmt, 3, (msg as NSString).utf8String, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 3) }
        if let meta = metadataJSON { sqlite3_bind_text(stmt, 4, (meta as NSString).utf8String, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 4) }
        sqlite3_bind_text(stmt, 5, (startStr as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 6, (finishStr as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if let ms = durationMs { sqlite3_bind_int(stmt, 7, Int32(ms)) } else { sqlite3_bind_null(stmt, 7) }

        let ok = sqlite3_step(stmt) == SQLITE_DONE
        if !ok {
            print("❌ recordSystemJobRun insert failed: \(String(cString: sqlite3_errmsg(db)))")
        }
        return ok
    }

    func fetchLastSystemJobRun(jobKey: SystemJobKey) -> SystemJobRun? {
        let sql = """
            SELECT run_id, job_key, status, message, metadata_json, started_at, finished_at, duration_ms
              FROM SystemJobRuns
             WHERE job_key = ?
             ORDER BY datetime(finished_at) DESC
             LIMIT 1;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare fetchLastSystemJobRun: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, (jobKey.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)

        if sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(stmt, 0))
            let jobKeyStr = String(cString: sqlite3_column_text(stmt, 1))
            let statusStr = String(cString: sqlite3_column_text(stmt, 2))
            let message = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
            let metadataStr = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
            let startedStr = String(cString: sqlite3_column_text(stmt, 5))
            let finishedStr = String(cString: sqlite3_column_text(stmt, 6))
            let durationType = sqlite3_column_type(stmt, 7)
            let durationMs = (durationType == SQLITE_NULL) ? nil : Int(sqlite3_column_int(stmt, 7))

            let status = SystemJobStatus(rawValue: statusStr) ?? .failed
            let startedAt = DateFormatter.iso8601DateTime.date(from: startedStr) ?? Date()
            let finishedAt = DateFormatter.iso8601DateTime.date(from: finishedStr) ?? startedAt
            var metadata: [String: Any]? = nil
            if let metaStr = metadataStr, let data = metaStr.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            {
                metadata = obj
            }

            return SystemJobRun(id: id,
                                jobKey: jobKeyStr,
                                status: status,
                                message: message,
                                metadata: metadata,
                                startedAt: startedAt,
                                finishedAt: finishedAt,
                                durationMs: durationMs)
        }
        return nil
    }
}
