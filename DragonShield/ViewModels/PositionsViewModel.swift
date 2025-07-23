import SwiftUI

class PositionsViewModel: ObservableObject {
    @Published var totalAssetValueCHF: Double = 0
    @Published var positionValueOriginal: [Int: Double] = [:]
    @Published var positionValueCHF: [Int: Double?] = [:]
    @Published var currencySymbols: [String: String] = [:]
    @Published var calculating: Bool = false
    @Published var showErrorToast: Bool = false
    @Published var top10PositionsCHF: [TopPosition] = []

    struct TopPosition: Identifiable {
        let id: Int
        let instrument: String
        let valueCHF: Double
        let currency: String
    }

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
                self.top10PositionsCHF = orig.keys.compactMap { id in
                    if let value = chf[id], let v = value {
                        let name = positions.first { $0.id == id }?.instrumentName ?? ""
                        let currency = positions.first { $0.id == id }?.instrumentCurrency.uppercased() ?? "CHF"
                        return TopPosition(id: id, instrument: name, valueCHF: v, currency: currency)
                    }
                    return nil
                }
                .sorted { $0.valueCHF > $1.valueCHF }
                .prefix(10)
                .map { $0 }
                self.calculating = false
                self.showErrorToast = missingRate
            }
        }
    }

    func calculateTop10Positions(db: DatabaseManager,
                                 excludeOwnRealEstate: Bool = false) {
        var positions = db.fetchPositionReports()
        if excludeOwnRealEstate {
            positions = positions.filter { $0.assetSubClass != "Own Real Estate" }
        }
        calculateValues(positions: positions, db: db)
    }
}
