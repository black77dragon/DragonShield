import Foundation

struct FXUpdateSummary {
    let updatedCurrencies: [String]
    let asOf: Date
    let provider: String
    let insertedCount: Int
    let failedCount: Int
    let skippedCount: Int // unsupported/missing from provider response
}

/// Orchestrates fetching latest FX and persisting to ExchangeRates.
final class FXUpdateService {
    private let db: DatabaseManager
    private let provider: FXRateProvider
    private(set) var lastError: Error?

    init(dbManager: DatabaseManager, provider: FXRateProvider = FrankfurterProvider()) {
        self.db = dbManager
        self.provider = provider
    }

    /// Returns the list of currency codes to update: active + API supported, excluding base.
    func targetCurrencies(base: String) -> [String] {
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
            print("[FX][Update] Start provider=\(provider.code) base=\(baseUpper) targets=\(targets.joined(separator: ","))")
            let response = try await provider.fetchLatest(base: baseUpper, symbols: targets)
            var inserted = 0
            var updated: [String] = []
            var eligible: [String] = []
            for code in targets {
                if let rate = response.rates[code] {
                    eligible.append(code)
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
                    print(String(format: "[FX][Update] %3@ -> CHF rate=%.6f (raw=%.6f, base=%@)", code, toCHF, rate, response.base.uppercased()))
                    if toCHF > 0, db.insertExchangeRate(currencyCode: code, rateDate: response.asOf, rateToChf: toCHF, rateSource: "api", apiProvider: provider.code, isLatest: true) {
                        inserted += 1
                        updated.append(code)
                    } else if toCHF <= 0 {
                        print("[FX][Update][WARN] Non-positive computed rate for \(code), skipping.")
                    } else {
                        print("[FX][Update][WARN] Insert failed for \(code). See sqlite logs above.")
                    }
                } else {
                    print("[FX][Update][WARN] No rate found in response for \(code)")
                }
            }
            let end = DispatchTime.now()
            let ms = Int(Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000.0)
            let skipped = targets.count - eligible.count
            let failed = max(eligible.count - inserted, 0)
            let status = failed > 0 || skipped > 0 ? "PARTIAL" : "SUCCESS"
            let errMsg = (failed > 0 || skipped > 0) ? "failed=\(failed); skipped=\(skipped)" : nil
            _ = db.recordFxRateUpdate(updateDate: response.asOf, apiProvider: provider.code, currenciesUpdated: updated, status: status, errorMessage: errMsg, ratesCount: inserted, executionTimeMs: ms)
            print("[FX][Update] Done inserted=\(inserted) failed=\(failed) skipped=\(skipped) asOf=\(DateFormatter.iso8601DateOnly.string(from: response.asOf))")
            return FXUpdateSummary(updatedCurrencies: updated, asOf: response.asOf, provider: provider.code, insertedCount: inserted, failedCount: failed, skippedCount: skipped)
        } catch {
            let end = DispatchTime.now()
            let ms = Int(Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000.0)
            lastError = error
            print("[FX][Update][ERROR] \(error)")
            _ = db.recordFxRateUpdate(updateDate: Date(), apiProvider: provider.code, currenciesUpdated: [], status: "FAILED", errorMessage: String(describing: error), ratesCount: 0, executionTimeMs: ms)
            return nil
        }
    }

    /// Auto-update on launch if the set is stale beyond threshold.
    func autoUpdateOnLaunchIfStale(thresholdHours: Int = 24, base: String) async {
        let stale = isStale(thresholdHours: thresholdHours, base: base)
        print("[FX][Auto] base=\(base.uppercased()) threshold=\(thresholdHours)h stale=\(stale)")
        if stale {
            _ = await updateLatestForAll(base: base)
        } else {
            print("[FX][Auto] Skipping update; rates are fresh.")
        }
    }
}
