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
    let setTargetChf: Double?
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

    /// Sums only holdings that are included (user target > 0) and valued successfully.
    var includedTotalValueBase: Double {
        rows.reduce(0) { acc, row in
            guard row.status == .ok, row.userTargetPct > 0 else { return acc }
            return acc + row.currentValueBase
        }
    }
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
               a.rwk_set_target_chf,
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
                let setTargetValue = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 4)
                let currency = String(cString: sqlite3_column_text(stmt, 5))
                let qty = sqlite3_column_double(stmt, 6)
                let hasPrice = sqlite3_column_type(stmt, 7) != SQLITE_NULL
                let price = hasPrice ? sqlite3_column_double(stmt, 7) : 0
                let nativeValue = qty * price
                let note = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
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
                rows.append(ValuationRow(instrumentId: instrId, instrumentName: name, researchTargetPct: research, userTargetPct: user, setTargetChf: setTargetValue, currentValueBase: valueBase, actualPct: 0, deltaResearchPct: nil, deltaUserPct: nil, notes: note, status: status))
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
            return ValuationRow(instrumentId: row.instrumentId, instrumentName: row.instrumentName, researchTargetPct: row.researchTargetPct, userTargetPct: row.userTargetPct, setTargetChf: row.setTargetChf, currentValueBase: row.currentValueBase, actualPct: pct, deltaResearchPct: deltaResearch, deltaUserPct: deltaUser, notes: row.notes, status: row.status)
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
                "fxPolicy": "latest/is_latest",
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

// MARK: - Portfolio Risk Scoring (DS-032)

struct PortfolioRiskBucket: Identifiable {
    let bucket: Int
    let valueBase: Double
    let weight: Double
    let count: Int
    var id: Int { bucket }
}

struct PortfolioRiskInstrumentContribution: Identifiable {
    let id: Int
    let instrumentName: String
    let sri: Int
    let liquidityTier: Int
    let valueBase: Double
    let weight: Double
    let blendedScore: Double
    let usedFallback: Bool
    let manualOverride: Bool
    let overrideExpiresAt: Date?
    let valuationStatus: ValuationStatus
    let mappingVersion: String?
    let calcMethod: String?
}

enum PortfolioRiskCategory: String {
    case low = "Low"
    case moderate = "Moderate"
    case elevated = "Elevated"
    case high = "High"
}

struct PortfolioRiskSnapshot {
    let themeId: Int
    let positionsAsOf: Date?
    let fxAsOf: Date?
    let baseCurrency: String
    let totalValueBase: Double
    let weightedSRI: Double
    let weightedLiquidityPremium: Double
    let portfolioScore: Double
    let category: PortfolioRiskCategory
    let sriBuckets: [PortfolioRiskBucket]
    let liquidityBuckets: [PortfolioRiskBucket]
    let instruments: [PortfolioRiskInstrumentContribution]
    let excludedFxCount: Int
    let excludedPriceCount: Int
    let missingRiskCount: Int
    let overrideSummary: PortfolioRiskOverrideSummary
    let highRiskShare: Double
    let illiquidShare: Double
}

struct PortfolioRiskOverrideSummary {
    var active: Int
    var expiringSoon: Int
    var expired: Int
    var total: Int { active + expiringSoon + expired }
}

/// Scores portfolio risk by value-weighting instrument SRI and a liquidity premium.
/// Implements DS-032 methodology: blended score = weighted SRI + weighted liquidity premium, clamped to 1...7.
final class PortfolioRiskScoringService {
    private let dbManager: DatabaseManager
    private let fxService: FXConversionService
    private let valuationService: PortfolioValuationService

    init(dbManager: DatabaseManager, fxService: FXConversionService) {
        self.dbManager = dbManager
        self.fxService = fxService
        self.valuationService = PortfolioValuationService(dbManager: dbManager, fxService: fxService)
    }

    func score(themeId: Int, valuation: ValuationSnapshot? = nil) -> PortfolioRiskSnapshot {
        let valuation = valuation ?? valuationService.snapshot(themeId: themeId)
        let total = valuation.totalValueBase
        var sriTotals: [Int: Double] = [:]
        var liquidityTotals: [Int: Double] = [:]
        var sriCounts: [Int: Int] = [:]
        var liquidityCounts: [Int: Int] = [:]
        var weightedSRI = 0.0
        var weightedLiquidityPremium = 0.0
        var missingRisk = 0
        var instrumentRows: [PortfolioRiskInstrumentContribution] = []
        var overrideSummary = PortfolioRiskOverrideSummary(active: 0, expiringSoon: 0, expired: 0)

        guard total > 0 else {
            return PortfolioRiskSnapshot(
                themeId: themeId,
                positionsAsOf: valuation.positionsAsOf,
                fxAsOf: valuation.fxAsOf,
                baseCurrency: dbManager.baseCurrency,
                totalValueBase: 0,
                weightedSRI: 0,
                weightedLiquidityPremium: 0,
                portfolioScore: 0,
                category: .low,
                sriBuckets: [],
                liquidityBuckets: [],
                instruments: [],
                excludedFxCount: valuation.excludedFxCount,
                excludedPriceCount: valuation.excludedPriceCount,
                missingRiskCount: 0,
                overrideSummary: overrideSummary,
                highRiskShare: 0,
                illiquidShare: 0
            )
        }

        for row in valuation.rows {
            let risk = resolveRisk(instrumentId: row.instrumentId)
            if risk.usedFallback { missingRisk += 1 }

            let included = row.status == .ok && row.currentValueBase > 0
            let weight = included ? row.currentValueBase / total : 0
            if included {
                weightedSRI += weight * Double(risk.sri)
                weightedLiquidityPremium += weight * risk.liquidityPenalty

                sriTotals[risk.sri, default: 0] += row.currentValueBase
                liquidityTotals[risk.liquidityTier, default: 0] += row.currentValueBase
                sriCounts[risk.sri, default: 0] += 1
                liquidityCounts[risk.liquidityTier, default: 0] += 1
            }

            if risk.manualOverride {
                switch overrideStatus(for: risk.overrideExpiresAt) {
                case .active: overrideSummary.active += 1
                case .expiringSoon: overrideSummary.expiringSoon += 1
                case .expired: overrideSummary.expired += 1
                }
            }

            let blended = min(7.0, Double(risk.sri) + risk.liquidityPenalty)
            instrumentRows.append(
                PortfolioRiskInstrumentContribution(
                    id: row.instrumentId,
                    instrumentName: row.instrumentName,
                    sri: risk.sri,
                    liquidityTier: risk.liquidityTier,
                    valueBase: row.currentValueBase,
                    weight: weight,
                    blendedScore: blended,
                    usedFallback: risk.usedFallback,
                    manualOverride: risk.manualOverride,
                    overrideExpiresAt: risk.overrideExpiresAt,
                    valuationStatus: row.status,
                    mappingVersion: risk.mappingVersion,
                    calcMethod: risk.calcMethod
                )
            )
        }

        let bucketsSRI = sriTotals.map { key, value in
            PortfolioRiskBucket(bucket: key, valueBase: value, weight: value / total, count: sriCounts[key, default: 0])
        }.sorted { $0.bucket < $1.bucket }

        let bucketsLiquidity = liquidityTotals.map { key, value in
            PortfolioRiskBucket(bucket: key, valueBase: value, weight: value / total, count: liquidityCounts[key, default: 0])
        }.sorted { $0.bucket < $1.bucket }

        let blendedScore = clampScore(weightedSRI + weightedLiquidityPremium)
        let highRiskShare = instrumentRows.filter { $0.weight > 0 && $0.sri >= 6 }.reduce(0.0) { $0 + $1.weight }
        let illiquidShare = instrumentRows.filter { $0.weight > 0 && $0.liquidityTier >= 2 }.reduce(0.0) { $0 + $1.weight }

        return PortfolioRiskSnapshot(
            themeId: themeId,
            positionsAsOf: valuation.positionsAsOf,
            fxAsOf: valuation.fxAsOf,
            baseCurrency: dbManager.baseCurrency,
            totalValueBase: total,
            weightedSRI: weightedSRI,
            weightedLiquidityPremium: weightedLiquidityPremium,
            portfolioScore: blendedScore,
            category: category(for: blendedScore),
            sriBuckets: bucketsSRI,
            liquidityBuckets: bucketsLiquidity,
            instruments: instrumentRows.sorted { $0.weight > $1.weight },
            excludedFxCount: valuation.excludedFxCount,
            excludedPriceCount: valuation.excludedPriceCount,
            missingRiskCount: missingRisk,
            overrideSummary: overrideSummary,
            highRiskShare: highRiskShare,
            illiquidShare: illiquidShare
        )
    }

    private struct InstrumentRiskInputs {
        let sri: Int
        let liquidityTier: Int
        let liquidityPenalty: Double
        let usedFallback: Bool
        let manualOverride: Bool
        let overrideExpiresAt: Date?
        let mappingVersion: String?
        let calcMethod: String?
    }

    private func resolveRisk(instrumentId: Int) -> InstrumentRiskInputs {
        if let profile = dbManager.fetchRiskProfile(instrumentId: instrumentId) {
            let sri = dbManager.coerceSRI(profile.effectiveSRI)
            let tier = dbManager.coerceLiquidityTier(profile.effectiveLiquidityTier)
            return InstrumentRiskInputs(
                sri: sri,
                liquidityTier: tier,
                liquidityPenalty: liquidityPenalty(for: tier),
                usedFallback: false,
                manualOverride: profile.manualOverride,
                overrideExpiresAt: profile.overrideExpiresAt,
                mappingVersion: profile.mappingVersion,
                calcMethod: profile.calcMethod
            )
        }

        guard let details = dbManager.fetchInstrumentDetails(id: instrumentId) else {
            // Fallback to conservative defaults when the instrument cannot be resolved.
            return InstrumentRiskInputs(
                sri: 5,
                liquidityTier: 1,
                liquidityPenalty: liquidityPenalty(for: 1),
                usedFallback: true,
                manualOverride: false,
                overrideExpiresAt: nil,
                mappingVersion: nil,
                calcMethod: nil
            )
        }

        let defaults = dbManager.riskDefaults(for: details.subClassId)
        let tier = dbManager.coerceLiquidityTier(defaults.liquidityTier)
        return InstrumentRiskInputs(
            sri: dbManager.coerceSRI(defaults.sri),
            liquidityTier: tier,
            liquidityPenalty: liquidityPenalty(for: tier),
            usedFallback: true,
            manualOverride: false,
            overrideExpiresAt: nil,
            mappingVersion: defaults.mappingVersion,
            calcMethod: defaults.calcMethod
        )
    }

    private func liquidityPenalty(for tier: Int) -> Double {
        switch tier {
        case 0: return 0.0 // Liquid
        case 1: return 0.5 // Restricted
        default: return 1.0 // Illiquid or unknown
        }
    }

    private func clampScore(_ score: Double) -> Double {
        max(1.0, min(7.0, score))
    }

    private func category(for score: Double) -> PortfolioRiskCategory {
        if score <= 2.5 { return .low }
        if score <= 4.0 { return .moderate }
        if score <= 5.5 { return .elevated }
        return .high
    }

    private enum OverrideStatus {
        case active
        case expiringSoon
        case expired
    }

    private func overrideStatus(for expiresAt: Date?) -> OverrideStatus {
        guard let expires = expiresAt else { return .active }
        if expires < Date() { return .expired }
        if let soon = Calendar.current.date(byAdding: .day, value: 30, to: Date()), expires < soon {
            return .expiringSoon
        }
        return .active
    }
}
