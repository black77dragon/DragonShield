import Foundation
import SwiftUI

class TargetAllocationViewModel: ObservableObject {
    @Published var classTargets: [Int: Double] = [:]
    @Published var subClassTargets: [Int: Double] = [:]
    @Published var assetClasses: [DatabaseManager.AssetClassData] = []
    @Published var expandedClasses: [Int: Bool] = [:]

    private let dbManager: DatabaseManager
    private let portfolioId: Int

    let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    init(dbManager: DatabaseManager, portfolioId: Int) {
        self.dbManager = dbManager
        self.portfolioId = portfolioId
        loadTargets()
    }

    private func loadTargets() {
        assetClasses = dbManager.fetchAssetClassesDetailed()
        let rows = dbManager.fetchPortfolioTargetRecords(portfolioId: portfolioId)
        for row in rows {
            if let classId = row.classId {
                classTargets[classId] = row.percent
            }
            if let subId = row.subClassId {
                subClassTargets[subId] = row.percent
            }
        }
    }

    func subAssetClasses(for classId: Int) -> [DatabaseManager.SubClassTarget] {
        dbManager.subAssetClasses(for: classId)
    }

    func totalSubClassPct(for classId: Int) -> Double {
        subAssetClasses(for: classId)
            .map { subClassTargets[$0.id] ?? 0 }
            .reduce(0, +)
    }

    func saveAllTargets() {
        for (classId, pct) in classTargets {
            dbManager.upsertClassTarget(portfolioId: portfolioId, classId: classId, percent: pct)
        }
        for (subId, pct) in subClassTargets {
            dbManager.upsertSubClassTarget(portfolioId: portfolioId, subClassId: subId, percent: pct)
        }
    }
}
