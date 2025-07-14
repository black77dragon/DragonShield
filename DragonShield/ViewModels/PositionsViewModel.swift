import Foundation
import SwiftUI

class PositionsViewModel: ObservableObject {
    struct TopPositionCHF: Identifiable, Equatable {
        let id: Int
        let instrumentName: String
        let valueChf: Double
        let currency: String
    }

    @Published var top10PositionsCHF: [TopPositionCHF] = []

    private let db: DatabaseManager

    init(db: DatabaseManager = DatabaseManager()) {
        self.db = db
    }

    func loadTopPositions() {
        let reports = db.fetchPositionReports()
        var rates: [String: Double] = ["CHF": 1.0]
        for report in reports {
            let code = report.instrumentCurrency
            if rates[code] == nil && code != "CHF" {
                let rate = db.fetchExchangeRates(currencyCode: code).first?.rateToChf ?? 1.0
                rates[code] = rate
            }
        }
        let items = reports.compactMap { report -> TopPositionCHF? in
            guard let price = report.currentPrice else { return nil }
            let rate = rates[report.instrumentCurrency] ?? 1.0
            let value = report.quantity * price * rate
            return TopPositionCHF(id: report.id,
                                  instrumentName: report.instrumentName,
                                  valueChf: value,
                                  currency: report.instrumentCurrency)
        }
        .sorted { $0.valueChf > $1.valueChf }
        top10PositionsCHF = Array(items.prefix(10))
    }
}
