import Foundation
import SQLite3

final class FXConverter {
    private let dbManager: DatabaseManager
    private static let dateFormatter = ISO8601DateFormatter()
    private var cache: [String: (rate: Double, date: Date)] = [:]

    init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
    }

    func convert(value: Double, from valueCcy: String, to baseCcy: String, asOf: Date?, fxAsOf: inout Date?) -> Double? {
        guard let rate = fetchRate(from: valueCcy, to: baseCcy, asOf: asOf, fxAsOf: &fxAsOf) else { return nil }
        return value * rate
    }

    func chfValue(value: Double, currency: String, asOf: Date?, fxAsOf: inout Date?) -> Double? {
        convert(value: value, from: currency, to: "CHF", asOf: asOf, fxAsOf: &fxAsOf)
    }

    private func fetchRate(from valueCcy: String, to baseCcy: String, asOf: Date?, fxAsOf: inout Date?) -> Double? {
        let from = valueCcy.uppercased()
        let to = baseCcy.uppercased()
        if from == to { return 1.0 }
        guard let db = dbManager.db else { return nil }
        let dateStr = asOf.map { Self.dateFormatter.string(from: $0) } ?? Self.dateFormatter.string(from: Date())
        let sql = "SELECT rate_to_chf, rate_date FROM ExchangeRates WHERE currency_code = ? AND rate_date <= ? ORDER BY rate_date DESC LIMIT 1"

        func query(_ ccy: String) -> (Double, Date)? {
            if let cached = cache[ccy], cached.date <= (asOf ?? .distantFuture) {
                return cached
            }
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, ccy, -1, nil)
                sqlite3_bind_text(stmt, 2, dateStr, -1, nil)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    let rate = sqlite3_column_double(stmt, 0)
                    let date: Date
                    if let cString = sqlite3_column_text(stmt, 1),
                       let d = Self.dateFormatter.date(from: String(cString: cString)) {
                        date = d
                    } else {
                        LoggingService.shared.log("Failed to parse rate_date for currency '\(ccy)', falling back to position date.", type: .warning, logger: .database)
                        date = asOf ?? Date()
                    }
                    cache[ccy] = (rate, date)
                    return (rate, date)
                }
            }
            return nil
        }

        guard let valueInfo = query(from) else { return nil }
        let baseInfo: (Double, Date)
        if to == "CHF" {
            baseInfo = (1.0, valueInfo.1)
        } else if let info = query(to) {
            baseInfo = info
        } else {
            return nil
        }

        let usedDate = max(valueInfo.1, baseInfo.1)
        if usedDate > (fxAsOf ?? .distantPast) { fxAsOf = usedDate }

        if to == "CHF" {
            return valueInfo.0
        } else if from == "CHF" {
            return 1.0 / baseInfo.0
        } else {
            return valueInfo.0 / baseInfo.0
        }
    }
}
