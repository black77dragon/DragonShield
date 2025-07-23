import SwiftUI

struct CryptoHolding: Identifiable {
    let id = UUID()
    let name: String
    let valueCHF: Double
    let percentage: Double
}

final class CryptoTop5ViewModel: ObservableObject {
    @Published var holdings: [CryptoHolding] = []
    @Published var loading: Bool = false

    func load(db: DatabaseManager) {
        loading = true
        DispatchQueue.global().async {
            let positions = db.fetchPositionReports()
            var crypto: [(name: String, value: Double)] = []
            var total: Double = 0
            var rateCache: [String: Double] = [:]

            for p in positions {
                guard let price = p.currentPrice else { continue }
                let sub = p.assetSubClass?.lowercased() ?? ""
                if !sub.contains("crypto") { continue }
                var value = p.quantity * price
                let currency = p.instrumentCurrency.uppercased()
                if currency != "CHF" {
                    var rate = rateCache[currency]
                    if rate == nil {
                        rate = db.fetchExchangeRates(currencyCode: currency, upTo: nil).first?.rateToChf
                        rateCache[currency] = rate
                    }
                    guard let r = rate else { continue }
                    value *= r
                }
                crypto.append((name: p.instrumentName, value: value))
                total += value
            }

            crypto.sort { $0.value > $1.value }
            let top5 = Array(crypto.prefix(5))
            let rows = top5.map { item -> CryptoHolding in
                let pct = total > 0 ? (item.value / total * 100) : 0
                return CryptoHolding(name: item.name, valueCHF: item.value, percentage: pct)
            }

            DispatchQueue.main.async {
                self.holdings = rows
                self.loading = false
            }
        }
    }
}

