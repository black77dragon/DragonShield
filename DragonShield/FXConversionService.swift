import Foundation

final class FXConversionService {
    private let dbManager: DatabaseManager
    private var cache: [String: (rate: Double, date: Date)] = [:]
    private let cacheQueue = DispatchQueue(label: "com.dragonshield.fxconversionservice.cache", attributes: .concurrent)

    init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
    }

    /// Converts the given amount in the specified currency to CHF using the latest rate flagged with `is_latest`.
    /// - Parameters:
    ///   - amount: The amount in the source currency.
    ///   - currency: The ISO currency code of the amount.
    /// - Returns: Tuple with value in CHF, applied rate, and rate date, or `nil` if no rate exists.
    func convertToChf(amount: Double, currency: String) -> (valueChf: Double, rate: Double, rateDate: Date)? {
        let code = currency.uppercased()
        if code == "CHF" {
            return (amount, 1.0, .distantPast)
        }
        if let cached = cacheQueue.sync(execute: { self.cache[code] }) {
            return (amount * cached.rate, cached.rate, cached.date)
        }
        guard let rate = dbManager.fetchLatestExchangeRate(currencyCode: code) else {
            return nil
        }
        cacheQueue.async(flags: .barrier) {
            self.cache[code] = (rate.rateToChf, rate.rateDate)
        }
        return (amount * rate.rateToChf, rate.rateToChf, rate.rateDate)
    }
}
