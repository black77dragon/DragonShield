import Foundation
import SQLite3

struct FXConversionService {
    struct Conversion {
        let value: Double
        let rate: Double
        let rateAsOf: Date
    }

    static func convert(amount: Double, from fromCcy: String, to toCcy: String, asOf: Date, db: OpaquePointer?) -> Conversion? {
        guard let db else { return nil }
        let df = ISO8601DateFormatter()
        let from = fromCcy.uppercased()
        let to = toCcy.uppercased()
        if from == to {
            return Conversion(value: amount, rate: 1.0, rateAsOf: asOf)
        }
        let sql = "SELECT rate_to_chf, rate_date FROM ExchangeRates WHERE currency_code = ? AND rate_date <= ? ORDER BY rate_date DESC LIMIT 1"
        func query(_ ccy: String) -> (Double, Date)? {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
            sqlite3_bind_text(stmt, 1, ccy, -1, nil)
            sqlite3_bind_text(stmt, 2, df.string(from: asOf), -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                let rate = sqlite3_column_double(stmt, 0)
                let date: Date
                if let cStr = sqlite3_column_text(stmt, 1), let d = df.date(from: String(cString: cStr)) {
                    date = d
                } else {
                    date = asOf
                }
                return (rate, date)
            }
            return nil
        }
        if to == "CHF", let fromInfo = query(from) {
            return Conversion(value: amount * fromInfo.0, rate: fromInfo.0, rateAsOf: fromInfo.1)
        }
        if from == "CHF", let toInfo = query(to) {
            let rate = 1.0 / toInfo.0
            return Conversion(value: amount * rate, rate: rate, rateAsOf: toInfo.1)
        }
        if let fromInfo = query(from), let toInfo = query(to) {
            let rate = fromInfo.0 / toInfo.0
            let value = amount * rate
            let usedDate = max(fromInfo.1, toInfo.1)
            return Conversion(value: value, rate: rate, rateAsOf: usedDate)
        }

        return nil
    }
}
