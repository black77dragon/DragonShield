import SwiftUI
import Charts

/// Phase 1 Asset Allocation dashboard with live data but read-only actions.
struct AllocationDashboardView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel: TargetAllocationViewModel

    init() {
        _viewModel = StateObject(wrappedValue: TargetAllocationViewModel(dbManager: DatabaseManager(), portfolioId: 1))
    }

    private struct GridLayout {
        static let spacing: CGFloat = 24
        static let min: CGFloat = 320
        static let max: CGFloat = 480
    }

    // MARK: - Derived Metrics

    private var allAssets: [AllocationAsset] {
        viewModel.assets.flatMap { asset in
            [asset] + (asset.children ?? [])
        }
    }

    private var assetsOutOfRange: Int {
        allAssets.filter { abs($0.deviationPct) > 5 }.count
    }

    private var largestDeviation: Double {
        allAssets.map { abs($0.deviationPct) }.max() ?? 0
    }

    private var rebalancingAmount: Double {
        allAssets.map { abs($0.deviationChf) }.reduce(0, +)
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: GridLayout.min, maximum: GridLayout.max), spacing: GridLayout.spacing)], spacing: GridLayout.spacing) {
                header
                overviewTiles
                allocationTree
                chartsPanel
                actionsList
            }
            .padding()
        }
        .navigationTitle("Asset Allocation Targets")
    }

    private var header: some View {
        HStack {
            Spacer()
            Button("Import Targets") { /* placeholder */ }
            Button("Auto-Rebalance") {}
                .disabled(true)
                .foregroundColor(.secondary)
        }
    }

    private var overviewTiles: some View {
        HStack(spacing: 16) {
            overviewTile(title: "Portfolio Total", value: viewModel.actualChfTotal, color: .primary)
            overviewTile(title: "Assets Out of Range", value: Double(assetsOutOfRange), color: .red)
            overviewTile(title: "Largest Deviation", value: largestDeviation, color: .orange)
            overviewTile(title: "Rebalancing Amount", value: rebalancingAmount, color: .primary)
        }
    }

    private func overviewTile(title: String, value: Double, color: Color) -> some View {
        let display: String = {
            if title.contains("Total") || title.contains("Amount") {
                return viewModel.currencyFormatter.string(from: NSNumber(value: value)) ?? "-"
            } else {
                return String(format: "%.1f", value)
            }
        }()

        return VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(display)
                .font(.title3.bold())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.surface)
        .cornerRadius(8)
    }

    private var allocationTree: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Allocations")
                    .font(.headline)
                Spacer()
            }
            ForEach(viewModel.assets) { asset in
                VStack(alignment: .leading) {
                    HStack {
                        Text(asset.name)
                        Spacer()
                        Text(String(format: "%.1f%%", asset.actualPct))
                    }
                    if let children = asset.children {
                        ForEach(children) { sub in
                            HStack {
                                Text("\u{2022} " + sub.name)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(String(format: "%.1f%%", sub.actualPct))
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Theme.surface)
        .cornerRadius(8)
    }

    private var chartsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Deviation Bubble Chart")
                .font(.headline)
            DeviationBubbleChart(assets: viewModel.assets)
                .frame(height: 240)
        }
        .padding()
        .background(Theme.surface)
        .cornerRadius(8)
    }

    private var actionsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rebalancing Actions")
                .font(.headline)
            ForEach(suggestions.prefix(5), id: \.self) { s in
                HStack {
                    Text(s)
                    Spacer()
                    Button("Execute") {}
                        .disabled(true)
                }
            }
        }
        .padding()
        .background(Theme.surface)
        .cornerRadius(8)
    }

    private var suggestions: [String] {
        allAssets.sorted { abs($0.deviationChf) > abs($1.deviationChf) }
            .prefix(5)
            .map { asset in
                let action = asset.deviationChf > 0 ? "Buy" : "Sell"
                let amount = abs(asset.deviationChf)
                let name = asset.name
                let text = viewModel.currencyFormatter.string(from: NSNumber(value: amount)) ?? String(format: "%.0f", amount)
                return "\(action) \(name) \(text)"
            }
    }
}

struct DeviationBubbleChart: View {
    let assets: [AllocationAsset]
    @State private var selected: String?

    private func color(for deviation: Double, tolerance: Double) -> Color {
        let absDev = abs(deviation)
        if absDev <= tolerance { return .green }
        if absDev <= tolerance * 2 { return .orange }
        return .red
    }

    var body: some View {
        Chart(assets, id: \.id) { item in
            PointMark(
                x: .value("Deviation", item.deviationPct),
                y: .value("Allocation", item.actualPct)
            )
            .foregroundStyle(color(for: item.deviationPct, tolerance: 5))
            .symbolSize(item.actualPct * 5)
            .annotation(position: .overlay, alignment: .center) {
                if selected == item.id {
                    Circle().stroke(Color.blue, lineWidth: 2)
                        .frame(width: 20, height: 20)
                }
            }
            .accessibilityLabel("\(item.name), \(item.deviationPct, specifier: "%.1f")% deviation")
            .onTapGesture { selected = item.id }
            .onHover { hovering in
                if hovering { selected = item.id }
            }
        }
        .chartOverlay { _ in Color.clear }
        .accessibilityLabel("Deviation bubble chart")
    }
}

struct AllocationDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        AllocationDashboardView()
            .environmentObject(DatabaseManager())
    }
}
