import SwiftUI

struct CurrencyBreakdown: Identifiable {
    let id = UUID()
    let currencyCode: String
    let percentage: Double
    let totalCHF: Double
}

class CurrencyExposureViewModel: ObservableObject {
    @Published var currencyExposure: [CurrencyBreakdown] = []
    @Published var loading: Bool = false

    func calculate(db: DatabaseManager) {
        loading = true
        DispatchQueue.global().async {
            let positions = db.fetchPositionReports()
            var totals: [String: Double] = [:]
            var rateCache: [String: Double] = [:]
            var total: Double = 0
            for p in positions {
                guard let price = p.currentPrice else { continue }
                let currency = p.instrumentCurrency.uppercased()
                var value = p.quantity * price
                if currency != "CHF" {
                    if rateCache[currency] == nil {
                        let rates = db.fetchExchangeRates(currencyCode: currency, upTo: nil)
                        if let rate = rates.first?.rateToChf {
                            rateCache[currency] = rate
                        } else {
                            continue
                        }
                    }
                    if let rate = rateCache[currency] { value *= rate }
                }
                totals[currency, default: 0] += value
                total += value
            }
            var breakdown = totals.map { CurrencyBreakdown(currencyCode: $0.key, percentage: 0, totalCHF: $0.value) }
            breakdown.sort { $0.totalCHF > $1.totalCHF }
            var result: [CurrencyBreakdown] = []
            var otherValue: Double = 0
            for (index, item) in breakdown.enumerated() {
                if index < 6 {
                    result.append(item)
                } else {
                    otherValue += item.totalCHF
                }
            }
            if otherValue > 0 {
                result.append(CurrencyBreakdown(currencyCode: "Other", percentage: 0, totalCHF: otherValue))
            }
            result = result.map { br in
                CurrencyBreakdown(currencyCode: br.currencyCode, percentage: total > 0 ? br.totalCHF / total * 100 : 0, totalCHF: br.totalCHF)
            }
            DispatchQueue.main.async {
                self.currencyExposure = result
                self.loading = false
            }
        }
    }
}
