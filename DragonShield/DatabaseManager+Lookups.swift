import Foundation
import SQLite3

extension DatabaseManager {
    struct IdName: Identifiable, Hashable { let id: Int; public let name: String }

    func listInstrumentNames(limit: Int = 500) -> [IdName] {
        guard let db else { return [] }
        var out: [IdName] = []
        let sql = "SELECT instrument_id, instrument_name FROM Instruments WHERE is_active = 1 ORDER BY instrument_name COLLATE NOCASE LIMIT ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 1))
                out.append(.init(id: id, name: name))
            }
        }
        sqlite3_finalize(stmt)
        return out
    }

    func listAccountNames(limit: Int = 500) -> [IdName] {
        guard let db else { return [] }
        var out: [IdName] = []
        let sql = "SELECT account_id, account_name FROM Accounts ORDER BY account_name COLLATE NOCASE LIMIT ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 1))
                out.append(.init(id: id, name: name))
            }
        }
        sqlite3_finalize(stmt)
        return out
    }

    func listPortfolioThemeNames(limit: Int = 500) -> [IdName] {
        guard let db else { return [] }
        var out: [IdName] = []
        let sql = "SELECT id, name FROM PortfolioTheme WHERE soft_delete = 0 ORDER BY name COLLATE NOCASE LIMIT ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 1))
                out.append(.init(id: id, name: name))
            }
        }
        sqlite3_finalize(stmt)
        return out
    }

    func listAssetClassNames(limit: Int = 500) -> [IdName] {
        guard let db else { return [] }
        var out: [IdName] = []
        let sql = "SELECT class_id, class_name FROM AssetClasses ORDER BY sort_order, class_name COLLATE NOCASE LIMIT ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 1))
                out.append(.init(id: id, name: name))
            }
        }
        sqlite3_finalize(stmt)
        return out
    }
}
