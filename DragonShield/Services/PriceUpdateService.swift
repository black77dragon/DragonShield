import Foundation

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
        await withTaskGroup(of: ResultItem?.self) { group in
            for rec in records {
                group.addTask { [weak self] in
                    guard let self else { return nil }
                    guard let provider = PriceProviderRegistry.shared.provider(for: rec.providerCode) else {
                        _ = self.db.updatePriceSourceStatus(instrumentId: rec.instrumentId, providerCode: rec.providerCode, status: "no_provider")
                        return ResultItem(instrumentId: rec.instrumentId, status: "error", message: "Unknown provider \(rec.providerCode)")
                    }
                    do {
                        let quote = try await provider.fetchLatest(externalId: rec.externalId, expectedCurrency: rec.expectedCurrency)
                        if let expected = rec.expectedCurrency, expected.uppercased() != quote.currency.uppercased() {
                            _ = self.db.updatePriceSourceStatus(instrumentId: rec.instrumentId, providerCode: rec.providerCode, status: "currency_mismatch")
                            return ResultItem(instrumentId: rec.instrumentId, status: "error", message: "Currency mismatch: expected \(expected), got \(quote.currency)")
                        }
                        let iso = ISO8601DateFormatter()
                        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        let ok = self.db.upsertPrice(instrumentId: rec.instrumentId, price: quote.price, currency: quote.currency, asOf: iso.string(from: quote.asOf), source: quote.source)
                        _ = self.db.updatePriceSourceStatus(instrumentId: rec.instrumentId, providerCode: rec.providerCode, status: ok ? "ok" : "db_error")
                        return ResultItem(instrumentId: rec.instrumentId, status: ok ? "ok" : "error", message: ok ? "Updated" : "DB error")
                    } catch {
                        _ = self.db.updatePriceSourceStatus(instrumentId: rec.instrumentId, providerCode: rec.providerCode, status: "error")
                        return ResultItem(instrumentId: rec.instrumentId, status: "error", message: error.localizedDescription)
                    }
                }
            }
            for await item in group { if let it = item { results.append(it) } }
        }
        return results
    }
}

