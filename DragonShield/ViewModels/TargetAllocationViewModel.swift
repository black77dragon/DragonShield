import Foundation
import SwiftUI

class TargetAllocationViewModel: ObservableObject {
    @Published var classTargets: [Int: Double] = [:] {
        didSet {
            for (classID, pct) in classTargets {
                if pct == 0 {
                    for sub in subAssetClasses(for: classID) {
                        subClassTargets[sub.id] = 0
                    }
                }
            }
        }
    }
    @Published var subClassTargets: [Int: Double] = [:]
    @Published var assetClasses: [DatabaseManager.AssetClassData] = []
    @Published var expandedClasses: [Int: Bool] = [:]
    @Published var includeDirectRealEstate: Bool

    private let dbManager: DatabaseManager
    private let portfolioId: Int

    let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "CHF"
        f.maximumFractionDigits = 0
        return f
    }()

    init(dbManager: DatabaseManager, portfolioId: Int) {
        self.dbManager = dbManager
        self.portfolioId = portfolioId
        self.includeDirectRealEstate = dbManager.includeDirectRealEstate
        loadTargets()
    }

    private func loadTargets() {
        assetClasses = dbManager.fetchAssetClassesDetailed()
        let rows = dbManager.fetchPortfolioTargetRecords(portfolioId: portfolioId)
        var classMap: [Int: Double] = [:]
        var subMap: [Int: Double] = [:]
        for row in rows {
            if let classId = row.classId, row.subClassId == nil {
                classMap[classId] = row.percent
            }
            if let subId = row.subClassId {
                subMap[subId] = row.percent
            }
        }
        subClassTargets = subMap
        classTargets = classMap
    }

    func subAssetClasses(for classId: Int) -> [DatabaseManager.SubClassTarget] {
        var subs = dbManager.subAssetClasses(for: classId)
        if !includeDirectRealEstate {
            subs.removeAll { $0.name == "Own Real Estate" }
        }
        return subs
    }

    func totalSubClassPct(for classId: Int) -> Double {
        subAssetClasses(for: classId)
            .map { subClassTargets[$0.id] ?? 0 }
            .reduce(0, +)
    }

    var sortedClasses: [DatabaseManager.AssetClassData] {
        let active = assetClasses
            .filter { (classTargets[$0.id] ?? 0) > 0 }
            .sorted { (classTargets[$0.id] ?? 0) > (classTargets[$1.id] ?? 0) }
        let inactive = assetClasses.filter { (classTargets[$0.id] ?? 0) == 0 }
        return active + inactive
    }

    func chartColor(for classId: Int) -> Color {
        guard let codeString = assetClasses.first(where: { $0.id == classId })?.code,
              let code = AssetClassCode(rawValue: codeString) else { return .gray }
        return Theme.assetClassColors[code] ?? .gray
    }

    func saveAllTargets() {
        _ = dbManager.updateConfiguration(key: "include_direct_re", value: includeDirectRealEstate ? "true" : "false")
        for (classId, pct) in classTargets {
            dbManager.upsertClassTarget(portfolioId: portfolioId, classId: classId, percent: pct, tolerance: 5)
        }
        for (subId, pct) in subClassTargets {
            dbManager.upsertSubClassTarget(portfolioId: portfolioId, subClassId: subId, percent: pct, tolerance: 5)
        }
    }

    func resetAllTargets() {
        for key in classTargets.keys { classTargets[key] = 0 }
        for key in subClassTargets.keys { subClassTargets[key] = 0 }
    }
}
