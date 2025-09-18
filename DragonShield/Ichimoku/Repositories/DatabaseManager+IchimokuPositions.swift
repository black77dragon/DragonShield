import Foundation
import SQLite3

private let SQLITE_TRANSIENT_POSITION = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

extension DatabaseManager {
    func ichimokuFetchPositions(includeClosed: Bool = false) -> [IchimokuPositionRow] {
        var sql = """
            SELECT p.position_id, p.date_opened, p.status, p.confirmed_by_user, p.last_evaluated, p.last_close, p.last_kijun,
                   t.ticker_id, t.symbol, COALESCE(t.name,''), t.index_source, t.is_active, t.notes
              FROM ichimoku_positions p
              JOIN ichimoku_tickers t ON t.ticker_id = p.ticker_id
        """
        if !includeClosed {
            sql.append(" WHERE p.status = 'ACTIVE'")
        }
        sql.append(" ORDER BY datetime(p.date_opened) DESC")
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("❌ ichimokuFetchPositions prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return []
        }
        defer { sqlite3_finalize(statement) }
        var rows: [IchimokuPositionRow] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let positionId = Int(sqlite3_column_int(statement, 0))
            guard let openedPtr = sqlite3_column_text(statement, 1),
                  let dateOpened = DateFormatter.iso8601DateOnly.date(from: String(cString: openedPtr)) else { continue }
            guard let statusPtr = sqlite3_column_text(statement, 2),
                  let status = IchimokuPositionStatus(rawValue: String(cString: statusPtr)) else { continue }
            let confirmed = sqlite3_column_int(statement, 3) == 1
            let lastEval = sqlite3_column_text(statement, 4).flatMap { DateFormatter.iso8601DateOnly.date(from: String(cString: $0)) }
            let lastClose = sqlite3_column_type(statement, 5) == SQLITE_NULL ? nil : sqlite3_column_double(statement, 5)
            let lastKijun = sqlite3_column_type(statement, 6) == SQLITE_NULL ? nil : sqlite3_column_double(statement, 6)
            let tickerId = Int(sqlite3_column_int(statement, 7))
            let symbol = sqlite3_column_text(statement, 8).map { String(cString: $0) } ?? ""
            let name = sqlite3_column_text(statement, 9).map { String(cString: $0) } ?? ""
            guard let indexPtr = sqlite3_column_text(statement, 10),
                  let index = IchimokuIndexSource(rawValue: String(cString: indexPtr)) else { continue }
            let isActive = sqlite3_column_int(statement, 11) == 1
            let notes = sqlite3_column_text(statement, 12).map { String(cString: $0) }

            let ticker = IchimokuTicker(id: tickerId,
                                        symbol: symbol,
                                        name: name,
                                        indexSource: index,
                                        isActive: isActive,
                                        notes: notes)

            rows.append(IchimokuPositionRow(
                id: positionId,
                ticker: ticker,
                dateOpened: dateOpened,
                status: status,
                confirmedByUser: confirmed,
                lastEvaluated: lastEval,
                lastClose: lastClose,
                lastKijun: lastKijun
            ))
        }
        return rows
    }

    func ichimokuFindActivePosition(tickerId: Int) -> IchimokuPositionRow? {
        ichimokuFetchPositions(includeClosed: false).first { $0.ticker.id == tickerId }
    }

    @discardableResult
    func ichimokuCreatePosition(tickerId: Int,
                                opened: Date,
                                confirmed: Bool) -> IchimokuPositionRow? {
        if let existing = ichimokuFindActivePosition(tickerId: tickerId) { return existing }
        let sql = """
            INSERT INTO ichimoku_positions (ticker_id, date_opened, status, confirmed_by_user)
            VALUES (?, ?, 'ACTIVE', ?)
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("❌ ichimokuCreatePosition prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(tickerId))
        let openedStr = DateFormatter.iso8601DateOnly.string(from: opened)
        sqlite3_bind_text(statement, 2, (openedStr as NSString).utf8String, -1, SQLITE_TRANSIENT_POSITION)
        sqlite3_bind_int(statement, 3, confirmed ? 1 : 0)
        let result = sqlite3_step(statement)
        if result != SQLITE_DONE {
            print("❌ ichimokuCreatePosition insert failed: code=\(result) err=\(String(cString: sqlite3_errmsg(db)))")
        }
        return ichimokuFetchPositions(includeClosed: true).first { $0.ticker.id == tickerId }
    }

    func ichimokuUpdatePositionStatus(positionId: Int,
                                      status: IchimokuPositionStatus,
                                      closedDate: Date? = nil) -> Bool {
        var sql = "UPDATE ichimoku_positions SET status = ?, updated_at = CURRENT_TIMESTAMP"
        if let closedDate = closedDate {
            sql.append(", last_evaluated = ?")
        }
        sql.append(" WHERE position_id = ?")
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("❌ ichimokuUpdatePositionStatus prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, (status.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT_POSITION)
        var index: Int32 = 2
        if let closedDate = closedDate {
            sqlite3_bind_text(statement, index, (DateFormatter.iso8601DateOnly.string(from: closedDate) as NSString).utf8String, -1, SQLITE_TRANSIENT_POSITION)
            index += 1
        }
        sqlite3_bind_int(statement, index, Int32(positionId))
        let result = sqlite3_step(statement) == SQLITE_DONE
        if !result {
            print("❌ ichimokuUpdatePositionStatus exec failed: \(String(cString: sqlite3_errmsg(db)))")
        }
        return result
    }

    func ichimokuUpdatePositionEvaluation(positionId: Int,
                                          evaluatedOn: Date,
                                          close: Double?,
                                          kijun: Double?) -> Bool {
        let sql = """
            UPDATE ichimoku_positions
               SET last_evaluated = ?,
                   last_close = ?,
                   last_kijun = ?,
                   updated_at = CURRENT_TIMESTAMP
             WHERE position_id = ?;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("❌ ichimokuUpdatePositionEvaluation prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, (DateFormatter.iso8601DateOnly.string(from: evaluatedOn) as NSString).utf8String, -1, SQLITE_TRANSIENT_POSITION)
        if let close {
            sqlite3_bind_double(statement, 2, close)
        } else {
            sqlite3_bind_null(statement, 2)
        }
        if let kijun {
            sqlite3_bind_double(statement, 3, kijun)
        } else {
            sqlite3_bind_null(statement, 3)
        }
        sqlite3_bind_int(statement, 4, Int32(positionId))
        let ok = sqlite3_step(statement) == SQLITE_DONE
        if !ok {
            print("❌ ichimokuUpdatePositionEvaluation exec failed: \(String(cString: sqlite3_errmsg(db)))")
        }
        return ok
    }


    func ichimokuSetPositionConfirmation(positionId: Int, confirmed: Bool) -> Bool {
        let sql = "UPDATE ichimoku_positions SET confirmed_by_user = ?, updated_at = CURRENT_TIMESTAMP WHERE position_id = ?"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("❌ ichimokuSetPositionConfirmation prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, confirmed ? 1 : 0)
        sqlite3_bind_int(statement, 2, Int32(positionId))
        let ok = sqlite3_step(statement) == SQLITE_DONE
        if !ok {
            print("❌ ichimokuSetPositionConfirmation exec failed: \(String(cString: sqlite3_errmsg(db)))")
        }
        return ok
    }

    func ichimokuInsertSellAlert(tickerId: Int,
                                 alertDate: Date,
                                 closePrice: Double,
                                 kijunValue: Double?,
                                 reason: String) -> IchimokuSellAlertRow? {
        let sql = """
            INSERT INTO ichimoku_sell_alerts (ticker_id, alert_date, close_price, kijun_value, reason)
            VALUES (?, ?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("❌ ichimokuInsertSellAlert prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(tickerId))
        sqlite3_bind_text(statement, 2, (DateFormatter.iso8601DateOnly.string(from: alertDate) as NSString).utf8String, -1, SQLITE_TRANSIENT_POSITION)
        sqlite3_bind_double(statement, 3, closePrice)
        if let kijunValue {
            sqlite3_bind_double(statement, 4, kijunValue)
        } else {
            sqlite3_bind_null(statement, 4)
        }
        sqlite3_bind_text(statement, 5, (reason as NSString).utf8String, -1, SQLITE_TRANSIENT_POSITION)
        let ok = sqlite3_step(statement) == SQLITE_DONE
        if !ok {
            print("❌ ichimokuInsertSellAlert exec failed: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        let alertId = Int(sqlite3_last_insert_rowid(db))
        return ichimokuFetchSellAlert(alertId: alertId)
    }

    func ichimokuFetchSellAlert(alertId: Int) -> IchimokuSellAlertRow? {
        let sql = """
            SELECT a.alert_id, a.alert_date, a.close_price, a.kijun_value, a.reason, a.resolved_at,
                   t.ticker_id, t.symbol, COALESCE(t.name,''), t.index_source, t.is_active, t.notes
              FROM ichimoku_sell_alerts a
              JOIN ichimoku_tickers t ON t.ticker_id = a.ticker_id
             WHERE a.alert_id = ?
             LIMIT 1;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(alertId))
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        guard let datePtr = sqlite3_column_text(statement, 1),
              let alertDate = DateFormatter.iso8601DateOnly.date(from: String(cString: datePtr)) else { return nil }
        let closePrice = sqlite3_column_double(statement, 2)
        let kijunValue = sqlite3_column_type(statement, 3) == SQLITE_NULL ? nil : sqlite3_column_double(statement, 3)
        let reason = sqlite3_column_text(statement, 4).map { String(cString: $0) } ?? ""
        let resolvedAt = sqlite3_column_text(statement, 5).flatMap { DateFormatter.iso8601DateOnly.date(from: String(cString: $0)) }
        let tickerId = Int(sqlite3_column_int(statement, 6))
        let symbol = sqlite3_column_text(statement, 7).map { String(cString: $0) } ?? ""
        let name = sqlite3_column_text(statement, 8).map { String(cString: $0) } ?? ""
        guard let indexPtr = sqlite3_column_text(statement, 9),
              let index = IchimokuIndexSource(rawValue: String(cString: indexPtr)) else { return nil }
        let isActive = sqlite3_column_int(statement, 10) == 1
        let notes = sqlite3_column_text(statement, 11).map { String(cString: $0) }
        let ticker = IchimokuTicker(id: tickerId,
                                    symbol: symbol,
                                    name: name,
                                    indexSource: index,
                                    isActive: isActive,
                                    notes: notes)
        return IchimokuSellAlertRow(id: Int(sqlite3_column_int(statement, 0)),
                                    ticker: ticker,
                                    alertDate: alertDate,
                                    closePrice: closePrice,
                                    kijunValue: kijunValue,
                                    reason: reason,
                                    resolvedAt: resolvedAt)
    }

    func ichimokuFetchSellAlerts(limit: Int? = nil,
                                 unresolvedOnly: Bool = false) -> [IchimokuSellAlertRow] {
        var sql = """
            SELECT a.alert_id, a.alert_date, a.close_price, a.kijun_value, a.reason, a.resolved_at,
                   t.ticker_id, t.symbol, COALESCE(t.name,''), t.index_source, t.is_active, t.notes
              FROM ichimoku_sell_alerts a
              JOIN ichimoku_tickers t ON t.ticker_id = a.ticker_id
        """
        if unresolvedOnly {
            sql.append(" WHERE a.resolved_at IS NULL")
        }
        sql.append(" ORDER BY datetime(a.alert_date) DESC")
        if let limit, limit > 0 {
            sql.append(" LIMIT \(limit)")
        }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("❌ ichimokuFetchSellAlerts prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return []
        }
        defer { sqlite3_finalize(statement) }
        var rows: [IchimokuSellAlertRow] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let alertId = Int(sqlite3_column_int(statement, 0))
            guard let datePtr = sqlite3_column_text(statement, 1),
                  let alertDate = DateFormatter.iso8601DateOnly.date(from: String(cString: datePtr)) else { continue }
            let closePrice = sqlite3_column_double(statement, 2)
            let kijunValue = sqlite3_column_type(statement, 3) == SQLITE_NULL ? nil : sqlite3_column_double(statement, 3)
            let reason = sqlite3_column_text(statement, 4).map { String(cString: $0) } ?? ""
            let resolvedAt = sqlite3_column_text(statement, 5).flatMap { DateFormatter.iso8601DateOnly.date(from: String(cString: $0)) }
            let tickerId = Int(sqlite3_column_int(statement, 6))
            let symbol = sqlite3_column_text(statement, 7).map { String(cString: $0) } ?? ""
            let name = sqlite3_column_text(statement, 8).map { String(cString: $0) } ?? ""
            guard let indexPtr = sqlite3_column_text(statement, 9),
                  let index = IchimokuIndexSource(rawValue: String(cString: indexPtr)) else { continue }
            let isActive = sqlite3_column_int(statement, 10) == 1
            let notes = sqlite3_column_text(statement, 11).map { String(cString: $0) }
            let ticker = IchimokuTicker(id: tickerId,
                                        symbol: symbol,
                                        name: name,
                                        indexSource: index,
                                        isActive: isActive,
                                        notes: notes)
            rows.append(IchimokuSellAlertRow(
                id: alertId,
                ticker: ticker,
                alertDate: alertDate,
                closePrice: closePrice,
                kijunValue: kijunValue,
                reason: reason,
                resolvedAt: resolvedAt
            ))
        }
        return rows
    }

    func ichimokuResolveSellAlert(alertId: Int, resolvedAt: Date = Date()) -> Bool {
        let sql = "UPDATE ichimoku_sell_alerts SET resolved_at = ?, updated_at = CURRENT_TIMESTAMP WHERE alert_id = ?"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("❌ ichimokuResolveSellAlert prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        defer { sqlite3_finalize(statement) }
        let dateStr = DateFormatter.iso8601DateOnly.string(from: resolvedAt)
        sqlite3_bind_text(statement, 1, (dateStr as NSString).utf8String, -1, SQLITE_TRANSIENT_POSITION)
        sqlite3_bind_int(statement, 2, Int32(alertId))
        let ok = sqlite3_step(statement) == SQLITE_DONE
        if !ok {
            print("❌ ichimokuResolveSellAlert exec failed: \(String(cString: sqlite3_errmsg(db)))")
        }
        return ok
    }
}
