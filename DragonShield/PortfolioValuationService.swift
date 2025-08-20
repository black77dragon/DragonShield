import Foundation
import SQLite3

struct PortfolioAssetValuation {
    let instrumentId: Int
    let instrumentName: String
    let researchTargetPct: Double
    let userTargetPct: Double
    let currency: String
    let currentValue: Double
    let notes: String?
}

final class PortfolioValuationService {
    private let db: OpaquePointer?

    init(db: OpaquePointer?) {
        self.db = db
    }

    func fetchThemeValuations(themeId: Int, importSessionId: Int) -> [PortfolioAssetValuation] {
        var results: [PortfolioAssetValuation] = []
        let sql = """
        SELECT a.instrument_id,
               i.instrument_name,
               a.research_target_pct,
               a.user_target_pct,
               i.currency,
               COALESCE(SUM(pr.quantity * pr.current_price),0),
               a.notes
          FROM PortfolioThemeAsset a
          JOIN Instruments i ON a.instrument_id = i.instrument_id
          LEFT JOIN PositionReports pr ON pr.instrument_id = a.instrument_id AND pr.import_session_id = ?
         WHERE a.theme_id = ?
         GROUP BY a.instrument_id, i.instrument_name, a.research_target_pct, a.user_target_pct, i.currency, a.notes;
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(importSessionId))
            sqlite3_bind_int(stmt, 2, Int32(themeId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let instrumentId = Int(sqlite3_column_int(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 1))
                let research = sqlite3_column_double(stmt, 2)
                let user = sqlite3_column_double(stmt, 3)
                let currency = String(cString: sqlite3_column_text(stmt, 4))
                let value = sqlite3_column_double(stmt, 5)
                let notes: String?
                if sqlite3_column_type(stmt, 6) == SQLITE_NULL {
                    notes = nil
                } else {
                    notes = String(cString: sqlite3_column_text(stmt, 6))
                }
                results.append(PortfolioAssetValuation(
                    instrumentId: instrumentId,
                    instrumentName: name,
                    researchTargetPct: research,
                    userTargetPct: user,
                    currency: currency,
                    currentValue: value,
                    notes: notes
                ))
            }
        } else {
            LoggingService.shared.log("fetchThemeValuations prepare failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return results
    }
}

