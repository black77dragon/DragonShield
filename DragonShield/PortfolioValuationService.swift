import Foundation
import SQLite3

struct PortfolioValuationRecord {
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

    init(database: OpaquePointer?) {
        self.db = database
    }

    func fetchValuations(importSessionId: Int, themeId: Int) -> [PortfolioValuationRecord] {
        var records: [PortfolioValuationRecord] = []
        let sql = """
        SELECT a.instrument_id, i.instrument_name, a.research_target_pct, a.user_target_pct, i.currency, COALESCE(SUM(pr.quantity * pr.current_price),0), a.notes
          FROM PortfolioThemeAsset a
          JOIN Instruments i ON a.instrument_id = i.instrument_id
          LEFT JOIN PositionReports pr ON pr.instrument_id = a.instrument_id AND pr.import_session_id = ?
         WHERE a.theme_id = ?
         GROUP BY a.instrument_id, i.instrument_name, a.research_target_pct, a.user_target_pct, i.currency, a.notes
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return records }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(importSessionId))
        sqlite3_bind_int(stmt, 2, Int32(themeId))
        while sqlite3_step(stmt) == SQLITE_ROW {
            let instrumentId = Int(sqlite3_column_int(stmt, 0))
            let instrumentName = String(cString: sqlite3_column_text(stmt, 1))
            let researchPct = sqlite3_column_double(stmt, 2)
            let userPct = sqlite3_column_double(stmt, 3)
            let currency = String(cString: sqlite3_column_text(stmt, 4))
            let currentValue = sqlite3_column_double(stmt, 5)
            let notes = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
            records.append(PortfolioValuationRecord(instrumentId: instrumentId,
                                                   instrumentName: instrumentName,
                                                   researchTargetPct: researchPct,
                                                   userTargetPct: userPct,
                                                   currency: currency,
                                                   currentValue: currentValue,
                                                   notes: notes))
        }
        return records
    }
}
