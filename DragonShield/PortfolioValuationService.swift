import Foundation
import SQLite3

struct ValuationRow: Identifiable {
    let instrumentId: Int
    let instrumentName: String
    let researchTargetPct: Double
    let userTargetPct: Double
    let currentValueBase: Double
    let actualPct: Double
    let notes: String?
    let flag: String?
    var id: Int { instrumentId }
}

struct ValuationSnapshot {
    let positionsAsOf: Date?
    let fxAsOf: Date?
    let totalValueBase: Double
    let rows: [ValuationRow]
    let excludedFxCount: Int
    let missingCurrencies: [String]
}

final class PortfolioValuationService {
    private let dbManager: DatabaseManager
    private static let dateFormatter = ISO8601DateFormatter()

    init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
    }

    func snapshot(themeId: Int) -> ValuationSnapshot {
        let start = Date()
        guard let db = dbManager.db else {
            return ValuationSnapshot(positionsAsOf: nil, fxAsOf: nil, totalValueBase: 0, rows: [], excludedFxCount: 0, missingCurrencies: [])
        }
        guard !dbManager.baseCurrency.isEmpty else {
            LoggingService.shared.log("Base currency not configured.", type: .error, logger: .database)
            return ValuationSnapshot(positionsAsOf: nil, fxAsOf: nil, totalValueBase: 0, rows: [], excludedFxCount: 0, missingCurrencies: [])
        }

        let theme = dbManager.getPortfolioTheme(id: themeId)

        var positionsAsOf: Date?
        var stmt: OpaquePointer?
        let asOfSql = "SELECT MAX(report_date) FROM PositionReports"
        if sqlite3_prepare_v2(db, asOfSql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let cString = sqlite3_column_text(stmt, 0) {
                    positionsAsOf = Self.dateFormatter.date(from: String(cString: cString))
                }
            }
        }
        sqlite3_finalize(stmt)

        var rows: [ValuationRow] = []
        var total: Double = 0
        var fxAsOf: Date? = nil
        var excludedFx = 0
        var missing: Set<String> = []

        let sql = """
        SELECT a.instrument_id, i.instrument_name, a.research_target_pct, a.user_target_pct, i.currency, COALESCE(SUM(pr.quantity * pr.current_price),0), a.notes
          FROM PortfolioThemeAsset a
          JOIN Instruments i ON a.instrument_id = i.instrument_id
          LEFT JOIN PositionReports pr ON pr.instrument_id = a.instrument_id
         WHERE a.theme_id = ?
         GROUP BY a.instrument_id, i.instrument_name, a.research_target_pct, a.user_target_pct, i.currency, a.notes
        """
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(themeId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let instrId = Int(sqlite3_column_int(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 1))
                let research = sqlite3_column_double(stmt, 2)
                let user = sqlite3_column_double(stmt, 3)
                let currency = String(cString: sqlite3_column_text(stmt, 4))
                let nativeValue = sqlite3_column_double(stmt, 5)
                let note = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
                var flag: String? = nil
                var valueBase: Double = 0
                if nativeValue == 0 {
                    flag = "No position"
                } else if currency == dbManager.baseCurrency {
                    valueBase = nativeValue
                } else if let rate = fetchRate(for: currency, asOf: positionsAsOf, fxAsOf: &fxAsOf) {
                    valueBase = nativeValue * rate
                } else {
                    flag = "FX missing — excluded"
                    excludedFx += 1
                    missing.insert(currency)
                }
                rows.append(ValuationRow(instrumentId: instrId, instrumentName: name, researchTargetPct: research, userTargetPct: user, currentValueBase: valueBase, actualPct: 0, notes: note, flag: flag))
                if flag == nil { total += valueBase }
            }
        }
        sqlite3_finalize(stmt)

        var valuedCount = 0
        rows = rows.map { row in
            var pct: Double = 0
            if total > 0 && row.flag == nil {
                pct = row.currentValueBase / total * 100
                valuedCount += 1
            }
            return ValuationRow(instrumentId: row.instrumentId, instrumentName: row.instrumentName, researchTargetPct: row.researchTargetPct, userTargetPct: row.userTargetPct, currentValueBase: row.currentValueBase, actualPct: pct, notes: row.notes, flag: row.flag)
        }

        let duration = Int(Date().timeIntervalSince(start) * 1000)
        if let t = theme {
            let posStr = positionsAsOf.map { Self.dateFormatter.string(from: $0) } ?? ""
            let fxStr = fxAsOf.map { Self.dateFormatter.string(from: $0) } ?? ""
            LoggingService.shared.log("valuation themeId=\(t.id) themeCode=\(t.code) positions_asof=\(posStr) fx_asof=\(fxStr) instrumentsN=\(rows.count) valuedN=\(valuedCount) excludedFxN=\(excludedFx) totalBase=\(String(format: "%.2f", total)) duration_ms=\(duration)", logger: .database)
        }

        return ValuationSnapshot(positionsAsOf: positionsAsOf, fxAsOf: fxAsOf, totalValueBase: total, rows: rows, excludedFxCount: excludedFx, missingCurrencies: Array(missing))
    }

    private func fetchRate(for currency: String, asOf: Date?, fxAsOf: inout Date?) -> Double? {
        guard let db = dbManager.db else { return nil }
        let dateStr = asOf.map { Self.dateFormatter.string(from: $0) } ?? Self.dateFormatter.string(from: Date())
        let sql = "SELECT rate_to_chf, rate_date FROM ExchangeRates WHERE currency_code = ? AND rate_date <= ? ORDER BY rate_date DESC LIMIT 1"
        var stmt: OpaquePointer?
        var result: Double?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, currency, -1, nil)
            sqlite3_bind_text(stmt, 2, dateStr, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                result = sqlite3_column_double(stmt, 0)
                if let cString = sqlite3_column_text(stmt, 1) {
                    let date = Self.dateFormatter.date(from: String(cString: cString))
                    if let d = date {
                        if let existing = fxAsOf {
                            if d > existing { fxAsOf = d }
                        } else {
                            fxAsOf = d
                        }
                    }
                }
            }
        }
        sqlite3_finalize(stmt)
        return result
    }
}

