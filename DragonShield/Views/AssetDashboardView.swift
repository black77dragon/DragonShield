import SwiftUI
import Charts

struct AssetDashboardView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var groups: [AssetDashboardClass] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(groups) { group in
                    VStack(alignment: .leading) {
                        Text(group.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Chart {
                            ForEach(group.assets.sorted { $0.value > $1.value }) { item in
                                BarMark(
                                    x: .value("Value", item.value),
                                    y: .value("Asset", item.name)
                                )
                                .annotation(position: .trailing) {
                                    Text(String(format: "%.0f", item.value))
                                        .font(.caption)
                                }
                            }
                        }
                        .frame(height: CGFloat(max(150, group.assets.count * 24)))
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Asset Dashboard")
        .onAppear(perform: loadData)
    }

    private func loadData() {
        groups = dbManager.fetchAssetDashboardData()
    }
}

#Preview {
    AssetDashboardView()
        .environmentObject(DatabaseManager())
}
