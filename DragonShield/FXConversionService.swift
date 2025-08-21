import Foundation
import SQLite3

enum FXConversionResult {
    case converted(value: Double, rate: Double, rateAsOf: Date)
    case missing
}

struct FXConversionService {
    private static let dateFormatter = ISO8601DateFormatter()

    static func convert(amount: Double, from fromCcy: String, to toCcy: String, asOf: Date, db: DatabaseManager) -> FXConversionResult {
        guard let sqlite = db.db else { return .missing }
        let from = fromCcy.uppercased()
        let to = toCcy.uppercased()
        if from == to {
            return .converted(value: amount, rate: 1.0, rateAsOf: asOf)
        }
        let dateStr = dateFormatter.string(from: asOf)
        let sql = "SELECT rate_to_chf, rate_date FROM ExchangeRates WHERE currency_code = ? AND rate_date <= ? ORDER BY rate_date DESC LIMIT 1"
        func query(_ currency: String) -> (Double, Date)? {
            if currency == "CHF" { return (1.0, asOf) }
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            if sqlite3_prepare_v2(sqlite, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, currency, -1, nil)
                sqlite3_bind_text(stmt, 2, dateStr, -1, nil)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    let rate = sqlite3_column_double(stmt, 0)
                    let date: Date
                    if let cString = sqlite3_column_text(stmt, 1), let d = dateFormatter.date(from: String(cString: cString)) {
                        date = d
                    } else {
                        LoggingService.shared.log("Failed to parse rate_date for currency '\(currency)', falling back to position date.", type: .warning, logger: .database)
                        date = asOf
                    }
                    return (rate, date)
                }
            }
            return nil
        }

        if to == "CHF" {
            guard let info = query(from) else { return .missing }
            return .converted(value: amount * info.0, rate: info.0, rateAsOf: info.1)
        } else if from == "CHF" {
            guard let info = query(to) else { return .missing }
            let rate = 1.0 / info.0
            return .converted(value: amount * rate, rate: rate, rateAsOf: info.1)
        } else {
            guard let fromInfo = query(from), let toInfo = query(to) else { return .missing }
            let rate = fromInfo.0 / toInfo.0
            let usedDate = max(fromInfo.1, toInfo.1)
            return .converted(value: amount * rate, rate: rate, rateAsOf: usedDate)
        }
    }
}
