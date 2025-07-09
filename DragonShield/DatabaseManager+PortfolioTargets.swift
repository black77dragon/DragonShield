import Foundation
import SwiftUI

extension DatabaseManager {
    struct AllocationTarget: Identifiable, Hashable {
        let id: String
        var assetClassName: String
        var targetPercent: Double
        var currentPercent: Double
    }

    struct SubClassTarget: Identifiable, Hashable {
        let id: Int
        var name: String
        var targetPercent: Double
        var currentPercent: Double
    }

    struct ClassTarget: Identifiable, Hashable {
        let id: Int
        var name: String
        var targetPercent: Double
        var currentPercent: Double
        var subTargets: [SubClassTarget]
    }

    /// Returns current and target allocation percentages grouped by asset class.
    /// This uses sample data from `fetchAssetAllocationVariance()` for now.
    func fetchPortfolioTargets() -> [AllocationTarget] {
        let variance = fetchAssetAllocationVariance()
        return variance.items.map { item in
            AllocationTarget(id: item.id,
                              assetClassName: item.assetClassName,
                              targetPercent: item.targetPercent,
                              currentPercent: item.currentPercent)
        }
    }

    /// Persists updated target percentages. The demo implementation only logs
    /// the values but would update `PortfolioInstruments` in a full build.
    func savePortfolioTargets(_ targets: [AllocationTarget]) {
        for target in targets {
            LoggingService.shared.log(
                "Saving target for \(target.assetClassName): \(target.targetPercent)%",
                type: .info,
                logger: .database
            )
        }
        // Actual SQL update omitted in sample code base
    }

    /// Returns all asset classes with optional subclass targets. This sample
    /// implementation combines basic asset class data with placeholder
    /// subclass information.
    func fetchPortfolioClassTargets() -> [ClassTarget] {
        let classes = fetchAssetClassesDetailed()
        let varianceMap = Dictionary(uniqueKeysWithValues: fetchPortfolioTargets().map { ($0.assetClassName, $0) })

        return classes.map { cls in
            let base = varianceMap[cls.name]
            let subs = fetchSubClasses(for: cls.id).map { sub in
                SubClassTarget(id: sub.id,
                               name: sub.name,
                               targetPercent: 0,
                               currentPercent: 0)
            }
            return ClassTarget(id: cls.id,
                               name: cls.name,
                               targetPercent: base?.targetPercent ?? 0,
                               currentPercent: base?.currentPercent ?? 0,
                               subTargets: subs)
        }
    }

    /// Placeholder for saving class and subclass targets separately.
    func savePortfolioClassTargets(_ classes: [ClassTarget]) {
        for cls in classes {
            LoggingService.shared.log(
                "Saving class target for \(cls.name): \(cls.targetPercent)%",
                type: .info,
                logger: .database
            )
            for sub in cls.subTargets {
                LoggingService.shared.log(
                    "  Sub \(sub.name): \(sub.targetPercent)%",
                    type: .info,
                    logger: .database
                )
            }
        }
        // Actual SQL update omitted in sample code base
    }

    private func fetchSubClasses(for classId: Int) -> [(id: Int, name: String)] {
        var subClasses: [(id: Int, name: String)] = []
        let query = "SELECT sub_class_id, sub_class_name FROM AssetSubClasses WHERE class_id = ? ORDER BY sort_order, sub_class_name"

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(classId))
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                if let namePtr = sqlite3_column_text(statement, 1) {
                    subClasses.append((id: id, name: String(cString: namePtr)))
                }
            }
        } else {
            LoggingService.shared.log(
                "Failed to prepare fetchSubClasses: \(String(cString: sqlite3_errmsg(db)))",
                type: .error,
                logger: .database
            )
        }
        sqlite3_finalize(statement)
        return subClasses
    }
}
