import Foundation
import SwiftUI

extension DatabaseManager {
    struct AllocationTarget: Identifiable, Hashable {
        let id: String
        var assetClassName: String
        var targetPercent: Double
        var currentPercent: Double
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
}
