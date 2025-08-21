import Foundation
import SQLite3

struct FXConversionService {
    struct Result {
        let value: Double
        let rate: Double
        let rateAsOf: Date
    }

    static func convert(amount: Double, fromCcy: String, toCcy: String, asOf: Date, db: DatabaseManager) -> Result? {
        let from = fromCcy.uppercased()
        let to = toCcy.uppercased()
        if from == to {
            return Result(value: amount, rate: 1.0, rateAsOf: asOf)
        }
        guard let database = db.db else { return nil }
        let df = ISO8601DateFormatter()
        let dateStr = df.string(from: asOf)
        let sql = "SELECT rate_to_chf, rate_date FROM ExchangeRates WHERE currency_code = ? AND rate_date <= ? ORDER BY rate_date DESC LIMIT 1"

        func query(_ ccy: String) -> (Double, Date)? {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
            sqlite3_bind_text(stmt, 1, ccy, -1, nil)
            sqlite3_bind_text(stmt, 2, dateStr, -1, nil)
            guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
            let rate = sqlite3_column_double(stmt, 0)
            let date: Date
            if let cString = sqlite3_column_text(stmt, 1), let d = df.date(from: String(cString: cString)) {
                date = d
            } else {
                LoggingService.shared.log("Failed to parse rate_date for currency '\(ccy)', falling back to snapshot date.", type: .warning, logger: .database)
                date = asOf
            }
            return (rate, date)
        }

        if to == "CHF" {
            if from == "CHF" { return Result(value: amount, rate: 1.0, rateAsOf: asOf) }
            guard let info = query(from) else { return nil }
            return Result(value: amount * info.0, rate: info.0, rateAsOf: info.1)
        } else if from == "CHF" {
            guard let info = query(to) else { return nil }
            let rate = 1.0 / info.0
            return Result(value: amount * rate, rate: rate, rateAsOf: info.1)
        } else {
            guard let fromInfo = query(from), let toInfo = query(to) else { return nil }
            let rate = fromInfo.0 / toInfo.0
            let usedDate = max(fromInfo.1, toInfo.1)
            return Result(value: amount * rate, rate: rate, rateAsOf: usedDate)
        }
    }
}
