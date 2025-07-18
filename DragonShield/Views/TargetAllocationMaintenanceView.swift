import SwiftUI

/// Legacy target allocation editor. The underlying data logic remains unchanged
/// but the UI now delegates to ``AllocationTargetsTableView`` for a unified
/// appearance.
struct TargetAllocationMaintenanceView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    var body: some View {
        AllocationTargetsTableView()
            .navigationTitle("Target Asset Allocation")
    }
}

struct TargetAllocationMaintenanceView_Previews: PreviewProvider {
    static var previews: some View {
        TargetAllocationMaintenanceView()
            .environmentObject(DatabaseManager())
    }
}

