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
            var total: Double = 0
            for p in positions {
                guard let price = p.currentPrice else { continue }
                let currency = p.instrumentCurrency.uppercased()
                let valueOrig = p.quantity * price
                guard let conv = db.convert(amount: valueOrig, from: currency, asOf: nil) else { continue }
                totals[currency, default: 0] += conv.value
                total += conv.value
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
