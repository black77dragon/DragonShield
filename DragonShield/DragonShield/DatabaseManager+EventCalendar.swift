import Foundation
import SQLite3

struct EventCalendarRow: Identifiable, Hashable {
    let id: Int
    let code: String
    let title: String
    let category: String
    let eventDate: String
    let eventTime: String?
    let timezone: String?
    let status: String
    let source: String?
    let notes: String?
}

extension DatabaseManager {
    func listEventCalendar(search: String? = nil, limit: Int = 200) -> [EventCalendarRow] {
        guard let db else { return [] }
        var sql = "SELECT id, code, title, category, event_date, event_time, timezone, status, source, notes FROM EventCalendar"
        var params: [String] = []
        if let q = search?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty {
            sql += " WHERE code LIKE ? OR title LIKE ? OR category LIKE ?"
            let pattern = "%" + q + "%"
            params = [pattern, pattern, pattern]
        }
        sql += " ORDER BY event_date ASC, (event_time IS NULL), event_time ASC LIMIT ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        var bindIndex: Int32 = 1
        for p in params {
            sqlite3_bind_text(stmt, bindIndex, p, -1, SQLITE_TRANSIENT)
            bindIndex += 1
        }
        sqlite3_bind_int(stmt, bindIndex, Int32(limit))
        var rows: [EventCalendarRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(eventCalendarRow(from: stmt))
        }
        return rows
    }

    func getEventCalendar(code: String) -> EventCalendarRow? {
        guard let db else { return nil }
        let sql = "SELECT id, code, title, category, event_date, event_time, timezone, status, source, notes FROM EventCalendar WHERE code = ? LIMIT 1"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, code, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) == SQLITE_ROW {
            return eventCalendarRow(from: stmt)
        }
        return nil
    }

    private func eventCalendarRow(from stmt: OpaquePointer?) -> EventCalendarRow {
        let id = Int(sqlite3_column_int(stmt, 0))
        let code = String(cString: sqlite3_column_text(stmt, 1))
        let title = String(cString: sqlite3_column_text(stmt, 2))
        let category = String(cString: sqlite3_column_text(stmt, 3))
        let eventDate = String(cString: sqlite3_column_text(stmt, 4))
        let eventTime = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
        let timezone = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
        let status = String(cString: sqlite3_column_text(stmt, 7))
        let source = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
        let notes = sqlite3_column_text(stmt, 9).map { String(cString: $0) }
        return EventCalendarRow(id: id,
                                code: code,
                                title: title,
                                category: category,
                                eventDate: eventDate,
                                eventTime: eventTime,
                                timezone: timezone,
                                status: status,
                                source: source,
                                notes: notes)
    }
}
