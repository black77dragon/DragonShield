import SQLite3
import Foundation

extension DatabaseManager {
    private static let fxFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private static var rateCache: [String: (Double, Date)] = [:]

    /// Returns the FX rate from one currency to another and the date of the rate used.
    /// - Parameters:
    ///   - from: Source currency (e.g., "USD").
    ///   - to: Target currency (e.g., "CHF"). Defaults to the manager's baseCurrency.
    ///   - asOf: Optional date to use; the latest rate on or before this date is used.
    func fxRate(from: String, to: String? = nil, asOf: Date? = nil) -> (rate: Double, date: Date)? {
        let source = from.uppercased()
        let target = (to ?? baseCurrency).uppercased()
        if source == target { return (1.0, asOf ?? Date()) }
        let cacheKey = "\(source)->\(target)"
        if let cached = Self.rateCache[cacheKey], asOf == nil { return cached }
        guard let db else { return nil }
        let dateStr = asOf.map { Self.fxFormatter.string(from: $0) } ?? Self.fxFormatter.string(from: Date())
        let sql = "SELECT rate_to_chf, rate_date FROM ExchangeRates WHERE currency_code = ? AND rate_date <= ? ORDER BY rate_date DESC LIMIT 1"
        func query(_ code: String) -> (Double, Date)? {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, code, -1, nil)
                sqlite3_bind_text(stmt, 2, dateStr, -1, nil)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    let rate = sqlite3_column_double(stmt, 0)
                    let d: Date
                    if let cString = sqlite3_column_text(stmt, 1),
                       let parsed = Self.fxFormatter.date(from: String(cString: cString)) {
                        d = parsed
                    } else {
                        LoggingService.shared.log("Failed to parse rate_date for currency '\(code)', falling back to asOf", type: .warning, logger: .database)
                        d = asOf ?? Date()
                    }
                    return (rate, d)
                }
            }
            return nil
        }
        guard let fromInfo = query(source) else { return nil }
        let toInfo: (Double, Date)
        if target == "CHF" {
            toInfo = (1.0, fromInfo.1)
        } else if let base = query(target) {
            toInfo = base
        } else {
            return nil
        }
        let usedDate = max(fromInfo.1, toInfo.1)
        let rate: Double
        if target == "CHF" {
            rate = fromInfo.0
        } else if source == "CHF" {
            rate = 1.0 / toInfo.0
        } else {
            rate = fromInfo.0 / toInfo.0
        }
        if asOf == nil { Self.rateCache[cacheKey] = (rate, usedDate) }
        return (rate, usedDate)
    }

    /// Converts an amount from one currency into the base currency (default CHF).
    /// - Parameters:
    ///   - amount: Amount in source currency.
    ///   - currency: Source currency code.
    ///   - asOf: Optional date determining which FX rate to use.
    ///   - to: Target currency, defaults to baseCurrency.
    /// - Returns: Tuple of converted value and rate date, or nil if rate missing.
    func convert(amount: Double, from currency: String, to target: String? = nil, asOf: Date? = nil) -> (value: Double, date: Date)? {
        guard let info = fxRate(from: currency, to: target, asOf: asOf) else { return nil }
        return (amount * info.rate, info.date)
    }
}
