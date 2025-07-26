import SwiftUI
import Charts

struct AllocationDashboardView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = AllocationDashboardViewModel()

    private let columns = [GridItem(.adaptive(minimum: 320, maximum: 480), spacing: 24)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                OverviewBar(viewModel: viewModel)
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

private struct OverviewBar: View {
    @ObservedObject var viewModel: AllocationDashboardViewModel

    var body: some View {
        HStack(spacing: 24) {
            tile(label: "Portfolio Total", value: viewModel.portfolioTotalFormatted)
            Divider().frame(height: 40)
            tile(label: "Assets Out of Range",
                 value: "\(viewModel.outOfRangeCount)",
                 background: .linearGradient([Color.allocationRed.opacity(0.1), .white], startPoint: .topLeading, endPoint: .bottomTrailing),
                 color: .allocationRed)
            Divider().frame(height: 40)
            tile(label: "Largest Deviation",
                 value: String(format: "%.1f%%", viewModel.largestDeviation),
                 background: .linearGradient([Color.allocationAmber.opacity(0.1), .white], startPoint: .topLeading, endPoint: .bottomTrailing),
                 color: .allocationAmber)
            Divider().frame(height: 40)
            tile(label: "Rebalance Amount", value: viewModel.rebalanceAmountFormatted)
        }
        .padding(12)
        .background(
            Capsule()
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        )
    }

    private func tile(label: String, value: String, background: some ShapeStyle = Color.white, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

private struct AllocationTreeCard: View {
    @ObservedObject var viewModel: AllocationDashboardViewModel

    var body: some View {
        Card("Asset Classes") {
            HStack {
                Text("Tolerance")
                    .font(.caption)
                Text("±5%")
                    .font(.caption2)
                    .padding(4)
                    .background(Color.gray.opacity(0.15))
                    .clipShape(Capsule())
                Spacer()
            }
            ScrollView {
                OutlineGroup(viewModel.assets, children: \.children) { asset in
                    AssetRowView(asset: asset, level: asset.id.hasPrefix("class-") ? 0 : 1)
                }
            }
        }
    }
}

private struct AssetRowView: View {
    let asset: AllocationDashboardViewModel.Asset
    let level: Int
    @State private var hovering = false

    var devColor: Color {
        let pct = abs(asset.deviationPct)
        if pct > 10 { return .allocationRed }
        if pct > 5 { return .allocationAmber }
        return .allocationGreen
    }

    var body: some View {
        HStack {
            Text(asset.name)
                .frame(width: 120, alignment: .leading)
            Spacer()
            Text(String(format: "%.1f%%", asset.targetPct))
                .frame(width: 60, alignment: .trailing)
                .font(.system(.body, design: .monospaced).weight(.semibold))
            Text(String(format: "%.1f%%", asset.actualPct))
                .frame(width: 60, alignment: .trailing)
                .font(.system(.body, design: .monospaced).weight(.semibold))
            DeviationBar(dev: asset.deviationPct, color: devColor)
            Text(String(format: "%+.1f%%", asset.deviationPct))
                .frame(width: 50, alignment: .trailing)
                .font(.system(.body, design: .monospaced).weight(.semibold))
        }
        .padding(.vertical, 4)
        .background(level == 0 ? Color.beige : Color.clear)
        .background(hovering ? Color.blue.opacity(0.1) : Color.clear)
        .overlay(alignment: .leading) {
            if hovering { Rectangle().fill(Theme.primaryAccent).frame(width: 3) }
        }
        .onHover { hovering = $0 }
    }
}

private struct DeviationBar: View {
    let dev: Double
    let color: Color

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.quaternary).frame(width: 60)
            Capsule().fill(color).frame(width: abs(dev) * 60)
        }
        .frame(height: 6)
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
        Card("Rebalancing Suggestions") {
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

struct AllocationDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        AllocationDashboardView().environmentObject(DatabaseManager())
    }
}
