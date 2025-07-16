import SwiftUI

struct AllocationDisplayItem: Identifiable {
    let id: String
    let assetClassName: String
    var targetPercent: Double
    var currentPercent: Double
    var currentValueCHF: Double
}

final class AssetAllocationViewModel: ObservableObject {
    @Published var items: [AllocationDisplayItem] = []
    var portfolioValue: Double = 0

    private var db: DatabaseManager?
    private var classIdMap: [String: Int] = [:]

    let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "CHF"
        f.maximumFractionDigits = 0
        return f
    }()

    func load(using dbManager: DatabaseManager) {
        self.db = dbManager
        let classes = dbManager.fetchAssetClassesDetailed()
        classIdMap = Dictionary(uniqueKeysWithValues: classes.map { ($0.name, $0.id) })

        let targets = dbManager.fetchPortfolioTargetRecords(portfolioId: 1)
        let targetPairs: [(Int, Double)] = targets.compactMap { record in
            guard let cid = record.classId, record.subClassId == nil else { return nil }
            return (cid, record.percent)
        }
        let targetMap: [Int: Double] = Dictionary(uniqueKeysWithValues: targetPairs)

        var actualTotals: [Int: Double] = [:]
        var totalValue: Double = 0

        let positions = dbManager.fetchPositionReports()
        var rateCache: [String: Double] = [:]

        for p in positions {
            guard let price = p.currentPrice,
                  let className = p.assetClass,
                  let classId = classIdMap[className] else { continue }
            var value = p.quantity * price
            let currency = p.instrumentCurrency.uppercased()
            if currency != "CHF" {
                if rateCache[currency] == nil {
                    rateCache[currency] = dbManager.fetchExchangeRates(currencyCode: currency, upTo: nil).first?.rateToChf
                }
                guard let r = rateCache[currency] else { continue }
                value *= r
            }
            actualTotals[classId, default: 0] += value
            totalValue += value
        }

        portfolioValue = totalValue

        items = classes.map { cls in
            let current = actualTotals[cls.id] ?? 0
            let currentPct = totalValue > 0 ? current / totalValue * 100 : 0
            return AllocationDisplayItem(id: cls.name,
                                         assetClassName: cls.name,
                                         targetPercent: targetMap[cls.id] ?? 0,
                                         currentPercent: currentPct,
                                         currentValueCHF: current)
        }
    }

    func updateTarget(for item: AllocationDisplayItem, to newValue: Double) {
        guard let db, let id = classIdMap[item.assetClassName] else { return }
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].targetPercent = newValue
        }
        db.upsertClassTarget(portfolioId: 1, classId: id, percent: newValue)
    }

    func deviationColor(for item: AllocationDisplayItem) -> Color {
        let diff = abs(item.currentPercent - item.targetPercent)
        switch diff {
        case 0..<5: return .success
        case 5..<15: return .warning
        default: return .error
        }
    }
}

