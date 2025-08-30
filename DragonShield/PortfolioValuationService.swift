import Foundation
import SQLite3

enum ValuationStatus: String {
    case ok = "OK"
    case noPosition = "No position"
    case fxMissing = "FX missing — excluded"
    case priceMissing = "Price missing — excluded"
}

struct ValuationRow: Identifiable {
    let instrumentId: Int
    let instrumentName: String
    let researchTargetPct: Double
    let userTargetPct: Double
    let currentValueBase: Double
    let actualPct: Double
    let deltaResearchPct: Double?
    let deltaUserPct: Double?
    let notes: String?
    let status: ValuationStatus
    var id: Int { instrumentId }
}

struct ValuationSnapshot {
    let positionsAsOf: Date?
    let fxAsOf: Date?
    let totalValueBase: Double
    let rows: [ValuationRow]
    let excludedFxCount: Int
    let missingCurrencies: [String]
    let excludedPriceCount: Int
}

final class PortfolioValuationService {
    private let dbManager: DatabaseManager
    private let fxService: FXConversionService
    private static let dateFormatter = ISO8601DateFormatter()

    init(dbManager: DatabaseManager, fxService: FXConversionService) {
        self.dbManager = dbManager
        self.fxService = fxService
    }

    func snapshot(themeId: Int) -> ValuationSnapshot {
        let start = Date()
        guard let db = dbManager.db else {
            return ValuationSnapshot(positionsAsOf: nil, fxAsOf: nil, totalValueBase: 0, rows: [], excludedFxCount: 0, missingCurrencies: [], excludedPriceCount: 0)
        }
        guard !dbManager.baseCurrency.isEmpty else {
            LoggingService.shared.log("Base currency not configured.", type: .error, logger: .database)
            return ValuationSnapshot(positionsAsOf: nil, fxAsOf: nil, totalValueBase: 0, rows: [], excludedFxCount: 0, missingCurrencies: [], excludedPriceCount: 0)
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
        var excludedPrice = 0
        var included = 0
        var missing: Set<String> = []

        let sql = """
        SELECT a.instrument_id,
               i.instrument_name,
               a.research_target_pct,
               a.user_target_pct,
               i.currency,
               COALESCE(SUM(pr.quantity),0) AS qty,
               ipl.price,
               a.notes
          FROM PortfolioThemeAsset a
          JOIN Instruments i ON a.instrument_id = i.instrument_id
          LEFT JOIN PositionReports pr ON pr.instrument_id = a.instrument_id
          LEFT JOIN InstrumentPriceLatest ipl ON ipl.instrument_id = a.instrument_id
         WHERE a.theme_id = ?
         GROUP BY a.instrument_id, i.instrument_name, a.research_target_pct, a.user_target_pct, i.currency, a.notes, ipl.price
        """
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(themeId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let instrId = Int(sqlite3_column_int(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 1))
                let research = sqlite3_column_double(stmt, 2)
                let user = sqlite3_column_double(stmt, 3)
                let currency = String(cString: sqlite3_column_text(stmt, 4))
                let qty = sqlite3_column_double(stmt, 5)
                let hasPrice = sqlite3_column_type(stmt, 6) != SQLITE_NULL
                let price = hasPrice ? sqlite3_column_double(stmt, 6) : 0
                let nativeValue = qty * price
                let note = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
                var status: ValuationStatus = .ok
                var valueBase: Double = 0
                if qty == 0 {
                    status = .noPosition
                } else if !hasPrice {
                    status = .priceMissing
                    excludedPrice += 1
                } else if let result = fxService.convertToChf(amount: nativeValue, currency: currency) {
                    valueBase = result.valueChf
                    included += 1
                    if result.rateDate > (fxAsOf ?? .distantPast) { fxAsOf = result.rateDate }
                } else {
                    status = .fxMissing
                    excludedFx += 1
                    missing.insert(currency)
                }
                rows.append(ValuationRow(instrumentId: instrId, instrumentName: name, researchTargetPct: research, userTargetPct: user, currentValueBase: valueBase, actualPct: 0, deltaResearchPct: nil, deltaUserPct: nil, notes: note, status: status))
                if status == .ok { total += valueBase }
            }
        }
        sqlite3_finalize(stmt)

        rows = rows.map { row in
            var pct: Double = 0
            if total > 0 && row.status == .ok {
                pct = row.currentValueBase / total * 100
            }
            let deltaResearch = row.status == .fxMissing ? nil : pct - row.researchTargetPct
            let deltaUser = row.status == .fxMissing ? nil : pct - row.userTargetPct
            return ValuationRow(instrumentId: row.instrumentId, instrumentName: row.instrumentName, researchTargetPct: row.researchTargetPct, userTargetPct: row.userTargetPct, currentValueBase: row.currentValueBase, actualPct: pct, deltaResearchPct: deltaResearch, deltaUserPct: deltaUser, notes: row.notes, status: row.status)
        }

        let duration = Int(Date().timeIntervalSince(start) * 1000)
        if let t = theme {
            let event: [String: Any] = [
                "themeId": t.id,
                "rowsTotal": rows.count,
                "rowsIncluded": included,
                "rowsFxMissing": excludedFx,
                "totalChf": total,
                "fxAsOf": fxAsOf.map { Self.dateFormatter.string(from: $0) } ?? NSNull(),
                "durationMs": duration,
                "fxPolicy": "latest/is_latest"
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

        return ValuationSnapshot(positionsAsOf: positionsAsOf, fxAsOf: fxAsOf, totalValueBase: total, rows: rows, excludedFxCount: excludedFx, missingCurrencies: Array(missing), excludedPriceCount: excludedPrice)
    }
}
