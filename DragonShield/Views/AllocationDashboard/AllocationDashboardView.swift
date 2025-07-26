import SwiftUI
import Charts

struct AllocationDashboardView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = AllocationDashboardViewModel()

    private let gridColumns = [GridItem(.adaptive(minimum: 320, maximum: 480), spacing: 24)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 24) {
                overviewSection
                treeSection
                chartsSection
                actionsSection
            }
            .padding(24)
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

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                overviewTile(title: "Portfolio Total", value: viewModel.portfolioTotalFormatted, color: .primary)
                overviewTile(title: "Assets Out of Range", value: "\(viewModel.outOfRangeCount)", color: .red)
            }
            HStack {
                overviewTile(title: "Largest Deviation", value: String(format: "%.1f%%", viewModel.largestDeviation), color: .orange)
                overviewTile(title: "Rebalancing Amount", value: viewModel.rebalanceAmountFormatted, color: .primary)
            }
        }
    }

    private func overviewTile(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption)
            Text(value).font(.title3.bold()).foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.fieldGray)
        .cornerRadius(8)
    }

    private var treeSection: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Allocations (%)").font(.headline)
                Spacer()
                Text("Tolerance ±5%")
                    .font(.caption)
                    .padding(4)
                    .background(Color.softBlue)
                    .cornerRadius(4)
            }
            OutlineGroup(viewModel.assets, children: \.children) { asset in
                allocationRow(asset)
            }
        }
    }

    private func allocationRow(_ asset: AllocationDashboardViewModel.Asset) -> some View {
        HStack {
            Text(asset.name).frame(width: 120, alignment: .leading)
            Spacer()
            Text(String(format: "%.1f%%", asset.targetPct)).frame(width: 60, alignment: .trailing)
            Text(String(format: "%.1f%%", asset.actualPct)).frame(width: 60, alignment: .trailing)
            deviationBar(for: asset).frame(width: 80, height: 8)
            Text(String(format: "%+.1f%%", asset.deviationPct)).frame(width: 50, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .background(viewModel.highlightedId == asset.id ? Color.softBlue.opacity(0.3) : Color.clear)
        .onTapGesture { viewModel.highlightedId = asset.id }
    }

    private func deviationBar(for asset: AllocationDashboardViewModel.Asset) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let pct = abs(asset.deviationPct)
            let color: Color = pct > 10 ? .red : (pct > 5 ? .orange : .green)
            HStack(spacing: 0) {
                Spacer()
                Rectangle().fill(color).frame(width: width * CGFloat(min(pct/10,1)))
            }
        }
    }

    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Deviation Bubble Chart").font(.headline)
            Chart(viewModel.bubbles) { bubble in
                PointMark(x: .value("Deviation", bubble.deviation), y: .value("Allocation", bubble.allocation))
                    .foregroundStyle(bubble.color)
                    .symbolSize(bubble.size)
            }
            .frame(height: 240)
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top Rebalancing Actions").font(.headline)
            ForEach(viewModel.actions.prefix(5)) { action in
                HStack {
                    Text(action.label)
                    Spacer()
                    Text(action.amount)
                }
            }
            Button("Execute") {}.disabled(true)
        }
    }
}

struct AllocationDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        AllocationDashboardView().environmentObject(DatabaseManager())
    }
}
