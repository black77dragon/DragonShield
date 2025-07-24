import SwiftUI

struct CurrencyMapEntry: Identifiable {
    let id = UUID()
    let currency: String
    let country: String
    let totalCHF: Double
}

class CurrencyMapViewModel: ObservableObject {
    @Published var entries: [CurrencyMapEntry] = []
    @Published var quantiles: [Double] = []
    @Published var loading: Bool = false

    private let currencyToCountry: [String: String] = [
        "USD": "United States",
        "EUR": "Germany",
        "GBP": "United Kingdom",
        "CHF": "Switzerland",
        "JPY": "Japan",
        "CAD": "Canada",
        "AUD": "Australia",
        "CNY": "China",
        "HKD": "Hong Kong",
        "INR": "India"
    ]

    func calculate(db: DatabaseManager) {
        loading = true
        DispatchQueue.global().async {
            let positions = db.fetchPositionReports()
            var totals: [String: Double] = [:]
            var rateCache: [String: Double] = [:]
            for p in positions {
                guard let price = p.currentPrice else { continue }
                let currency = p.instrumentCurrency.uppercased()
                var value = p.quantity * price
                if currency != "CHF" {
                    if rateCache[currency] == nil {
                        let rates = db.fetchExchangeRates(currencyCode: currency, upTo: nil)
                        if let rate = rates.first?.rateToChf { rateCache[currency] = rate }
                    }
                    if let rate = rateCache[currency] { value *= rate }
                }
                totals[currency, default: 0] += value
            }
            var entries: [CurrencyMapEntry] = []
            for (code, total) in totals {
                guard let country = self.currencyToCountry[code] else { continue }
                entries.append(CurrencyMapEntry(currency: code, country: country, totalCHF: total))
            }
            entries.sort { $0.totalCHF > $1.totalCHF }
            let values = entries.map { $0.totalCHF }.sorted()
            var quantiles: [Double] = []
            if !values.isEmpty {
                for q in 1..<5 {
                    let idx = Int(Double(values.count - 1) * Double(q) / 5.0)
                    quantiles.append(values[idx])
                }
            }
            DispatchQueue.main.async {
                self.entries = entries
                self.quantiles = quantiles
                self.loading = false
            }
        }
    }
}
