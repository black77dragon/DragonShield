import SwiftUI
import MapKit

class CurrencyMapViewModel: ObservableObject {
    @Published var totals: [String: Double] = [:]
    @Published var quantileBreaks: [Double] = []
    @Published var loading: Bool = false

    func load(using db: DatabaseManager) {
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
                        rateCache[currency] = db.fetchExchangeRates(currencyCode: currency, upTo: nil).first?.rateToChf
                    }
                    if let rate = rateCache[currency] { value *= rate } else { continue }
                }
                totals[currency, default: 0] += value
            }
            let values = totals.values.sorted()
            var breaks: [Double] = []
            if !values.isEmpty {
                for i in 1..<5 {
                    let idx = Int(Double(values.count - 1) * Double(i) / 5.0)
                    breaks.append(values[idx])
                }
            }
            DispatchQueue.main.async {
                self.totals = totals
                self.quantileBreaks = breaks
                self.loading = false
            }
        }
    }
}
