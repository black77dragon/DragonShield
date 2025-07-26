import SwiftUI
import Charts

struct AllocationDashboardView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = AllocationTargetsTableViewModel()
    @State private var selectedId: String? = nil

    private let gridCols = [GridItem(.adaptive(minimum: 320, maximum: 480), spacing: 24)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridCols, spacing: 24) {
                headerBar
                overviewTiles
                allocationTree
                chartsPanel
                actionsList
            }
            .padding(24)
        }
        .onAppear { viewModel.load(using: dbManager) }
        .navigationTitle("Asset Allocation Targets")
    }

    // MARK: - Sections
    private var headerBar: some View {
        HStack {
            Spacer()
            Button("Import Targets") { /* TODO */ }
            Button("Auto-Rebalance") {}
                .disabled(true)
        }
    }

    private var overviewTiles: some View {
        let metrics = computeMetrics()
        return HStack(spacing: 16) {
            OverviewTile(title: "Portfolio Total", value: formatChf(metrics.total), color: .secondary)
            OverviewTile(title: "Assets Out of Range", value: String(metrics.outOfRange), color: .red)
            OverviewTile(title: "Largest Deviation", value: String(format: "%.1f%%", metrics.largestDev), color: metrics.largestDev > 5 ? .orange : .secondary)
            OverviewTile(title: "Rebalancing Amount", value: formatChf(metrics.rebalance), color: .secondary)
        }
    }

    private var allocationTree: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Allocations (%)")
                Spacer()
                Text("±5%")
                    .font(.caption)
                    .padding(4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
            OutlineGroup(viewModel.assets, children: \.children) { asset in
                treeRow(asset)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor)))
    }

    private var chartsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            DeviationBubbleChart(assets: allAssets(), selected: $selectedId)
                .frame(height: 200)
            DualRingDonutChart(data: donutData())
                .frame(height: 220)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor)))
    }

    private var actionsList: some View {
        VStack(alignment: .leading) {
            Text("Top Rebalancing Actions")
                .font(.headline)
            ForEach(topActions(), id: \.id) { action in
                HStack {
                    Text(action.name)
                    Spacer()
                    Text(formatSignedChf(action.delta))
                }
                .font(.caption)
            }
            Button("Execute") {}
                .disabled(true)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor)))
    }

    // MARK: - Helpers
    private func treeRow(_ asset: AllocationAsset) -> some View {
        HStack {
            Text(asset.name)
                .fontWeight(asset.id == selectedId ? .bold : .regular)
            Spacer()
            Text(String(format: "%.1f%%", asset.actualPct))
            DeviationBar(value: asset.deviationPct)
        }
        .padding(.vertical, 2)
        .background(asset.id == selectedId ? Color.accentColor.opacity(0.2) : Color.clear)
        .onTapGesture { selectedId = asset.id }
    }

    private func computeMetrics() -> (total: Double, outOfRange: Int, largestDev: Double, rebalance: Double) {
        var out = 0
        var largest = 0.0
        var rebalance = 0.0
        var total = viewModel.actualChfTotal
        func scan(_ asset: AllocationAsset) {
            let dev = abs(asset.deviationPct)
            if dev > 5 { out += 1 }
            largest = max(largest, dev)
            rebalance += abs(asset.deviationChf)
            if let children = asset.children { for c in children { scan(c) } }
        }
        for a in viewModel.assets { scan(a) }
        return (total, out, largest, rebalance)
    }

    private func allAssets() -> [AllocationAsset] {
        var result: [AllocationAsset] = []
        func collect(_ asset: AllocationAsset) {
            result.append(asset)
            if let children = asset.children { children.forEach(collect) }
        }
        viewModel.assets.forEach(collect)
        return result
    }

    private func donutData() -> [AssetAllocation] {
        viewModel.assets.filter { $0.id.hasPrefix("class-") }.map {
            AssetAllocation(name: $0.name, targetPercent: $0.targetPct, actualPercent: $0.actualPct)
        }
    }

    private struct ActionItem: Identifiable { let id = UUID(); let name: String; let delta: Double }

    private func topActions() -> [ActionItem] {
        let sorted = allAssets().sorted { abs($0.deviationChf) > abs($1.deviationChf) }
        return sorted.prefix(5).map { ActionItem(name: $0.name, delta: $0.deviationChf) }
    }

    private func formatChf(_ value: Double) -> String {
        viewModel.currencyFormatter.string(from: NSNumber(value: value)) ?? "" }

    private func formatSignedChf(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return sign + (viewModel.currencyFormatter.string(from: NSNumber(value: abs(value))) ?? "")
    }
}

struct OverviewTile: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
    }
}

struct DeviationBar: View {
    let value: Double
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let pct = min(max((value + 5) / 10, 0), 1)
            Capsule()
                .fill(value.magnitude <= 5 ? Color.green : (value.magnitude <= 10 ? Color.orange : Color.red))
                .frame(width: width * pct, height: 8)
                .animation(.easeInOut(duration: 0.2), value: value)
        }
        .frame(width: 80, height: 8)
    }
}

struct DeviationBubbleChart: View {
    let assets: [AllocationAsset]
    @Binding var selected: String?

    var body: some View {
        Chart(assets) { asset in
            PointMark(
                x: .value("Deviation", asset.deviationPct),
                y: .value("Allocation", asset.actualPct),
                size: .value("Value", max(asset.actualPct, 1))
            )
            .foregroundStyle(color(for: asset))
            .symbolSize(80)
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(Color.clear).contentShape(Rectangle())
                    .onHover { inside in }
                    .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                        if let a = nearestAsset(at: value.location, proxy: proxy, size: geo.size) {
                            selected = a.id
                        }
                    })
            }
        }
    }

    private func color(for asset: AllocationAsset) -> Color {
        if abs(asset.deviationPct) <= 5 { return .green }
        if abs(asset.deviationPct) <= 10 { return .orange }
        return .red
    }

    private func nearestAsset(at location: CGPoint, proxy: ChartProxy, size: CGSize) -> AllocationAsset? {
        let x = proxy.value(atX: location.x, as: Double.self) ?? 0
        let y = proxy.value(atY: location.y, as: Double.self) ?? 0
        return assets.min(by: { hypot($0.deviationPct - x, $0.actualPct - y) < hypot($1.deviationPct - x, $1.actualPct - y) })
    }
}

#Preview {
    AllocationDashboardView()
        .environmentObject(DatabaseManager())
}
