import Foundation
import SQLite3

struct PortfolioTimelineRow: Identifiable, Hashable {
    let id: Int
    let description: String
    let timeIndication: String
    let sortOrder: Int
    let active: Bool
}

final class PortfolioTimelineRepository {
    private let connection: DatabaseConnection
    private var db: OpaquePointer? { connection.db }

    init(connection: DatabaseConnection) {
        self.connection = connection
    }

    convenience init(dbManager: DatabaseManager) {
        self.init(connection: dbManager.databaseConnection)
    }

    func listActive() -> [PortfolioTimelineRow] {
        listPortfolioTimelines(includeInactive: false)
    }

    func listPortfolioTimelines(includeInactive: Bool = true) -> [PortfolioTimelineRow] {
        var rows: [PortfolioTimelineRow] = []
        guard let db else { return rows }
        let sql = includeInactive
            ? "SELECT id, description, time_indication, sort_order, is_active FROM PortfolioTimelines ORDER BY sort_order, id"
            : "SELECT id, description, time_indication, sort_order, is_active FROM PortfolioTimelines WHERE is_active = 1 ORDER BY sort_order, id"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let description = String(cString: sqlite3_column_text(stmt, 1))
                let timeIndication = String(cString: sqlite3_column_text(stmt, 2))
                let order = Int(sqlite3_column_int(stmt, 3))
                let active = sqlite3_column_int(stmt, 4) == 1
                rows.append(PortfolioTimelineRow(id: id, description: description, timeIndication: timeIndication, sortOrder: order, active: active))
            }
        }
        return rows
    }

    func createPortfolioTimeline(description: String, timeIndication: String, sortOrder: Int, active: Bool) -> PortfolioTimelineRow? {
        guard let db else { return nil }
        let sql = "INSERT INTO PortfolioTimelines(description, time_indication, sort_order, is_active) VALUES(?,?,?,?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, description, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, timeIndication, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 3, Int32(sortOrder))
        sqlite3_bind_int(stmt, 4, active ? 1 : 0)
        guard sqlite3_step(stmt) == SQLITE_DONE else { return nil }
        let id = Int(sqlite3_last_insert_rowid(db))
        return PortfolioTimelineRow(id: id, description: description, timeIndication: timeIndication, sortOrder: sortOrder, active: active)
    }

    func updatePortfolioTimeline(id: Int, description: String?, timeIndication: String?, sortOrder: Int?, active: Bool?) -> Bool {
        guard let db else { return false }
        var sets: [String] = []
        var bind: [Any?] = []
        if let description { sets.append("description = ?"); bind.append(description) }
        if let timeIndication { sets.append("time_indication = ?"); bind.append(timeIndication) }
        if let sortOrder { sets.append("sort_order = ?"); bind.append(sortOrder) }
        if let active { sets.append("is_active = ?"); bind.append(active ? 1 : 0) }
        guard !sets.isEmpty else { return true }
        let sql = "UPDATE PortfolioTimelines SET \(sets.joined(separator: ", ")) WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        var idx: Int32 = 1
        for v in bind {
            if let s = v as? String { sqlite3_bind_text(stmt, idx, s, -1, SQLITE_TRANSIENT) }
            else if let i = v as? Int { sqlite3_bind_int(stmt, idx, Int32(i)) }
            else if let i = v as? Int32 { sqlite3_bind_int(stmt, idx, i) }
            else if let i = v as? Int64 { sqlite3_bind_int64(stmt, idx, i) }
            else { sqlite3_bind_null(stmt, idx) }
            idx += 1
        }
        sqlite3_bind_int(stmt, idx, Int32(id))
        return sqlite3_step(stmt) == SQLITE_DONE && sqlite3_changes(db) > 0
    }

    func deletePortfolioTimeline(id: Int) -> Bool {
        guard let db else { return false }
        var stmt: OpaquePointer?
        let sql = "UPDATE PortfolioTimelines SET is_active = 0 WHERE id = ? AND is_active = 1"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        sqlite3_bind_int(stmt, 1, Int32(id))
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_DONE && sqlite3_changes(db) > 0
    }

    func reorderPortfolioTimelines(idsInOrder: [Int]) -> Bool {
        guard let db else { return false }
        var ok = true
        var order = 1
        for id in idsInOrder {
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, "UPDATE PortfolioTimelines SET sort_order = ? WHERE id = ?", -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(order))
                sqlite3_bind_int(stmt, 2, Int32(id))
                ok = ok && (sqlite3_step(stmt) == SQLITE_DONE)
            } else {
                ok = false
            }
            sqlite3_finalize(stmt)
            order += 1
        }
        return ok
    }
}
