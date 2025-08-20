// DragonShield/PortfolioValuationService.swift
// MARK: - Version 1.0
// MARK: - History
// - 1.0: Fetch theme asset valuations with notes.

import Foundation
import SQLite3

/// Provides valuation data for portfolio themes.
final class PortfolioValuationService {
    private let db: OpaquePointer?

    /// Create a service using an existing SQLite connection.
    init(db: OpaquePointer?) {
        self.db = db
    }

    /// Represents valuation details for a theme asset.
    struct ThemeAssetValuation: Equatable {
        let instrumentId: Int
        let instrumentName: String
        let researchTargetPct: Double
        let userTargetPct: Double
        let currency: String
        let value: Double
        let notes: String?
    }

    /// Fetch valuations for all assets within a theme for a given import session.
    func fetchValuations(importSessionId: Int, themeId: Int) -> [ThemeAssetValuation] {
        guard let db = db else { return [] }
        let sql = """
        SELECT a.instrument_id, i.instrument_name, a.research_target_pct, a.user_target_pct, i.currency, COALESCE(SUM(pr.quantity * pr.current_price),0), a.notes
          FROM PortfolioThemeAsset a
          JOIN Instruments i ON a.instrument_id = i.instrument_id
          LEFT JOIN PositionReports pr ON pr.instrument_id = a.instrument_id AND pr.import_session_id = ?
         WHERE a.theme_id = ?
         GROUP BY a.instrument_id, i.instrument_name, a.research_target_pct, a.user_target_pct, i.currency, a.notes
        """
        var stmt: OpaquePointer?
        var results: [ThemeAssetValuation] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
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
                let valuation = ThemeAssetValuation(
                    instrumentId: instrId,
                    instrumentName: name,
                    researchTargetPct: research,
                    userTargetPct: user,
                    currency: currency,
                    value: value,
                    notes: notes
                )
                results.append(valuation)
            }
        } else {
            LoggingService.shared.log("Failed to prepare fetchValuations: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return results
    }
}

