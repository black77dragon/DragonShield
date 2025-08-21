import SQLite3
import Foundation

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
        var rates: [ExchangeRate] = []
        var query = """
            SELECT rate_id, currency_code, rate_date, rate_to_chf, rate_source, api_provider, is_latest, created_at
              FROM ExchangeRates
        """
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
        let query = """
            SELECT rate_id, currency_code, rate_date, rate_to_chf, rate_source, api_provider, is_latest, created_at
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
        let query = """
            INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, api_provider, is_latest)
            VALUES (?, ?, ?, ?, ?, ?);
        """
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
        if let api = apiProvider {
            sqlite3_bind_text(statement, 5, (api as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 5)
        }
        sqlite3_bind_int(statement, 6, isLatest ? 1 : 0)
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        return result
    }

    func updateExchangeRate(id: Int, rateDate: Date, rateToChf: Double, rateSource: String, apiProvider: String?, isLatest: Bool) -> Bool {
        if isLatest {
            let clear = "UPDATE ExchangeRates SET is_latest = 0 WHERE currency_code = (SELECT currency_code FROM ExchangeRates WHERE rate_id = ?);"
            var s: OpaquePointer?
            if sqlite3_prepare_v2(db, clear, -1, &s, nil) == SQLITE_OK {
                sqlite3_bind_int(s, 1, Int32(id))
                _ = sqlite3_step(s)
            }
            sqlite3_finalize(s)
        }
        let query = """
            UPDATE ExchangeRates
               SET rate_date = ?, rate_to_chf = ?, rate_source = ?, api_provider = ?, is_latest = ?
             WHERE rate_id = ?;
        """
        var statement: OpaquePointer?
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare updateExchangeRate: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        let dateStr = DateFormatter.iso8601DateOnly.string(from: rateDate)
        sqlite3_bind_text(statement, 1, (dateStr as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 2, rateToChf)
        sqlite3_bind_text(statement, 3, (rateSource as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if let api = apiProvider {
            sqlite3_bind_text(statement, 4, (api as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 4)
        }
        sqlite3_bind_int(statement, 5, isLatest ? 1 : 0)
        sqlite3_bind_int(statement, 6, Int32(id))
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        return result
    }

    func deleteExchangeRate(id: Int) -> Bool {
        let query = "DELETE FROM ExchangeRates WHERE rate_id = ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare deleteExchangeRate: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        sqlite3_bind_int(statement, 1, Int32(id))
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        return result
    }

    /// Resolve an FX rate between two currencies as of an optional date.
    /// - Returns: Tuple of rate and the rate's date, or nil if not found.
    func exchangeRate(from fromCode: String, to toCode: String, asOf: Date? = nil) -> (rate: Double, rateDate: Date)? {
        let from = fromCode.uppercased()
        let to = toCode.uppercased()
        if from == to { return (1.0, asOf ?? Date()) }
        guard let db else { return nil }

        let df = ISO8601DateFormatter()
        let dateStr = df.string(from: asOf ?? Date())
        let query = "SELECT rate_to_chf, rate_date FROM ExchangeRates WHERE currency_code = ? AND rate_date <= ? ORDER BY rate_date DESC LIMIT 1"
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        func fetch(_ ccy: String) -> (Double, Date)? {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return nil }
            sqlite3_bind_text(stmt, 1, (ccy as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, (dateStr as NSString).utf8String, -1, SQLITE_TRANSIENT)
            guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
            let rate = sqlite3_column_double(stmt, 0)
            if let cString = sqlite3_column_text(stmt, 1),
               let d = df.date(from: String(cString: cString)) {
                return (rate, d)
            } else {
                LoggingService.shared.log("Failed to parse rate_date for currency '\(ccy)', falling back to as-of date.", type: .warning, logger: .database)
                return (rate, asOf ?? Date())
            }
        }

        guard let fromInfo = fetch(from) else { return nil }
        let toInfo: (Double, Date)
        if to == "CHF" {
            toInfo = (1.0, fromInfo.1)
        } else if let info = fetch(to) {
            toInfo = info
        } else {
            return nil
        }

        let usedDate = max(fromInfo.1, toInfo.1)
        let rate: Double
        if to == "CHF" {
            rate = fromInfo.0
        } else if from == "CHF" {
            rate = 1.0 / toInfo.0
        } else {
            rate = fromInfo.0 / toInfo.0
        }
        return (rate, usedDate)
    }

    /// Convert an amount from a given currency to the manager's base currency.
    /// - Parameters:
    ///   - amount: Nominal amount in the source currency.
    ///   - currencyCode: ISO currency code of the amount.
    ///   - asOf: Optional valuation date.
    /// - Returns: Tuple of converted value and FX rate date, or nil if rate missing.
    func convertToBase(amount: Double, currencyCode: String, asOf: Date? = nil) -> (value: Double, rateDate: Date)? {
        let base = baseCurrency
        guard let (rate, date) = exchangeRate(from: currencyCode, to: base, asOf: asOf) else { return nil }
        return (amount * rate, date)
    }
}

