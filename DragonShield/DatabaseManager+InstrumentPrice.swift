import Foundation
import Combine

extension DatabaseManager {
    /// Lists instruments with their latest price (if any), with optional filters.
    /// - Parameters:
    ///   - search: Case-insensitive filter across name, ticker, ISIN, valor.
    ///   - currencies: Restrict to these currency codes (uppercased).
    ///   - missingOnly: If true, only instruments without a latest price.
    ///   - staleDays: If provided, include instruments with latest price older than N days.
    func listInstrumentLatestPrices(
        search: String? = nil,
        currencies: [String]? = nil,
        missingOnly: Bool = false,
        staleDays: Int? = nil
    ) -> [InstrumentLatestPriceRow] {
        InstrumentPriceRepository(connection: databaseConnection).listInstrumentLatestPrices(
            search: search,
            currencies: currencies,
            missingOnly: missingOnly,
            staleDays: staleDays
        )
    }

    func getLatestPrice(instrumentId: Int) -> (price: Double, currency: String, asOf: String)? {
        InstrumentPriceRepository(connection: databaseConnection).getLatestPrice(instrumentId: instrumentId)
    }

    func upsertPrice(instrumentId: Int, price: Double, currency: String, asOf: String, source: String? = nil) -> Bool {
        let ok = InstrumentPriceRepository(connection: databaseConnection).upsertPrice(
            instrumentId: instrumentId,
            price: price,
            currency: currency,
            asOf: asOf,
            source: source
        )
        if ok {
            // Notify SwiftUI views bound to DatabaseManager to refresh derived queries
            DispatchQueue.main.async { [weak self] in self?.objectWillChange.send() }
        }
        return ok
    }

    func listPriceHistory(instrumentId: Int, limit: Int = 20) -> [InstrumentPriceHistoryRow] {
        InstrumentPriceRepository(connection: databaseConnection)
            .listPriceHistory(instrumentId: instrumentId, limit: limit)
    }

    func latestPriceUpdateTimestamp() -> Date? {
        InstrumentPriceRepository(connection: databaseConnection).latestPriceUpdateTimestamp()
    }
}
