import SwiftUI

class PositionsViewModel: ObservableObject {
    @Published var totalAssetValueCHF: Double = 0
    @Published var calculating: Bool = false
    @Published var showErrorToast: Bool = false

    func calculateTotalAssetValue(positions: [PositionReportData], db: DatabaseManager) {
        calculating = true
        DispatchQueue.global().async {
            var total: Double = 0
            for p in positions {
                guard let price = p.currentPrice else { continue }
                var value = p.quantity * price
                if p.instrumentCurrency.uppercased() != "CHF" {
                    let rates = db.fetchExchangeRates(currencyCode: p.instrumentCurrency, upTo: nil)
                    guard let rate = rates.first?.rateToChf else {
                        DispatchQueue.main.async {
                            self.calculating = false
                            self.showErrorToast = true
                        }
                        return
                    }
                    value *= rate
                }
                total += value
            }
            DispatchQueue.main.async {
                self.totalAssetValueCHF = total
                self.calculating = false
            }
        }
    }
}
