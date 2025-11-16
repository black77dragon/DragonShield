#if os(iOS)
    import Foundation
    import SQLite3

    extension DatabaseManager {
        struct ThemeHoldingRow: Identifiable {
            let instrumentId: Int
            let instrumentName: String
            let instrumentCurrency: String
            let quantity: Double
            let setTargetChf: Double?
            let latestPrice: Double?
            let priceCurrency: String?
            let priceAsOf: String?
            let valueChf: Double?
            var id: Int { instrumentId }
        }

        /// Returns holdings for a theme: instrument, qty (sum of positions), latest price, value in CHF.
        /// Works even if PositionReports or PortfolioThemeAsset are missing (returns empty).
        func fetchThemeHoldings(themeId: Int) -> [ThemeHoldingRow] {
            guard let db = db else { return [] }
            // Check required tables
            let required = ["PortfolioThemeAsset", "Instruments"]
            for t in required {
                if !tableExistsIOS(t) { return [] }
            }
            let sql = """
                SELECT i.instrument_id,
                       i.instrument_name,
                       i.currency,
                       COALESCE(SUM(pr.quantity), 0) AS qty,
                       MAX(a.rwk_set_target_chf) AS target_chf
                  FROM PortfolioThemeAsset a
                  JOIN Instruments i ON a.instrument_id = i.instrument_id
                  LEFT JOIN PositionReports pr ON pr.instrument_id = a.instrument_id
                 WHERE a.theme_id = ?
                 GROUP BY i.instrument_id, i.instrument_name, i.currency
                 ORDER BY i.instrument_name COLLATE NOCASE
            """
            var stmt: OpaquePointer?
            var rows: [ThemeHoldingRow] = []
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int(stmt, 1, Int32(themeId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 1))
                let currency = String(cString: sqlite3_column_text(stmt, 2))
                let qty = sqlite3_column_double(stmt, 3)
                let targetChf: Double?
                if sqlite3_column_type(stmt, 4) == SQLITE_NULL {
                    targetChf = nil
                } else {
                    targetChf = sqlite3_column_double(stmt, 4)
                }
                var lp: Double? = nil
                var priceCur: String? = nil
                var asOf: String? = nil
                if let info = getLatestPrice(instrumentId: id) {
                    lp = info.price
                    priceCur = info.currency
                    asOf = info.asOf
                }
                var chf: Double? = nil
                if let p = lp {
                    let native = qty * p
                    let curr = (priceCur ?? currency).uppercased()
                    if curr == "CHF" { chf = native }
                    else if let r = latestRateToChf(currencyCode: curr)?.rate { chf = native * r }
                }
                rows.append(ThemeHoldingRow(instrumentId: id,
                                            instrumentName: name,
                                            instrumentCurrency: currency,
                                            quantity: qty,
                                            setTargetChf: targetChf,
                                            latestPrice: lp,
                                            priceCurrency: priceCur,
                                            priceAsOf: asOf,
                                            valueChf: chf))
            }
            return rows
        }
    }
#endif
