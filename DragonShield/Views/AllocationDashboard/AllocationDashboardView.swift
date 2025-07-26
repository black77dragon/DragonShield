import SwiftUI
import Charts

struct AllocationDashboardView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = AllocationDashboardViewModel()

    private enum Constants {
        static let pagePadding: CGFloat = 32
        static let cardSpacing: CGFloat = 24
        static let cornerRadius: CGFloat = 12
    }

    private let gridColumns = [GridItem(.adaptive(minimum: 320, maximum: 480), spacing: Constants.cardSpacing)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: Constants.cardSpacing) {
                OverviewBar(viewModel: viewModel)
                AllocationTreeCard(viewModel: viewModel)
                DeviationChartsCard(viewModel: viewModel)
                RebalanceListCard(viewModel: viewModel)
            }
            .padding(.horizontal, Constants.pagePadding)
        }
        .navigationTitle("Asset Allocation Targets")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button("Import Targets") {}
                Button("Auto-Rebalance") {}.disabled(true)
            }
        }
        .onAppear { viewModel.load(using: dbManager) }
    }

    // MARK: - Subviews

    private struct Card<Content: View>: View {
        let title: String?
        let content: Content

        init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
            self.title = title
            self.content = content()
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                if let title = title {
                    Text(title).font(.headline)
                }
                content
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: Constants.cornerRadius)
                            .stroke(Color.quaternary, lineWidth: 1)
                    )
            )
        }
    }

    private struct OverviewBar: View {
        @ObservedObject var viewModel: AllocationDashboardViewModel

        private func tile(label: String, value: String, gradient: LinearGradient? = nil) -> some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(gradient ?? LinearGradient(colors: [.white], startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        }

        var body: some View {
            HStack(spacing: Constants.cardSpacing) {
                tile(label: "Portfolio Total", value: viewModel.portfolioTotalFormatted)
                Divider().frame(height: 40)
                tile(label: "Assets Out of Range", value: "\(viewModel.outOfRangeCount)",
                     gradient: LinearGradient(colors: [Color.numericRed.opacity(0.1), .white], startPoint: .topLeading, endPoint: .bottomTrailing))
                Divider().frame(height: 40)
                tile(label: "Largest Deviation", value: String(format: "%.1f%%", viewModel.largestDeviation),
                     gradient: LinearGradient(colors: [Color.numericAmber.opacity(0.1), .white], startPoint: .topLeading, endPoint: .bottomTrailing))
                Divider().frame(height: 40)
                tile(label: "Rebalance Amount", value: viewModel.rebalanceAmountFormatted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.white).shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1))
        }
    }

    private struct AllocationTreeCard: View {
        @ObservedObject var viewModel: AllocationDashboardViewModel

        var body: some View {
            Card("Asset Classes") {
                ScrollView {
                    OutlineGroup(viewModel.assets, children: \.children) { asset in
                        AssetRowView(asset: asset, level: asset.id.contains("sub-") ? 1 : 0)
                    }
                }
            }
        }
    }

    private struct AssetRowView: View {
        let asset: AllocationDashboardViewModel.Asset
        let level: Int

        var body: some View {
            HStack {
                Text(asset.name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(String(format: "%.1f%%", asset.targetPct))
                    .frame(width: 60, alignment: .trailing)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                Text(String(format: "%.1f%%", asset.actualPct))
                    .frame(width: 60, alignment: .trailing)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                DeviationBar(dev: asset.deviationPct)
                    .frame(width: 80, height: 6)
                Text(String(format: "%+.1f%%", asset.deviationPct))
                    .frame(width: 50, alignment: .trailing)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
            }
            .padding(.vertical, 4)
            .background(level == 0 ? Color.gray.opacity(0.1) : Color.clear)
        }
    }

    private struct DeviationBar: View {
        let dev: Double

        var body: some View {
            ZStack(alignment: .leading) {
                Capsule().fill(Color.quaternary)
                Capsule()
                    .fill(dev >= 0 ? Color.numericGreen : Color.numericRed)
                    .frame(width: abs(dev) * 60)
            }
            .offset(x: dev >= 0 ? 30 : -30)
        }
    }

    private struct DeviationChartsCard: View {
        @ObservedObject var viewModel: AllocationDashboardViewModel

        var body: some View {
            Card("Deviation Bubble Chart") {
                Chart(viewModel.bubbles) { bubble in
                    PointMark(
                        x: .value("Deviation", bubble.deviation),
                        y: .value("Allocation", bubble.allocation),
                        size: .value("Allocation %", bubble.allocation),
                        series: .value("Asset", bubble.name)
                    )
                    .symbol(by: .value("State", bubble.color))
                    .foregroundStyle(bubble.color)
                }
                .chartXScale(domain: -25...25)
                .chartYScale(domain: 0...40)
                .frame(height: 240)
            }
        }
    }

    private struct RebalanceListCard: View {
        @ObservedObject var viewModel: AllocationDashboardViewModel

        var body: some View {
            Card("Top Rebalancing Actions") {
                ForEach(viewModel.actions.prefix(5)) { action in
                    HStack {
                        Text(action.label)
                        Spacer()
                        Text(action.amount)
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                    }
                }
                Button("Execute") {}.disabled(true)
            }
        }
    }
}

struct AllocationDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        AllocationDashboardView().environmentObject(DatabaseManager())
    }
}
