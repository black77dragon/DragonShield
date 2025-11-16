import SwiftUI

enum RiskGroupingDimension: String, CaseIterable, Identifiable {
    case sector
    case issuer
    case currency
    case country
    case assetClass

    var id: String { rawValue }
}

struct RiskBucket: Identifiable {
    let id = UUID()
    let label: String
    let valueCHF: Double
    let exposurePct: Double
    let isOverconcentrated: Bool
}

final class RiskBucketsViewModel: ObservableObject {
    @Published var topRiskBuckets: [RiskBucket] = []
    @Published var selectedRiskDimension: RiskGroupingDimension = .sector {
        didSet { computeBuckets() }
    }

    private var db: DatabaseManager?
    private var positions: [PositionReportData] = []

    func load(using dbManager: DatabaseManager) {
        db = dbManager
        positions = dbManager.fetchPositionReports()
        computeBuckets()
    }

    private func computeBuckets() {
        guard let db else { return }
        var rateCache: [String: Double] = [:]
        var groups: [String: Double] = [:]
        var total = 0.0

        for p in positions {
            guard let iid = p.instrumentId, let lp = db.getLatestPrice(instrumentId: iid) else { continue }
            var value = p.quantity * lp.price
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
            total += value
            let key: String
            switch selectedRiskDimension {
            case .sector:
                key = p.instrumentSector ?? "Unknown"
            case .issuer:
                key = p.institutionName
            case .currency:
                key = currency
            case .country:
                key = p.instrumentCountry ?? "Unknown"
            case .assetClass:
                key = p.assetClass ?? "Unknown"
            }
            groups[key, default: 0] += value
        }

        guard total > 0 else {
            topRiskBuckets = []
            return
        }

        let buckets = groups.map { label, value in
            RiskBucket(label: label,
                       valueCHF: value,
                       exposurePct: value / total,
                       isOverconcentrated: value / total > 0.25)
        }
        .sorted { $0.valueCHF > $1.valueCHF }
        .prefix(5)

        topRiskBuckets = Array(buckets)
    }
}
