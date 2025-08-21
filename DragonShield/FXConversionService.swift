import Foundation
import SQLite3

struct FXConversionService {
    struct ConversionResult {
        let value: Double
        let rate: Double
        let rateAsOf: Date
    }

    private let dbManager: DatabaseManager
    private static let formatter = ISO8601DateFormatter()

    init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
    }

    func convert(amount: Double, from fromCcy: String, to toCcy: String, asOf: Date) -> ConversionResult? {
        if fromCcy == toCcy {
            return ConversionResult(value: amount, rate: 1.0, rateAsOf: asOf)
        }
        guard let db = dbManager.db else { return nil }
        let dateStr = Self.formatter.string(from: asOf)
        let sql = "SELECT rate_to_chf, rate_date FROM ExchangeRates WHERE currency_code = ? AND rate_date <= ? ORDER BY rate_date DESC LIMIT 1"

        func query(_ ccy: String) -> (Double, Date)? {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, ccy, -1, nil)
                sqlite3_bind_text(stmt, 2, dateStr, -1, nil)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    let rate = sqlite3_column_double(stmt, 0)
                    let date: Date
                    if let cString = sqlite3_column_text(stmt, 1),
                       let d = Self.formatter.date(from: String(cString: cString)) {
                        date = d
                    } else {
                        LoggingService.shared.log("Failed to parse rate_date for currency '\(ccy)', falling back to position date.", type: .warning, logger: .database)
                        date = asOf
                    }
                    return (rate, date)
                }
            }
            return nil
        }

        guard let fromInfo = query(fromCcy) else { return nil }
        let toInfo: (Double, Date)
        if toCcy == "CHF" {
            toInfo = (1.0, fromInfo.1)
        } else if let info = query(toCcy) {
            toInfo = info
        } else {
            return nil
        }
        let usedDate = max(fromInfo.1, toInfo.1)
        let rate: Double
        if toCcy == "CHF" {
            rate = fromInfo.0
        } else if fromCcy == "CHF" {
            rate = 1.0 / toInfo.0
        } else {
            rate = fromInfo.0 / toInfo.0
        }
        return ConversionResult(value: amount * rate, rate: rate, rateAsOf: usedDate)
    }
}
