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
        let result = dbManager.fetchAssetAllocationVariance()
        portfolioValue = result.portfolioValue
        let classes = dbManager.fetchAssetClassesDetailed()

        let varianceMap = Dictionary(uniqueKeysWithValues: result.items.map { ($0.assetClassName, $0) })

        items = classes.map { cls in
            let v = varianceMap[cls.name]
            return AllocationDisplayItem(id: cls.name,
                                         assetClassName: cls.name,
                                         targetPercent: v?.targetPercent ?? 0,
                                         currentPercent: v?.currentPercent ?? 0,
                                         currentValueCHF: v?.currentValue ?? 0)
        }

        classIdMap = Dictionary(uniqueKeysWithValues: classes.map { ($0.name, $0.id) })
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

