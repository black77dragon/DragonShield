import Foundation
import SQLite3

struct ValuationRow: Identifiable {
    let instrumentId: Int
    let instrumentName: String
    let researchTargetPct: Double
    let userTargetPct: Double
    let currentValueBase: Double?
    let actualPct: Double
    let notes: String?
    let status: String
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
        var included = 0
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
                var status = "OK"
                var valueBase: Double?
                if nativeValue == 0 {
                    status = "No position"
                    valueBase = 0
                } else {
                    let result = FXConversionService.convert(
                        amount: nativeValue,
                        from: currency,
                        to: dbManager.baseCurrency,
                        asOf: positionsAsOf ?? Date(),
                        db: dbManager
                    )
                    switch result {
                    case let .converted(v, _, date):
                        valueBase = v
                        included += 1
                        if date > (fxAsOf ?? .distantPast) { fxAsOf = date }
                        total += v
                    case .missing:
                        status = "FX missing — excluded"
                        excludedFx += 1
                        missing.insert(currency)
                    }
                }
                rows.append(ValuationRow(instrumentId: instrId, instrumentName: name, researchTargetPct: research, userTargetPct: user, currentValueBase: valueBase, actualPct: 0, notes: note, status: status))
            }
        }
        sqlite3_finalize(stmt)

        rows = rows.map { row in
            var pct: Double = 0
            if let v = row.currentValueBase, total > 0 && row.status == "OK" {
                pct = v / total * 100
            }
            return ValuationRow(instrumentId: row.instrumentId, instrumentName: row.instrumentName, researchTargetPct: row.researchTargetPct, userTargetPct: row.userTargetPct, currentValueBase: row.currentValueBase, actualPct: pct, notes: row.notes, status: row.status)
        }

        let duration = Int(Date().timeIntervalSince(start) * 1000)
        if let t = theme {
            let event: [String: Any] = [
                "themeId": t.id,
                "positions_asof": positionsAsOf.map { Self.dateFormatter.string(from: $0) } ?? NSNull(),
                "fx_asof": fxAsOf.map { Self.dateFormatter.string(from: $0) } ?? NSNull(),
                "rows_total": rows.count,
                "rows_included": included,
                "rows_fx_missing": excludedFx,
                "total_chf": total,
                "duration_ms": duration,
                "fx_source": "PositionsParity"
            ]
            do {
                let data = try JSONSerialization.data(withJSONObject: event)
                if let json = String(data: data, encoding: .utf8) {
                    LoggingService.shared.log(json, logger: .database)
                }
            } catch {
                LoggingService.shared.log("Failed to serialize valuation event to JSON: \(error.localizedDescription)", type: .error, logger: .database)
            }
        }

        return ValuationSnapshot(positionsAsOf: positionsAsOf, fxAsOf: fxAsOf, totalValueBase: total, rows: rows, excludedFxCount: excludedFx, missingCurrencies: Array(missing))
    }
}
