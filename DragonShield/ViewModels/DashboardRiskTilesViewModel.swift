import Foundation
import Combine

struct DashboardRiskInstrument: Identifiable {
    let id: Int
    let name: String
    let sri: Int
    let liquidityTier: Int
    let valueChf: Double
    let weight: Double
    let usedFallback: Bool
}

struct DashboardRiskBucket: Identifiable {
    let id: Int
    let label: String
    let count: Int
    let value: Double
    let share: Double
}

enum DashboardOverrideStatus: String, CaseIterable, Hashable {
    case active
    case expiringSoon
    case expired
}

struct DashboardOverrideSummary {
    let counts: [DashboardOverrideStatus: Int]
    let nextExpiry: Date?
}

struct DashboardRiskSnapshot {
    let baseCurrency: String
    let totalValue: Double
    let riskScore: Double?
    let category: PortfolioRiskCategory?
    let weightedSRI: Double
    let weightedLiquidityPremium: Double
    let highRiskShare: Double
    let illiquidShare: Double
    let priceAsOf: Date?
    let sriBuckets: [DashboardRiskBucket]
    let liquidityBuckets: [DashboardRiskBucket]
    let instrumentsBySRI: [Int: [DashboardRiskInstrument]]
    let instrumentsByLiquidity: [Int: [DashboardRiskInstrument]]
    let overrides: [DatabaseManager.RiskOverrideRow]
    let overrideSummary: DashboardOverrideSummary
    let missingPriceCount: Int
    let missingFxCount: Int
    let fallbackCount: Int

    static let empty = DashboardRiskSnapshot(
        baseCurrency: "CHF",
        totalValue: 0,
        riskScore: nil,
        category: nil,
        weightedSRI: 0,
        weightedLiquidityPremium: 0,
        highRiskShare: 0,
        illiquidShare: 0,
        priceAsOf: nil,
        sriBuckets: [],
        liquidityBuckets: [],
        instrumentsBySRI: [:],
        instrumentsByLiquidity: [:],
        overrides: [],
        overrideSummary: DashboardOverrideSummary(counts: [:], nextExpiry: nil),
        missingPriceCount: 0,
        missingFxCount: 0,
        fallbackCount: 0
    )
}

final class DashboardRiskTilesViewModel: ObservableObject {
    @Published var snapshot: DashboardRiskSnapshot = .empty
    @Published var loading: Bool = false

    func load(using dbManager: DatabaseManager) {
        loading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.computeSnapshot(dbManager: dbManager)
            DispatchQueue.main.async {
                self.snapshot = result
                self.loading = false
            }
        }
    }

    // MARK: - Computation

    private struct InstrumentRisk {
        let sri: Int
        let liquidityTier: Int
        let usedFallback: Bool
    }

    private func computeSnapshot(dbManager: DatabaseManager) -> DashboardRiskSnapshot {
        let fxService = FXConversionService(dbManager: dbManager)
        let positions = dbManager.fetchPositionReports()
        let overrides = dbManager.listRiskOverrides()
        var riskCache: [Int: InstrumentRisk] = [:]
        var instruments: [DashboardRiskInstrument] = []
        var missingPrice = 0
        var missingFx = 0
        var fallbackCount = 0
        var mostRecentPriceDate: Date?

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoShort = ISO8601DateFormatter()
        isoShort.formatOptions = [.withInternetDateTime]

        for position in positions {
            guard let instrumentId = position.instrumentId else { continue }
            guard let latestPrice = dbManager.getLatestPrice(instrumentId: instrumentId) else {
                missingPrice += 1
                continue
            }
            let nativeValue = position.quantity * latestPrice.price
            guard nativeValue != 0 else { continue }
            guard let converted = fxService.convertToChf(amount: nativeValue, currency: latestPrice.currency) else {
                missingFx += 1
                continue
            }

            let risk: InstrumentRisk
            if let cached = riskCache[instrumentId] {
                risk = cached
            } else {
                let resolved = resolveRisk(for: instrumentId, dbManager: dbManager)
                riskCache[instrumentId] = resolved
                if resolved.usedFallback { fallbackCount += 1 }
                risk = resolved
            }

            let instrument = DashboardRiskInstrument(
                id: instrumentId,
                name: position.instrumentName,
                sri: risk.sri,
                liquidityTier: risk.liquidityTier,
                valueChf: converted.valueChf,
                weight: 0, // filled later
                usedFallback: risk.usedFallback
            )
            instruments.append(instrument)

            if let parsed = iso.date(from: latestPrice.asOf) ?? isoShort.date(from: latestPrice.asOf) {
                if let current = mostRecentPriceDate {
                    if parsed > current { mostRecentPriceDate = parsed }
                } else {
                    mostRecentPriceDate = parsed
                }
            }
        }

        let totalValue = instruments.reduce(0) { $0 + $1.valueChf }
        guard totalValue > 0 else {
            let emptyOverrides = summarizeOverrides(overrides: overrides)
            return DashboardRiskSnapshot(
                baseCurrency: dbManager.preferences.baseCurrency,
                totalValue: 0,
                riskScore: nil,
                category: nil,
                weightedSRI: 0,
                weightedLiquidityPremium: 0,
                highRiskShare: 0,
                illiquidShare: 0,
                priceAsOf: mostRecentPriceDate,
                sriBuckets: [],
                liquidityBuckets: [],
                instrumentsBySRI: [:],
                instrumentsByLiquidity: [:],
                overrides: overrides,
                overrideSummary: emptyOverrides,
                missingPriceCount: missingPrice,
                missingFxCount: missingFx,
                fallbackCount: fallbackCount
            )
        }

        let weightedInstruments = instruments.map { item -> DashboardRiskInstrument in
            let weight = item.valueChf / totalValue
            return DashboardRiskInstrument(
                id: item.id,
                name: item.name,
                sri: item.sri,
                liquidityTier: item.liquidityTier,
                valueChf: item.valueChf,
                weight: weight,
                usedFallback: item.usedFallback
            )
        }

        var sriGroups: [Int: (count: Int, value: Double)] = [:]
        var liquidityGroups: [Int: (count: Int, value: Double)] = [:]
        var sriInstruments: [Int: [DashboardRiskInstrument]] = [:]
        var liquidityInstruments: [Int: [DashboardRiskInstrument]] = [:]
        var weightedSRI = 0.0
        var weightedLiquidityPremium = 0.0
        var highRiskValue = 0.0
        var illiquidValue = 0.0

        for item in weightedInstruments {
            weightedSRI += item.weight * Double(item.sri)
            weightedLiquidityPremium += item.weight * liquidityPenalty(for: item.liquidityTier)

            if item.sri >= 6 { highRiskValue += item.valueChf }
            if item.liquidityTier >= 1 { illiquidValue += item.valueChf }

            sriGroups[item.sri, default: (0, 0)].count += 1
            sriGroups[item.sri, default: (0, 0)].value += item.valueChf
            liquidityGroups[item.liquidityTier, default: (0, 0)].count += 1
            liquidityGroups[item.liquidityTier, default: (0, 0)].value += item.valueChf

            sriInstruments[item.sri, default: []].append(item)
            liquidityInstruments[item.liquidityTier, default: []].append(item)
        }

        let sriBuckets = (1 ... 7).map { bucket -> DashboardRiskBucket in
            let entry = sriGroups[bucket] ?? (0, 0)
            let share = entry.value / totalValue
            return DashboardRiskBucket(id: bucket, label: "SRI \(bucket)", count: entry.count, value: entry.value, share: share)
        }

        let liquidityLabels: [Int: String] = [0: "Liquid", 1: "Restricted", 2: "Illiquid"]
        let liquidityBuckets = [0, 1, 2].map { tier -> DashboardRiskBucket in
            let entry = liquidityGroups[tier] ?? (0, 0)
            let share = entry.value / totalValue
            let label = liquidityLabels[tier] ?? "Tier \(tier)"
            return DashboardRiskBucket(id: tier, label: label, count: entry.count, value: entry.value, share: share)
        }

        let riskScore = clampScore(weightedSRI + weightedLiquidityPremium)
        let overrideSummary = summarizeOverrides(overrides: overrides)

        let sortedSriInstruments = sriInstruments.mapValues { list in
            list.sorted { $0.valueChf > $1.valueChf }
        }
        let sortedLiqInstruments = liquidityInstruments.mapValues { list in
            list.sorted { $0.valueChf > $1.valueChf }
        }

        return DashboardRiskSnapshot(
            baseCurrency: dbManager.preferences.baseCurrency,
            totalValue: totalValue,
            riskScore: riskScore,
            category: category(for: riskScore),
            weightedSRI: weightedSRI,
            weightedLiquidityPremium: weightedLiquidityPremium,
            highRiskShare: highRiskValue / totalValue,
            illiquidShare: illiquidValue / totalValue,
            priceAsOf: mostRecentPriceDate,
            sriBuckets: sriBuckets,
            liquidityBuckets: liquidityBuckets,
            instrumentsBySRI: sortedSriInstruments,
            instrumentsByLiquidity: sortedLiqInstruments,
            overrides: overrides,
            overrideSummary: overrideSummary,
            missingPriceCount: missingPrice,
            missingFxCount: missingFx,
            fallbackCount: fallbackCount
        )
    }

    private func resolveRisk(for instrumentId: Int, dbManager: DatabaseManager) -> InstrumentRisk {
        if let profile = dbManager.fetchRiskProfile(instrumentId: instrumentId) {
            return InstrumentRisk(
                sri: dbManager.coerceSRI(profile.effectiveSRI),
                liquidityTier: dbManager.coerceLiquidityTier(profile.effectiveLiquidityTier),
                usedFallback: false
            )
        }
        if let details = dbManager.fetchInstrumentDetails(id: instrumentId) {
            let defaults = dbManager.riskDefaults(for: details.subClassId)
            return InstrumentRisk(
                sri: dbManager.coerceSRI(defaults.sri),
                liquidityTier: dbManager.coerceLiquidityTier(defaults.liquidityTier),
                usedFallback: true
            )
        }
        let sri = dbManager.riskConfigInt(key: "risk_default_sri", fallback: 5, min: 1, max: 7)
        let liq = dbManager.riskConfigInt(key: "risk_default_liquidity_tier", fallback: 1, min: 0, max: 2)
        return InstrumentRisk(sri: sri, liquidityTier: liq, usedFallback: true)
    }

    private func liquidityPenalty(for tier: Int) -> Double {
        switch tier {
        case 0: return 0.0 // Liquid
        case 1: return 0.5 // Restricted
        default: return 1.0 // Illiquid
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

    private func summarizeOverrides(overrides: [DatabaseManager.RiskOverrideRow]) -> DashboardOverrideSummary {
        var counts: [DashboardOverrideStatus: Int] = [:]
        var earliestExpiry: Date?
        for row in overrides {
            let status = overrideStatus(for: row)
            counts[status, default: 0] += 1
            if let expires = row.overrideExpiresAt {
                if let current = earliestExpiry {
                    if expires < current { earliestExpiry = expires }
                } else {
                    earliestExpiry = expires
                }
            }
        }
        return DashboardOverrideSummary(counts: counts, nextExpiry: earliestExpiry)
    }

    private func overrideStatus(for row: DatabaseManager.RiskOverrideRow) -> DashboardOverrideStatus {
        guard let expires = row.overrideExpiresAt else { return .active }
        if expires < Date() { return .expired }
        if let soon = Calendar.current.date(byAdding: .day, value: 30, to: Date()), expires < soon {
            return .expiringSoon
        }
        return .active
    }
}
