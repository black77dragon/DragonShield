import SwiftUI
import Charts

struct AllocationDashboardView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = AllocationDashboardViewModel()

    private let columns = [GridItem(.adaptive(minimum: 320, maximum: 480), spacing: 24)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                OverviewBar(total: viewModel.portfolioTotalFormatted,
                            outOfRange: viewModel.outOfRangeCount,
                            largestDeviation: viewModel.largestDeviation,
                            rebalanceAmount: viewModel.rebalanceAmountFormatted)
                    .gridCellColumns(columns.count)
                AllocationTreeCard(viewModel: viewModel)
                DeviationChartsCard(bubbles: viewModel.bubbles,
                                   highlighted: $viewModel.highlightedId)
                RebalanceListCard(actions: viewModel.actions)
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

// MARK: - Components

struct OverviewBar: View {
    let total: String
    let outOfRange: Int
    let largestDeviation: Double
    let rebalanceAmount: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            OverviewTile(value: total, label: "Portfolio Total")
            Divider().frame(width: 1, height: 40)
            OverviewTile(value: "\(outOfRange)", label: "Assets Out of Range", style: .alert)
            Divider().frame(width: 1, height: 40)
            OverviewTile(value: String(format: "%.1f%%", largestDeviation), label: "Largest Deviation", style: .warning)
            Divider().frame(width: 1, height: 40)
            OverviewTile(value: rebalanceAmount, label: "Rebalancing Amount")
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? .ultraThinMaterial : .white)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(colorScheme == .dark ? .tertiary : .quaternary, lineWidth: 1)
                )
        )
    }
}

enum TileStyle { case neutral, alert, warning }

struct OverviewTile: View {
    var value: String
    var label: String
    var style: TileStyle = .neutral

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(valueColor)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(tileBackground)
    }

    private var valueColor: Color {
        switch style {
        case .alert: return .red
        case .warning: return .orange
        case .neutral: return .primary
        }
    }

    @ViewBuilder
    private var tileBackground: some View {
        switch style {
        case .alert:
            LinearGradient(colors: [.red.opacity(0.08), .white], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .warning:
            LinearGradient(colors: [.orange.opacity(0.08), .white], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .neutral:
            Color.clear
        }
    }
}

struct AllocationTreeCard: View {
    @ObservedObject var viewModel: AllocationDashboardViewModel

    var body: some View {
        Card("Asset Classes") {
            Picker("Display", selection: .constant(0)) {
                Text("%").tag(0)
                Text("CHF").tag(1)
            }
            .pickerStyle(.segmented)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(viewModel.assets) { asset in
                        AssetRowView(asset: asset, level: 0, highlighted: viewModel.highlightedId == asset.id)
                        if let children = asset.children {
                            ForEach(children) { child in
                                AssetRowView(asset: child, level: 1, highlighted: viewModel.highlightedId == child.id)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct AssetRowView: View {
    let asset: AllocationDashboardViewModel.Asset
    let level: Int
    let highlighted: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(asset.name)
                .frame(width: level == 0 ? 140 : 120, alignment: .leading)
            Spacer()
            Text(String(format: "%.1f%%", asset.targetPct))
                .frame(width: 50, alignment: .trailing)
                .font(.system(.footnote, design: .monospaced))
            Text(String(format: "%.1f%%", asset.actualPct))
                .frame(width: 50, alignment: .trailing)
                .font(.system(.footnote, design: .monospaced))
            deviationBar
                .frame(width: 60)
            Text(String(format: "%+.1f%%", asset.deviationPct))
                .frame(width: 50, alignment: .trailing)
                .font(.system(.footnote, design: .monospaced))
        }
        .padding(.vertical, 4)
        .background(highlighted ? Color.blue.opacity(0.1) : (level == 0 ? Color.fieldGray.opacity(0.4) : Color.clear))
        .overlay(alignment: .leading) {
            if highlighted {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 3)
            }
        }
    }

    private var deviationBar: some View {
        let dev = asset.deviationPct
        let devColor = dev > 0 ? Color.numberRed : Color.numberGreen
        return ZStack(alignment: .leading) {
            Capsule().fill(Color.gray.opacity(0.25))
            Capsule().fill(devColor).frame(width: abs(dev) * 60)
        }
        .frame(height: 6)
        .offset(x: dev >= 0 ? 30 : -30)
    }
}

struct DeviationChartsCard: View {
    let bubbles: [AllocationDashboardViewModel.Bubble]
    @Binding var highlighted: String?

    var body: some View {
        Card("Deviation Bubble Chart") {
            Chart(bubbles) { bubble in
                PointMark(
                    x: .value("Deviation", bubble.deviation),
                    y: .value("Allocation", bubble.allocation)
                )
                .symbolSize(by: .value("Allocation %", bubble.allocation))
                .foregroundStyle(bubble.color)
            }
            .chartXScale(domain: -25...25)
            .chartYScale(domain: 0...40)
            .frame(height: 240)
        }
    }
}

struct RebalanceListCard: View {
    let actions: [AllocationDashboardViewModel.Action]

    var body: some View {
        Card("Top Rebalancing Actions") {
            ForEach(actions.prefix(5)) { action in
                HStack {
                    Text(action.label)
                    Spacer()
                    Text(action.amount)
                        .font(.system(.body, design: .monospaced))
                }
            }
            Button("Execute") {}
                .disabled(true)
        }
    }
}

struct AllocationDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        AllocationDashboardView().environmentObject(DatabaseManager())
    }
}
