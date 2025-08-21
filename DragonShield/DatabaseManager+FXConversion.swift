import SQLite3
import Foundation

extension DatabaseManager {
    /// Returns the exchange rate from a source currency to a target currency as of the given date.
    /// - Parameters:
    ///   - source: The currency code of the value being converted.
    ///   - target: The currency code of the desired target currency.
    ///   - date: The date for which the rate should be effective. If nil, the latest rate is used.
    /// - Returns: A tuple containing the rate and the date of the rate used, or nil if no rate is available for either currency.
    func exchangeRate(from source: String, to target: String, asOf date: Date?) -> (rate: Double, rateDate: Date)? {
        let src = source.uppercased()
        let tgt = target.uppercased()
        if src == tgt {
            return (1.0, date ?? Date())
        }
        func latestRate(for code: String) -> (Double, Date)? {
            if code == "CHF" {
                return (1.0, date ?? Date())
            }
            guard let info = fetchExchangeRates(currencyCode: code, upTo: date).first else { return nil }
            return (info.rateToChf, info.rateDate)
        }
        guard let srcInfo = latestRate(for: src), let tgtInfo = latestRate(for: tgt) else {
            return nil
        }
        let usedDate = max(srcInfo.1, tgtInfo.1)
        let rate: Double
        if tgt == "CHF" {
            rate = srcInfo.0
        } else if src == "CHF" {
            rate = 1.0 / tgtInfo.0
        } else {
            rate = srcInfo.0 / tgtInfo.0
        }
        return (rate, usedDate)
    }

    /// Converts an amount from one currency to another using the stored FX rates.
    /// - Parameters:
    ///   - amount: The numeric amount in the source currency.
    ///   - source: The currency code of the amount.
    ///   - target: The currency code to convert into.
    ///   - date: The effective date of the conversion. If nil, the latest rates are used.
    /// - Returns: The converted amount and the rate date used, or nil if a rate is missing.
    func convert(amount: Double, from source: String, to target: String, asOf date: Date?) -> (value: Double, rateDate: Date)? {
        guard let (rate, rateDate) = exchangeRate(from: source, to: target, asOf: date) else { return nil }
        return (amount * rate, rateDate)
    }

    /// Convenience helper to convert an amount to CHF.
    /// - Parameters:
    ///   - amount: The numeric amount in the source currency.
    ///   - currency: The currency code of the amount.
    ///   - date: The effective date of the conversion. If nil, the latest rate is used.
    /// - Returns: The CHF value and the rate date used, or nil if a rate is missing.
    func convertToChf(amount: Double, currency: String, asOf date: Date?) -> (valueChf: Double, rateDate: Date)? {
        convert(amount: amount, from: currency, to: "CHF", asOf: date)
    }
}

