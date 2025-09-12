import SQLite3
import Foundation

// Backward-compatible schema detection for ExchangeRates table
private struct ExchangeRatesSchema {
    static var cached: (hasRateId: Bool, hasApiProvider: Bool, hasCreatedAt: Bool)?
    static func detect(in db: OpaquePointer?) -> (hasRateId: Bool, hasApiProvider: Bool, hasCreatedAt: Bool) {
        if let c = cached { return c }
        var hasRateId = false
        var hasApiProvider = false
        var hasCreatedAt = false
        guard let db else { cached = (hasRateId, hasApiProvider, hasCreatedAt); return cached! }
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA table_info(ExchangeRates);", -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let namePtr = sqlite3_column_text(stmt, 1) {
                    let name = String(cString: namePtr).lowercased()
                    switch name {
                    case "rate_id": hasRateId = true
                    case "api_provider": hasApiProvider = true
                    case "created_at": hasCreatedAt = true
                    default: break
                    }
                }
            }
        }
        sqlite3_finalize(stmt)
        cached = (hasRateId, hasApiProvider, hasCreatedAt)
        return cached!
    }
}

extension DatabaseManager {
    struct ExchangeRate: Identifiable, Equatable {
        var id: Int
        var currencyCode: String
        var rateDate: Date
        var rateToChf: Double
        var rateSource: String
        var apiProvider: String?
        var isLatest: Bool
        var createdAt: Date
    }

    func fetchExchangeRates(currencyCode: String? = nil, upTo date: Date? = nil) -> [ExchangeRate] {
        let schema = ExchangeRatesSchema.detect(in: db)
        var rates: [ExchangeRate] = []
        var selectCols = [String]()
        selectCols.append(schema.hasRateId ? "rate_id" : "rowid AS rate_id")
        selectCols.append(contentsOf: ["currency_code", "rate_date", "rate_to_chf", "rate_source"])
        selectCols.append(schema.hasApiProvider ? "api_provider" : "NULL AS api_provider")
        selectCols.append("is_latest")
        selectCols.append(schema.hasCreatedAt ? "created_at" : "datetime('now') AS created_at")
        var query = "SELECT " + selectCols.joined(separator: ", ") + " FROM ExchangeRates"
        if currencyCode != nil || date != nil {
            query += " WHERE"
        }
        var conditions: [String] = []
        if currencyCode != nil {
            conditions.append("currency_code = ?")
        }
        if date != nil {
            conditions.append("rate_date <= ?")
        }
        if !conditions.isEmpty {
            query += " " + conditions.joined(separator: " AND ")
        }
        query += " ORDER BY rate_date DESC;"

        var statement: OpaquePointer?
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            var index: Int32 = 1
            if let code = currencyCode {
                sqlite3_bind_text(statement, index, (code as NSString).utf8String, -1, SQLITE_TRANSIENT)
                index += 1
            }
            if let d = date {
                let str = DateFormatter.iso8601DateOnly.string(from: d)
                sqlite3_bind_text(statement, index, (str as NSString).utf8String, -1, SQLITE_TRANSIENT)
            }
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let code = String(cString: sqlite3_column_text(statement, 1))
                let dateStr = String(cString: sqlite3_column_text(statement, 2))
                let rateDate = DateFormatter.iso8601DateOnly.date(from: dateStr) ?? Date()
                let rateToChf = sqlite3_column_double(statement, 3)
                let source = String(cString: sqlite3_column_text(statement, 4))
                let apiProv = sqlite3_column_text(statement, 5).map { String(cString: $0) }
                let latest = sqlite3_column_int(statement, 6) == 1
                let createdStr = String(cString: sqlite3_column_text(statement, 7))
                let created = DateFormatter.iso8601DateTime.date(from: createdStr) ?? Date()

                rates.append(ExchangeRate(id: id, currencyCode: code, rateDate: rateDate, rateToChf: rateToChf, rateSource: source, apiProvider: apiProv, isLatest: latest, createdAt: created))
            }
        } else {
            print("❌ Failed to prepare fetchExchangeRates: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        return rates
    }

    func fetchLatestExchangeRate(currencyCode: String) -> ExchangeRate? {
        let schema = ExchangeRatesSchema.detect(in: db)
        var selectCols = [String]()
        selectCols.append(schema.hasRateId ? "rate_id" : "rowid AS rate_id")
        selectCols.append(contentsOf: ["currency_code", "rate_date", "rate_to_chf", "rate_source"])
        selectCols.append(schema.hasApiProvider ? "api_provider" : "NULL AS api_provider")
        selectCols.append("is_latest")
        selectCols.append(schema.hasCreatedAt ? "created_at" : "datetime('now') AS created_at")
        let query = """
            SELECT \(selectCols.joined(separator: ", "))
              FROM ExchangeRates
             WHERE currency_code = ? AND is_latest = 1
             LIMIT 1;
        """
        var statement: OpaquePointer?
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        var rate: ExchangeRate?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (currencyCode as NSString).utf8String, -1, SQLITE_TRANSIENT)
            if sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let code = String(cString: sqlite3_column_text(statement, 1))
                let dateStr = String(cString: sqlite3_column_text(statement, 2))
                let rateDate = DateFormatter.iso8601DateOnly.date(from: dateStr) ?? Date()
                let rateToChf = sqlite3_column_double(statement, 3)
                let source = String(cString: sqlite3_column_text(statement, 4))
                let apiProv = sqlite3_column_text(statement, 5).map { String(cString: $0) }
                let latest = sqlite3_column_int(statement, 6) == 1
                let createdStr = String(cString: sqlite3_column_text(statement, 7))
                let created = DateFormatter.iso8601DateTime.date(from: createdStr) ?? Date()
                rate = ExchangeRate(id: id, currencyCode: code, rateDate: rateDate, rateToChf: rateToChf, rateSource: source, apiProvider: apiProv, isLatest: latest, createdAt: created)
            }
        } else {
            print("❌ Failed to prepare fetchLatestExchangeRate: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        return rate
    }

    func insertExchangeRate(currencyCode: String, rateDate: Date, rateToChf: Double, rateSource: String, apiProvider: String?, isLatest: Bool) -> Bool {
        // If we mark this as latest, clear previous latest for this currency first.
        if isLatest {
            let clear = "UPDATE ExchangeRates SET is_latest = 0 WHERE currency_code = ?;"
            var s: OpaquePointer?
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            if sqlite3_prepare_v2(db, clear, -1, &s, nil) == SQLITE_OK {
                sqlite3_bind_text(s, 1, (currencyCode as NSString).utf8String, -1, SQLITE_TRANSIENT)
                _ = sqlite3_step(s)
            }
            sqlite3_finalize(s)
        }

        // Use UPSERT to avoid UNIQUE constraint failures on (currency_code, rate_date).
        let hasApi = ExchangeRatesSchema.detect(in: db).hasApiProvider
        let query: String
        if hasApi {
            query = """
                INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, api_provider, is_latest)
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(currency_code, rate_date)
                DO UPDATE SET rate_to_chf = excluded.rate_to_chf,
                              rate_source = excluded.rate_source,
                              api_provider = excluded.api_provider,
                              is_latest = excluded.is_latest;
            """
        } else {
            query = """
                INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(currency_code, rate_date)
                DO UPDATE SET rate_to_chf = excluded.rate_to_chf,
                              rate_source = excluded.rate_source,
                              is_latest = excluded.is_latest;
            """
        }
        var statement: OpaquePointer?
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare insertExchangeRate: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        sqlite3_bind_text(statement, 1, (currencyCode as NSString).utf8String, -1, SQLITE_TRANSIENT)
        let dateStr = DateFormatter.iso8601DateOnly.string(from: rateDate)
        sqlite3_bind_text(statement, 2, (dateStr as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 3, rateToChf)
        sqlite3_bind_text(statement, 4, (rateSource as NSString).utf8String, -1, SQLITE_TRANSIENT)
        var nextIndex: Int32 = 5
        if hasApi {
            if let api = apiProvider {
                sqlite3_bind_text(statement, nextIndex, (api as NSString).utf8String, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(statement, nextIndex)
            }
            nextIndex += 1
        }
        sqlite3_bind_int(statement, nextIndex, isLatest ? 1 : 0)
        let result = sqlite3_step(statement) == SQLITE_DONE
        if !result {
            let msg = String(cString: sqlite3_errmsg(db))
            print("❌ insertExchangeRate step failed for \(currencyCode) date=\(dateStr): \(msg)")
        }
        sqlite3_finalize(statement)
        return result
    }

    func updateExchangeRate(id: Int, rateDate: Date, rateToChf: Double, rateSource: String, apiProvider: String?, isLatest: Bool) -> Bool {
        let schema = ExchangeRatesSchema.detect(in: db)
        let hasApi = schema.hasApiProvider
        let hasId = schema.hasRateId
        if isLatest {
            let clear: String = hasId
                ? "UPDATE ExchangeRates SET is_latest = 0 WHERE currency_code = (SELECT currency_code FROM ExchangeRates WHERE rate_id = ?);"
                : "UPDATE ExchangeRates SET is_latest = 0 WHERE currency_code = (SELECT currency_code FROM ExchangeRates WHERE rowid = ?);"
            var s: OpaquePointer?
            if sqlite3_prepare_v2(db, clear, -1, &s, nil) == SQLITE_OK {
                sqlite3_bind_int(s, 1, Int32(id))
                _ = sqlite3_step(s)
            }
            sqlite3_finalize(s)
        }
        let query: String
        if hasApi && hasId {
            query = """
                UPDATE ExchangeRates
                   SET rate_date = ?, rate_to_chf = ?, rate_source = ?, api_provider = ?, is_latest = ?
                 WHERE rate_id = ?;
            """
        } else if !hasApi && hasId {
            query = """
                UPDATE ExchangeRates
                   SET rate_date = ?, rate_to_chf = ?, rate_source = ?, is_latest = ?
                 WHERE rate_id = ?;
            """
        } else if hasApi && !hasId {
            query = """
                UPDATE ExchangeRates
                   SET rate_date = ?, rate_to_chf = ?, rate_source = ?, api_provider = ?, is_latest = ?
                 WHERE currency_code = (SELECT currency_code FROM ExchangeRates WHERE rowid = ?);
            """
        } else {
            query = """
                UPDATE ExchangeRates
                   SET rate_date = ?, rate_to_chf = ?, rate_source = ?, is_latest = ?
                 WHERE currency_code = (SELECT currency_code FROM ExchangeRates WHERE rowid = ?);
            """
        }
        var statement: OpaquePointer?
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare updateExchangeRate: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        let dateStr = DateFormatter.iso8601DateOnly.string(from: rateDate)
        var idx: Int32 = 1
        sqlite3_bind_text(statement, idx, (dateStr as NSString).utf8String, -1, SQLITE_TRANSIENT); idx += 1
        sqlite3_bind_double(statement, idx, rateToChf); idx += 1
        sqlite3_bind_text(statement, idx, (rateSource as NSString).utf8String, -1, SQLITE_TRANSIENT); idx += 1
        if hasApi {
            if let api = apiProvider { sqlite3_bind_text(statement, idx, (api as NSString).utf8String, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(statement, idx) }
            idx += 1
        }
        sqlite3_bind_int(statement, idx, isLatest ? 1 : 0); idx += 1
        sqlite3_bind_int(statement, idx, Int32(id))
        let result = sqlite3_step(statement) == SQLITE_DONE
        if !result {
            let msg = String(cString: sqlite3_errmsg(db))
            print("❌ updateExchangeRate step failed id=\(id) date=\(dateStr): \(msg)")
        }
        sqlite3_finalize(statement)
        return result
    }

    func deleteExchangeRate(id: Int) -> Bool {
        let hasId = ExchangeRatesSchema.detect(in: db).hasRateId
        let query = hasId ? "DELETE FROM ExchangeRates WHERE rate_id = ?;" : "DELETE FROM ExchangeRates WHERE rowid = ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare deleteExchangeRate: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        sqlite3_bind_int(statement, 1, Int32(id))
        let result = sqlite3_step(statement) == SQLITE_DONE
        if !result {
            let msg = String(cString: sqlite3_errmsg(db))
            print("❌ deleteExchangeRate step failed id=\(id): \(msg)")
        }
        sqlite3_finalize(statement)
        return result
    }
}
