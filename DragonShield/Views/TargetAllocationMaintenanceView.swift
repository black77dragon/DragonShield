import SwiftUI

/// Legacy target allocation editor. The underlying data logic remains unchanged
/// but the UI now delegates to ``AllocationTargetsTableView`` for a unified
/// appearance.
struct TargetAllocationMaintenanceView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var overviewModel = AllocationDashboardViewModel()

    var body: some View {
        VStack(spacing: 0) {
            OverviewBar(portfolioTotal: overviewModel.portfolioTotalFormatted,
                        outOfRange: "\(overviewModel.outOfRangeCount)",
                        largestDev: String(format: "%.1f%%", overviewModel.largestDeviation),
                        rebalAmount: overviewModel.rebalanceAmountFormatted)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.horizontal, 24)

            AllocationTargetsTableView()
        }
        .navigationTitle("Target Asset Allocation")
        .onAppear { overviewModel.load(using: dbManager) }
    }
}

struct TargetAllocationMaintenanceView_Previews: PreviewProvider {
    static var previews: some View {
        TargetAllocationMaintenanceView()
            .environmentObject(DatabaseManager())
    }
}

