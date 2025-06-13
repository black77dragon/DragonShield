// DragonShield/DatabaseManager+Portfolios.swift
// MARK: - Version 1.0 (2025-05-30)
// MARK: - History
// - Initial creation: Refactored from DatabaseManager.swift.

import SQLite3
import Foundation

extension DatabaseManager {

    func fetchPortfolios() -> [(id: Int, name: String, isDefault: Bool)] {
        var portfolios: [(id: Int, name: String, isDefault: Bool)] = []
        let query = "SELECT portfolio_id, portfolio_name, is_default FROM Portfolios ORDER BY sort_order, portfolio_name"
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let name = String(cString: sqlite3_column_text(statement, 1))
                let isDefault = sqlite3_column_int(statement, 2) == 1
                portfolios.append((id: id, name: name, isDefault: isDefault))
            }
        } else {
            print("❌ Failed to prepare fetchPortfolios: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        return portfolios
    }
}
