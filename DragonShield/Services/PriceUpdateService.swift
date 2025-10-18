import Foundation
import OSLog

final class PriceUpdateService {
    private let db: DatabaseManager

    init(dbManager: DatabaseManager) { self.db = dbManager }

    struct ResultItem {
        let instrumentId: Int
        let status: String
        let message: String
    }

    func fetchAndUpsert(_ records: [PriceSourceRecord]) async -> [ResultItem] {
        var results: [ResultItem] = []
        let log = LoggingService.shared
        await withTaskGroup(of: ResultItem?.self) { group in
            for rec in records {
                group.addTask { [weak self] in
                    guard let self else { return nil }
                    guard let provider = PriceProviderRegistry.shared.provider(for: rec.providerCode) else {
                        _ = self.db.updatePriceSourceStatus(instrumentId: rec.instrumentId, providerCode: rec.providerCode, status: "no_provider")
                        log.log("[PriceUpdate] No provider for instrumentId=\(rec.instrumentId) code=\(rec.providerCode)", type: .error)
                        return ResultItem(instrumentId: rec.instrumentId, status: "error", message: "Unknown provider \(rec.providerCode)")
                    }
                    log.log("[PriceUpdate] Fetching instrumentId=\(rec.instrumentId) provider=\(rec.providerCode) externalId=\(rec.externalId) expectedCurrency=\(rec.expectedCurrency ?? "-")", type: .info)
                    do {
                        let quote = try await provider.fetchLatest(externalId: rec.externalId, expectedCurrency: rec.expectedCurrency)
                        if let expected = rec.expectedCurrency, expected.uppercased() != quote.currency.uppercased() {
                            _ = self.db.updatePriceSourceStatus(instrumentId: rec.instrumentId, providerCode: rec.providerCode, status: "currency_mismatch")
                            log.log("[PriceUpdate] Currency mismatch instrumentId=\(rec.instrumentId) expected=\(expected) got=\(quote.currency)", type: .error)
                            return ResultItem(instrumentId: rec.instrumentId, status: "error", message: "Currency mismatch: expected \(expected), got \(quote.currency)")
                        }
                        let iso = ISO8601DateFormatter()
                        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        let asOfIso = iso.string(from: quote.asOf)
                        let ok = self.db.upsertPrice(instrumentId: rec.instrumentId, price: quote.price, currency: quote.currency, asOf: asOfIso, source: quote.source)
                        _ = self.db.updatePriceSourceStatus(instrumentId: rec.instrumentId, providerCode: rec.providerCode, status: ok ? "ok" : "db_error")
                        if ok {
                            log.log("[PriceUpdate] Updated instrumentId=\(rec.instrumentId) price=\(quote.price) curr=\(quote.currency) asOf=\(asOfIso) source=\(quote.source)")
                        } else {
                            log.log("[PriceUpdate] DB error instrumentId=\(rec.instrumentId)", type: .error)
                        }
                        return ResultItem(instrumentId: rec.instrumentId, status: ok ? "ok" : "error", message: ok ? "Updated" : "DB error")
                    } catch {
                        _ = self.db.updatePriceSourceStatus(instrumentId: rec.instrumentId, providerCode: rec.providerCode, status: "error")
                        log.log("[PriceUpdate] Fetch error instrumentId=\(rec.instrumentId) provider=\(rec.providerCode): \(error.localizedDescription)", type: .error)
                        return ResultItem(instrumentId: rec.instrumentId, status: "error", message: error.localizedDescription)
                    }
                }
            }
            for await item in group { if let it = item { results.append(it) } }
        }
        return results
    }
}
