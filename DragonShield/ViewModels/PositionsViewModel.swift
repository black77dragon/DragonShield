import SwiftUI

class PositionsViewModel: ObservableObject {
    @Published var totalAssetValueCHF: Double = 0
    @Published var positionValueOriginal: [Int: Double] = [:]
    @Published var positionValueCHF: [Int: Double?] = [:]
    @Published var currencySymbols: [String: String] = [:]
    @Published var calculating: Bool = false
    @Published var showErrorToast: Bool = false

    func calculateValues(positions: [PositionReportData], db: DatabaseManager) {
        calculating = true
        DispatchQueue.global().async {
            var total: Double = 0
            var orig: [Int: Double] = [:]
            var chf: [Int: Double?] = [:]
            var rateCache: [String: Double] = [:]
            var symbolCache: [String: String] = [:]
            var missingRate = false

            for p in positions {
                guard let price = p.currentPrice else { continue }
                let key = p.id

                let currency = p.instrumentCurrency.uppercased()
                let valueOrig = p.quantity * price
                orig[key] = valueOrig

                if let sym = symbolCache[currency] {
                    symbolCache[currency] = sym
                } else if let details = db.fetchCurrencyDetails(code: currency) {
                    symbolCache[currency] = details.symbol
                } else {
                    symbolCache[currency] = currency
                }

                var valueCHF = valueOrig
                if currency != "CHF" {
                    var rate = rateCache[currency]
                    if rate == nil {
                        let rates = db.fetchExchangeRates(currencyCode: currency, upTo: nil)
                        if let r = rates.first?.rateToChf {
                            rateCache[currency] = r
                            rate = r
                        }
                    }
                    if let r = rate {
                        valueCHF *= r
                        chf[key] = valueCHF
                        total += valueCHF
                    } else {
                        missingRate = true
                        chf[key] = nil
                    }
                } else {
                    chf[key] = valueCHF
                    total += valueCHF
                }
            }

            DispatchQueue.main.async {
                self.positionValueOriginal = orig
                self.positionValueCHF = chf
                self.currencySymbols = symbolCache
                self.totalAssetValueCHF = total
                self.calculating = false
                self.showErrorToast = missingRate
            }
        }
    }
}
