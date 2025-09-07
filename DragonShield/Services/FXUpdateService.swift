import Foundation

struct FXUpdateSummary {
    let updatedCurrencies: [String]
    let asOf: Date
    let provider: String
    let insertedCount: Int
}

/// Orchestrates fetching latest FX and persisting to ExchangeRates.
final class FXUpdateService {
    private let db: DatabaseManager
    private let provider: FXRateProvider

    init(dbManager: DatabaseManager, provider: FXRateProvider = ExchangerateHostProvider()) {
        self.db = dbManager
        self.provider = provider
    }

    /// Returns the list of currency codes to update: active + API supported, excluding base.
    private func targetCurrencies(base: String) -> [String] {
        let all = db.fetchCurrencies() // includes isActive and apiSupported
        return all.filter { $0.isActive && $0.apiSupported && $0.code.uppercased() != base.uppercased() }
            .map { $0.code.uppercased() }
            .sorted()
    }

    /// Returns true if any target currency has no latest rate or is older than the threshold.
    func isStale(thresholdHours: Int = 24, base: String) -> Bool {
        let now = Date()
        let targets = targetCurrencies(base: base)
        for code in targets {
            if let r = db.fetchLatestExchangeRate(currencyCode: code) {
                let age = now.timeIntervalSince(r.rateDate) / 3600.0
                if age > Double(thresholdHours) { return true }
            } else {
                return true
            }
        }
        return targets.isEmpty ? false : false
    }

    /// Fetch and persist latest rates for all target currencies. Returns summary.
    @discardableResult
    func updateLatestForAll(base: String) async -> FXUpdateSummary? {
        let baseUpper = base.uppercased()
        let start = DispatchTime.now()
        let targets = targetCurrencies(base: baseUpper)
        guard !targets.isEmpty else { return nil }

        do {
            let response = try await provider.fetchLatest(base: baseUpper, symbols: targets)
            var inserted = 0
            var updated: [String] = []
            for code in targets {
                if let rate = response.rates[code] {
                    // response rate is CHF->code when base is CHF; we need code->CHF (rate_to_chf)
                    let toCHF: Double
                    if response.base.uppercased() == baseUpper {
                        toCHF = rate > 0 ? (1.0 / rate) : 0.0
                    } else {
                        // Fallback: if base isn't CHF, try derive via CHF rate if present
                        if let chfRate = response.rates["CHF"], chfRate > 0 { // base->CHF
                            // We have base->CHF and base->code; code->CHF = (base->CHF) / (base->code)
                            toCHF = chfRate / rate
                        } else {
                            // As a last resort, use raw
                            toCHF = rate
                        }
                    }
                    if toCHF > 0, db.insertExchangeRate(currencyCode: code, rateDate: response.asOf, rateToChf: toCHF, rateSource: "api", apiProvider: provider.code, isLatest: true) {
                        inserted += 1
                        updated.append(code)
                    }
                }
            }
            let end = DispatchTime.now()
            let ms = Int(Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000.0)
            _ = db.recordFxRateUpdate(updateDate: response.asOf, apiProvider: provider.code, currenciesUpdated: updated, status: "SUCCESS", errorMessage: nil, ratesCount: inserted, executionTimeMs: ms)
            return FXUpdateSummary(updatedCurrencies: updated, asOf: response.asOf, provider: provider.code, insertedCount: inserted)
        } catch {
            let end = DispatchTime.now()
            let ms = Int(Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000.0)
            _ = db.recordFxRateUpdate(updateDate: Date(), apiProvider: provider.code, currenciesUpdated: [], status: "FAILED", errorMessage: String(describing: error), ratesCount: 0, executionTimeMs: ms)
            return nil
        }
    }

    /// Auto-update on launch if the set is stale beyond threshold.
    func autoUpdateOnLaunchIfStale(thresholdHours: Int = 24, base: String) async {
        if isStale(thresholdHours: thresholdHours, base: base) {
            _ = await updateLatestForAll(base: base)
        }
    }
}
