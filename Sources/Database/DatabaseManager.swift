import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public struct ValidationFinding: Identifiable, Equatable {
    public let id: Int
    public let entityType: String
    public let entityId: Int
    public let severity: String
    public let code: String
    public let message: String
    public let detailsJSON: String?
    public let computedAt: String
    public let scopeName: String?
}

public protocol DBGateway {
    func fetchClassValidationStatuses() -> [Int: String]
    func fetchSubClassValidationStatuses() -> [Int: String]
    func fetchValidationFindingsForClass(_ classId: Int) -> [ValidationFinding]
    func fetchValidationFindingsForSubClass(_ subId: Int) -> [ValidationFinding]
}

public final class DatabaseManager: DBGateway {
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "db.serial.queue")

    public init(path: String) throws {
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(path, &db, flags, nil) != SQLITE_OK {
            let msg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        sqlite3_exec(db, "PRAGMA foreign_keys=ON;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA synchronous=NORMAL;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA busy_timeout=5000;", nil, nil, nil)
    }

    deinit {
        if let pointer = db {
            sqlite3_close_v2(pointer)
        }
    }

    private func string(from statement: OpaquePointer?, index: Int32) -> String {
        guard let cStr = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: cStr)
    }

    @discardableResult
    public func execute(sql: String) -> Int32 {
        queue.sync { sqlite3_exec(db, sql, nil, nil, nil) }
    }

    public func querySingleString(sql: String) -> String? {
        queue.sync {
            var stmt: OpaquePointer?
            var result: String?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                defer { sqlite3_finalize(stmt) }
                if sqlite3_step(stmt) == SQLITE_ROW {
                    result = sqlite3_column_text(stmt, 0).map { String(cString: $0) }
                }
            }
            return result
        }
    }

    public func fetchClassValidationStatuses() -> [Int: String] {
        queue.sync {
            var results: [Int: String] = [:]
            let sql = "SELECT class_id, validation_status FROM V_ClassValidationStatus;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                defer { sqlite3_finalize(stmt) }
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let id = Int(sqlite3_column_int(stmt, 0))
                    let status = string(from: stmt, index: 1)
                    results[id] = status
                }
            }
            let updateSQL = "UPDATE ClassTargets SET validation_status=? WHERE class_id=?;"
            var update: OpaquePointer?
            if sqlite3_prepare_v2(db, updateSQL, -1, &update, nil) == SQLITE_OK {
                for (id, status) in results {
                    sqlite3_bind_text(update, 1, status, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_int(update, 2, Int32(id))
                    sqlite3_step(update)
                    sqlite3_reset(update)
                }
                sqlite3_finalize(update)
            }
            return results
        }
    }

    public func fetchSubClassValidationStatuses() -> [Int: String] {
        queue.sync {
            var results: [Int: String] = [:]
            let sql = "SELECT sub_class_id, validation_status FROM V_SubClassValidationStatus;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                defer { sqlite3_finalize(stmt) }
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let id = Int(sqlite3_column_int(stmt, 0))
                    let status = string(from: stmt, index: 1)
                    results[id] = status
                }
            }
            let updateSQL = "UPDATE SubClassTargets SET validation_status=? WHERE sub_class_id=?;"
            var update: OpaquePointer?
            if sqlite3_prepare_v2(db, updateSQL, -1, &update, nil) == SQLITE_OK {
                for (id, status) in results {
                    sqlite3_bind_text(update, 1, status, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_int(update, 2, Int32(id))
                    sqlite3_step(update)
                    sqlite3_reset(update)
                }
                sqlite3_finalize(update)
            }
            return results
        }
    }

    public func fetchValidationFindingsForClass(_ classId: Int) -> [ValidationFinding] {
        queue.sync {
            var findings: [ValidationFinding] = []
            let sql = """
            SELECT vf.id, vf.entity_type, vf.entity_id, vf.severity, vf.code, vf.message, vf.details_json, vf.computed_at,
                   CASE
                     WHEN vf.entity_type='subclass' THEN (
                       SELECT name FROM AssetSubClasses s WHERE s.sub_class_id=vf.entity_id
                     )
                     ELSE (
                       SELECT name FROM AssetClasses ac WHERE ac.class_id=?
                     )
                   END AS scope_name
            FROM ValidationFindings vf
            WHERE (vf.entity_type='class' AND vf.entity_id=?)
               OR (vf.entity_type='subclass' AND vf.entity_id IN (
                    SELECT sub_class_id FROM AssetSubClasses WHERE class_id=?
               ))
            ORDER BY CASE vf.severity WHEN 'error' THEN 2 WHEN 'warning' THEN 1 ELSE 0 END DESC,
                     vf.code ASC,
                     vf.computed_at DESC;
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(classId))
                sqlite3_bind_int(stmt, 2, Int32(classId))
                sqlite3_bind_int(stmt, 3, Int32(classId))
                defer { sqlite3_finalize(stmt) }
                while sqlite3_step(stmt) == SQLITE_ROW {
                    findings.append(parseFinding(stmt))
                }
            }
            return findings
        }
    }

    public func fetchValidationFindingsForSubClass(_ subId: Int) -> [ValidationFinding] {
        queue.sync {
            var findings: [ValidationFinding] = []
            let sql = """
            SELECT vf.id, vf.entity_type, vf.entity_id, vf.severity, vf.code, vf.message, vf.details_json, vf.computed_at,
                   (SELECT name FROM AssetSubClasses s WHERE s.sub_class_id=vf.entity_id) AS scope_name
            FROM ValidationFindings vf
            WHERE vf.entity_type='subclass' AND vf.entity_id=?
            ORDER BY CASE vf.severity WHEN 'error' THEN 2 WHEN 'warning' THEN 1 ELSE 0 END DESC,
                     vf.code ASC,
                     vf.computed_at DESC;
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(subId))
                defer { sqlite3_finalize(stmt) }
                while sqlite3_step(stmt) == SQLITE_ROW {
                    findings.append(parseFinding(stmt))
                }
            }
            return findings
        }
    }

    private func parseFinding(_ stmt: OpaquePointer?) -> ValidationFinding {
        ValidationFinding(
            id: Int(sqlite3_column_int(stmt, 0)),
            entityType: string(from: stmt, index: 1),
            entityId: Int(sqlite3_column_int(stmt, 2)),
            severity: string(from: stmt, index: 3),
            code: string(from: stmt, index: 4),
            message: string(from: stmt, index: 5),
            detailsJSON: sqlite3_column_text(stmt, 6).map { String(cString: $0) },
            computedAt: string(from: stmt, index: 7),
            scopeName: sqlite3_column_text(stmt, 8).map { String(cString: $0) }
        )
    }
}
