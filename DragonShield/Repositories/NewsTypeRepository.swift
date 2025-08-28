// DragonShield/Repositories/NewsTypeRepository.swift

import Foundation
import SQLite3

struct NewsTypeRow: Identifiable {
    let id: Int
    let code: String
    let displayName: String
    let sortOrder: Int
    let active: Bool
}

final class NewsTypeRepository {
    private let db: OpaquePointer?

    init(dbManager: DatabaseManager) {
        self.db = dbManager.db
    }

    func listActive() -> [NewsTypeRow] {
        guard let db else { return [] }
        let sql = "SELECT id, code, display_name, sort_order, active FROM NewsType WHERE active = 1 ORDER BY sort_order, id"
        var stmt: OpaquePointer?
        var rows: [NewsTypeRow] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let code = String(cString: sqlite3_column_text(stmt, 1))
                let name = String(cString: sqlite3_column_text(stmt, 2))
                let order = Int(sqlite3_column_int(stmt, 3))
                let active = sqlite3_column_int(stmt, 4) == 1
                rows.append(NewsTypeRow(id: id, code: code, displayName: name, sortOrder: order, active: active))
            }
        }
        return rows
    }
}

