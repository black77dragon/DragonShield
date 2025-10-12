import SwiftUI

class ExchangeRatesViewModel: ObservableObject {
    @Published var rates: [DatabaseManager.ExchangeRate] = []
    @Published var currencies: [DatabaseManager.CurrencyData] = []
    @Published var selectedCurrency: String? = nil
    @Published var asOfDate: Date = Date()
    @Published var log: [String] = []

    private var db: DatabaseManager

    init(db: DatabaseManager) {
        self.db = db
        self.asOfDate = db.asOfDate
        loadCurrencies()
        loadRates()
    }

    func loadCurrencies() {
        currencies = db.fetchActiveCurrencies().map {
            DatabaseManager.CurrencyData(code: $0.code, name: $0.name, symbol: $0.symbol)
        }
    }

    func loadRates() {
        rates = db.fetchExchangeRates(currencyCode: selectedCurrency, upTo: asOfDate)
    }

    func addRate(currency: String, date: Date, rate: Double, source: String, apiProvider: String?, latest: Bool) {
        if db.insertExchangeRate(currencyCode: currency, rateDate: date, rateToChf: rate, rateSource: source, apiProvider: apiProvider, isLatest: latest) {
            log.append("Added rate for \(currency) on \(DateFormatter.iso8601DateOnly.string(from: date)): \(rate) (\(source)\(apiProvider != nil ? ", \(apiProvider!)" : ""))")
            loadRates()
        }
    }

    func updateRate(id: Int, date: Date, rate: Double, source: String, apiProvider: String?, latest: Bool) {
        if db.updateExchangeRate(id: id, rateDate: date, rateToChf: rate, rateSource: source, apiProvider: apiProvider, isLatest: latest) {
            log.append("Edited rate #\(id)")
            loadRates()
        }
    }

    func deleteRate(id: Int) {
        if db.deleteExchangeRate(id: id) {
            log.append("Deleted rate #\(id)")
            loadRates()
        }
    }
}

extension DatabaseManager {
    struct CurrencyData {
        var code: String
        var name: String
        var symbol: String
    }
}
