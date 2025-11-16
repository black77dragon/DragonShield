import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

extension DatabaseManager {
    func ichimokuFetchTickers(activeOnly: Bool = false,
                              sources: [IchimokuIndexSource]? = nil) -> [IchimokuTicker]
    {
        var tickers: [IchimokuTicker] = []
        var sql = "SELECT ticker_id, symbol, COALESCE(name,''), index_source, is_active, notes FROM ichimoku_tickers"
        var conditions: [String] = []
        if activeOnly { conditions.append("is_active = 1") }
        if let sources, !sources.isEmpty {
            let placeholders = Array(repeating: "?", count: sources.count).joined(separator: ",")
            conditions.append("index_source IN (\(placeholders))")
        }
        if !conditions.isEmpty {
            sql.append(" WHERE ")
            sql.append(conditions.joined(separator: " AND "))
        }
        sql.append(" ORDER BY index_source, symbol")

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("❌ ichimokuFetchTickers prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return []
        }
        defer { sqlite3_finalize(statement) }

        var bindIndex: Int32 = 1
        if let sources, !sources.isEmpty {
            for source in sources {
                sqlite3_bind_text(statement, bindIndex, (source.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
                bindIndex += 1
            }
        }

        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            guard let symbolCStr = sqlite3_column_text(statement, 1) else { continue }
            let symbol = String(cString: symbolCStr)
            let name = sqlite3_column_text(statement, 2).map { String(cString: $0) } ?? ""
            guard let indexCStr = sqlite3_column_text(statement, 3),
                  let index = IchimokuIndexSource(rawValue: String(cString: indexCStr)) else { continue }
            let isActive = sqlite3_column_int(statement, 4) == 1
            let notes = sqlite3_column_text(statement, 5).map { String(cString: $0) }

            tickers.append(IchimokuTicker(
                id: id,
                symbol: symbol,
                name: name,
                indexSource: index,
                isActive: isActive,
                notes: notes
            ))
        }
        return tickers
    }

    func ichimokuFetchTickerById(_ id: Int) -> IchimokuTicker? {
        let sql = "SELECT ticker_id, symbol, COALESCE(name,''), index_source, is_active, notes FROM ichimoku_tickers WHERE ticker_id = ?"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("❌ ichimokuFetchTickerById prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(id))
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        guard let symbolPtr = sqlite3_column_text(statement, 1) else { return nil }
        guard let indexPtr = sqlite3_column_text(statement, 3),
              let index = IchimokuIndexSource(rawValue: String(cString: indexPtr)) else { return nil }
        let symbol = String(cString: symbolPtr)
        let name = sqlite3_column_text(statement, 2).map { String(cString: $0) } ?? ""
        let isActive = sqlite3_column_int(statement, 4) == 1
        let notes = sqlite3_column_text(statement, 5).map { String(cString: $0) }
        return IchimokuTicker(id: Int(sqlite3_column_int(statement, 0)),
                              symbol: symbol,
                              name: name,
                              indexSource: index,
                              isActive: isActive,
                              notes: notes)
    }

    func ichimokuFetchTicker(symbol: String) -> IchimokuTicker? {
        let sql = "SELECT ticker_id, symbol, COALESCE(name,''), index_source, is_active, notes FROM ichimoku_tickers WHERE symbol = ?"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("❌ ichimokuFetchTicker prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (symbol.uppercased() as NSString).utf8String, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        let id = Int(sqlite3_column_int(statement, 0))
        let sym = String(cString: sqlite3_column_text(statement, 1))
        let name = sqlite3_column_text(statement, 2).map { String(cString: $0) } ?? ""
        guard let indexCStr = sqlite3_column_text(statement, 3),
              let index = IchimokuIndexSource(rawValue: String(cString: indexCStr)) else { return nil }
        let isActive = sqlite3_column_int(statement, 4) == 1
        let notes = sqlite3_column_text(statement, 5).map { String(cString: $0) }
        return IchimokuTicker(id: id,
                              symbol: sym,
                              name: name,
                              indexSource: index,
                              isActive: isActive,
                              notes: notes)
    }

    func ichimokuUpsertTicker(symbol: String,
                              name: String?,
                              indexSource: IchimokuIndexSource,
                              isActive: Bool = true,
                              notes: String? = nil) -> IchimokuTicker?
    {
        let sql = """
            INSERT INTO ichimoku_tickers (symbol, name, index_source, is_active, notes)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(symbol) DO UPDATE SET
                name = excluded.name,
                index_source = excluded.index_source,
                is_active = excluded.is_active,
                notes = excluded.notes,
                updated_at = CURRENT_TIMESTAMP;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("❌ ichimokuUpsertTicker prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (symbol.uppercased() as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if let name {
            sqlite3_bind_text(statement, 2, (name as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 2)
        }
        sqlite3_bind_text(statement, 3, (indexSource.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 4, isActive ? 1 : 0)
        if let notes {
            sqlite3_bind_text(statement, 5, (notes as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 5)
        }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            print("❌ ichimokuUpsertTicker execution failed: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        return ichimokuFetchTicker(symbol: symbol.uppercased())
    }

    func ichimokuSetTickerActive(tickerId: Int, isActive: Bool) -> Bool {
        let sql = "UPDATE ichimoku_tickers SET is_active = ?, updated_at = CURRENT_TIMESTAMP WHERE ticker_id = ?"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("❌ ichimokuSetTickerActive prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, isActive ? 1 : 0)
        sqlite3_bind_int(statement, 2, Int32(tickerId))
        let result = sqlite3_step(statement) == SQLITE_DONE
        if !result {
            print("❌ ichimokuSetTickerActive exec failed: \(String(cString: sqlite3_errmsg(db)))")
        }
        return result
    }
}
