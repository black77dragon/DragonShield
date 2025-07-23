import SwiftUI
import Charts

struct RiskBucketsTile: DashboardTile {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = RiskBucketsViewModel()

    init() {}
    static let tileID = "risk_buckets"
    static let tileName = "Top 5 Risk Buckets by Value"
    static let iconName = "chart.pie"

    private let palette: [Color] = [.teal, .purple, .green, .orange, .red]

    private func color(for index: Int) -> Color {
        palette[index % palette.count]
    }

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
                HStack(alignment: .top) {
                    Chart(Array(viewModel.topRiskBuckets.enumerated()), id: \.element.id) { idx, bucket in
                        SectorMark(
                            angle: .value("Share", bucket.exposurePct),
                            innerRadius: .ratio(0.6)
                        )
                        .foregroundStyle(color(for: idx))
                    }
                    .chartLegend(.hidden)
                    .frame(width: 100, height: 100)

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(viewModel.topRiskBuckets.enumerated()), id: \.element.id) { idx, bucket in
                            HStack {
                                Rectangle()
                                    .fill(color(for: idx))
                                    .frame(width: 12, height: 12)
                                Text(bucket.label)
                                    .frame(width: 80, alignment: .leading)
                                Text(String(format: "%.1f%%", bucket.exposurePct * 100))
                                    .frame(width: 50, alignment: .trailing)
                                Text(String(format: "%.0f CHF", bucket.valueCHF))
                            }
                            .foregroundColor(.primary)
                        }
                    }
                    .font(.caption)
                    Spacer()
                }
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
