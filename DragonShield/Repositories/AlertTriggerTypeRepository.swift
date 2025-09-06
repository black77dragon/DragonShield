// DragonShield/Repositories/AlertTriggerTypeRepository.swift

import Foundation
import SQLite3

struct AlertTriggerTypeRow: Identifiable, Hashable {
    let id: Int
    let code: String
    let displayName: String
    let description: String?
    let sortOrder: Int
    let active: Bool
}

final class AlertTriggerTypeRepository {
    private let db: OpaquePointer?

    init(dbManager: DatabaseManager) {
        self.db = dbManager.db
    }

    func listActive() -> [AlertTriggerTypeRow] {
        guard let db else { return [] }
        let sql = "SELECT id, code, display_name, description, sort_order, active FROM AlertTriggerType WHERE active = 1 ORDER BY sort_order, id"
        var stmt: OpaquePointer?
        var rows: [AlertTriggerTypeRow] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let code = String(cString: sqlite3_column_text(stmt, 1))
                let name = String(cString: sqlite3_column_text(stmt, 2))
                let desc = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
                let order = Int(sqlite3_column_int(stmt, 4))
                let active = sqlite3_column_int(stmt, 5) == 1
                rows.append(AlertTriggerTypeRow(id: id, code: code, displayName: name, description: desc, sortOrder: order, active: active))
            }
        }
        return rows
    }
}

