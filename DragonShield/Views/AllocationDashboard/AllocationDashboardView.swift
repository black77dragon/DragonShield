import SwiftUI
import Charts

struct AllocationDashboardView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = AllocationDashboardViewModel()

    private let gridColumns = [
        GridItem(.adaptive(minimum: 320, maximum: 480), spacing: 24)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 24) {
                OverviewBar(total: viewModel.portfolioTotalFormatted,
                            outOfRange: viewModel.outOfRangeCount,
                            largestDeviation: viewModel.largestDeviation,
                            rebalanceAmount: viewModel.rebalanceAmountFormatted)
                AllocationTreeCard(viewModel: viewModel)
                DeviationChartsCard(viewModel: viewModel)
                RebalanceListCard(viewModel: viewModel)
            }
            .padding(.horizontal, 32)
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

}

// MARK: - Subviews

private struct OverviewBar: View {
    var total: String
    var outOfRange: Int
    var largestDeviation: Double
    var rebalanceAmount: String

    var body: some View {
        HStack(spacing: 0) {
            tile(label: "Portfolio", value: total)
            Divider().frame(height: 40)
            tile(label: "Out of Range", value: "\(outOfRange)", color: .numericRed)
            Divider().frame(height: 40)
            tile(label: "Largest Dev", value: String(format: "%+.1f%%", largestDeviation), color: color(for: largestDeviation))
            Divider().frame(height: 40)
            tile(label: "Rebalance", value: rebalanceAmount)
        }
        .padding(8)
        .background(Capsule().fill(Color.white).shadow(radius: 1))
    }

    private func tile(label: String, value: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func color(for deviation: Double) -> Color {
        let absDev = abs(deviation)
        if absDev > 5 { return .numericRed }
        if absDev > 2 { return .numericAmber }
        return .numericGreen
    }
}

private struct AllocationTreeCard: View {
    @ObservedObject var viewModel: AllocationDashboardViewModel

    var body: some View {
        Card("Asset Classes") {
            Picker("", selection: .constant(0)) {
                Text("Percent").tag(0)
                Text("Value").tag(1)
            }
            .pickerStyle(.segmented)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.assets) { asset in
                        AssetRowView(asset: asset, level: 0)
                        ForEach(asset.children ?? []) { sub in
                            AssetRowView(asset: sub, level: 1)
                        }
                    }
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
                .frame(width: level == 0 ? 140 : 120, alignment: .leading)
            Spacer()
            Text(String(format: "%.1f%%", asset.actualPct))
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .frame(width: 60, alignment: .trailing)
            deviationBar
            Text(String(format: "%+.1f%%", asset.deviationPct))
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(level == 0 ? Color.gray.opacity(0.1) : Color.clear)
    }

    private var deviationBar: some View {
        let dev = asset.deviationPct
        let devColor: Color = {
            let a = abs(dev)
            if a > 5 { return .numericRed }
            if a > 2 { return .numericAmber }
            return .numericGreen
        }()
        return ZStack(alignment: .leading) {
            Capsule().fill(Color.quaternary)
            Capsule().fill(devColor).frame(width: CGFloat(abs(dev)) * 6)
        }
        .frame(width: 60, height: 6)
        .offset(x: dev >= 0 ? 30 : -30)
    }
}

private struct DeviationChartsCard: View {
    @ObservedObject var viewModel: AllocationDashboardViewModel

    var body: some View {
        Card("Deviation Bubble Chart") {
            Chart(viewModel.bubbles) {
                PointMark(
                    x: .value("Deviation", $0.deviation),
                    y: .value("Allocation", $0.actual),
                    size: .value("Allocation %", $0.actual),
                    series: .value("Asset", $0.name)
                )
                .symbol(by: .value("State", $0.categoryColor))
                .foregroundStyle($0.categoryColor)
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
        Card("Rebalancing Suggestions") {
            VStack(alignment: .leading) {
                ForEach(viewModel.actions.prefix(5)) { action in
                    HStack {
                        Text(action.label)
                        Spacer()
                        Text(action.amount)
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                    }
                }
                Button("Execute") {}
                    .disabled(true)
            }
        }
    }
}

struct AllocationDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        AllocationDashboardView().environmentObject(DatabaseManager())
    }
}
