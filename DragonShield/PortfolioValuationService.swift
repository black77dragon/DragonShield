import Foundation
import SQLite3

struct PortfolioAssetValuation: Identifiable {
    let instrumentId: Int
    let instrumentName: String
    let researchTargetPct: Double
    let userTargetPct: Double
    let currency: String
    let currentValue: Double
    let notes: String?

    var id: Int { instrumentId }
}

final class PortfolioValuationService {
    private let manager: DatabaseManager

    init(manager: DatabaseManager) {
        self.manager = manager
    }

    func fetchThemeAssetValuations(importSessionId: Int, themeId: Int) -> [PortfolioAssetValuation] {
        var results: [PortfolioAssetValuation] = []
        guard let db = manager.db else { return results }
        let sql = """
        SELECT a.instrument_id, i.instrument_name, a.research_target_pct, a.user_target_pct, i.currency, COALESCE(SUM(pr.quantity * pr.current_price),0), a.notes
          FROM PortfolioThemeAsset a
          JOIN Instruments i ON a.instrument_id = i.instrument_id
          LEFT JOIN PositionReports pr ON pr.instrument_id = a.instrument_id AND pr.import_session_id = ?
         WHERE a.theme_id = ?
         GROUP BY a.instrument_id, i.instrument_name, a.research_target_pct, a.user_target_pct, i.currency, a.notes
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            sqlite3_finalize(stmt)
            return results
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(importSessionId))
        sqlite3_bind_int(stmt, 2, Int32(themeId))
        while sqlite3_step(stmt) == SQLITE_ROW {
            let instrId = Int(sqlite3_column_int(stmt, 0))
            let name = String(cString: sqlite3_column_text(stmt, 1))
            let research = sqlite3_column_double(stmt, 2)
            let user = sqlite3_column_double(stmt, 3)
            let currency = String(cString: sqlite3_column_text(stmt, 4))
            let value = sqlite3_column_double(stmt, 5)
            let notes = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
            results.append(PortfolioAssetValuation(instrumentId: instrId, instrumentName: name, researchTargetPct: research, userTargetPct: user, currency: currency, currentValue: value, notes: notes))
        }
        return results
    }
}
