import SwiftUI
import Charts

struct RiskBucketsTile: DashboardTile {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = RiskBucketsViewModel()

    init() {}
    static let tileID = "risk_buckets"
    static let tileName = "Top 5 Risk Buckets by Value"
    static let iconName = "chart.pie"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(Self.tileName)
                    .font(.headline)
                Spacer()
                Picker("Dimension", selection: $viewModel.selectedRiskDimension) {
                    ForEach(RiskGroupingDimension.allCases) { dim in
                        Text(dim.rawValue.capitalized).tag(dim)
                    }
                }
                .pickerStyle(.menu)
            }
            if viewModel.topRiskBuckets.isEmpty {
                Text("No data to display")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart(viewModel.topRiskBuckets) { bucket in
                    SectorMark(
                        angle: .value("Value", bucket.exposurePct)
                    )
                    .foregroundStyle(bucket.isOverconcentrated ? Color.error : Theme.primaryAccent)
                    .annotation(position: .overlay) {
                        VStack {
                            Text(bucket.label)
                                .font(.caption2)
                            Text(String(format: "%.1f%%", bucket.exposurePct * 100))
                                .font(.caption2)
                        }
                        .foregroundColor(.white)
                    }
                }
                .chartLegend(.hidden)
                .frame(height: 180)
            }
        }
        .padding(16)
        .background(Color(red: 245/255, green: 247/255, blue: 250/255))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        .onAppear { viewModel.load(using: dbManager) }
        .accessibilityElement(children: .combine)
    }
}
