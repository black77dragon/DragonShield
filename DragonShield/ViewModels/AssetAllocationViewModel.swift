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
        items = result.items.map { AllocationDisplayItem(id: $0.id,
                                                         assetClassName: $0.assetClassName,
                                                         targetPercent: $0.targetPercent,
                                                         currentPercent: $0.currentPercent,
                                                         currentValueCHF: $0.currentValue) }
        classIdMap = Dictionary(uniqueKeysWithValues: dbManager.fetchAssetClassesDetailed().map { ($0.name, $0.id) })
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

