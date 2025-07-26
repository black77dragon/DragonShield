import SwiftUI
import Charts

struct AllocationDashboardView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = AllocationDashboardViewModel()

    // MARK: - Column width constants
    private let leftWidth:  Double = 520
    private let rightWidth: Double = 400

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                OverviewBar(portfolioTotal: viewModel.portfolioTotalFormatted,
                            outOfRange: "\(viewModel.outOfRangeCount)",
                            largestDev: String(format: "%.1f%%", viewModel.largestDeviation),
                            rebalAmount: viewModel.rebalanceAmountFormatted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                HStack(alignment: .top, spacing: 32) {
                    AllocationTreeCard(viewModel: viewModel)
                        .frame(width: leftWidth)

                    VStack(spacing: 32) {
                        DeviationChartsCard(bubbles: viewModel.bubbles,
                                           highlighted: $viewModel.highlightedId)
                        RebalanceListCard(actions: viewModel.actions)
                    }
                    .frame(width: rightWidth)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .background(Color(NSColor.windowBackgroundColor))
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
    let portfolioTotal: String
    let outOfRange: String
    let largestDev: String
    let rebalAmount: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 0) {
            OverviewTile(value: portfolioTotal, label: "Portfolio Total")

            Divider().frame(width: 1, height: 40)

            OverviewTile(value: outOfRange,
                         label: "Assets Out of Range",
                         style: .alert)

            Divider().frame(width: 1, height: 40)

            OverviewTile(value: largestDev,
                         label: "Largest Deviation",
                         style: .warning)

            Divider().frame(width: 1, height: 40)

            OverviewTile(value: rebalAmount,
                         label: "Rebalancing Amount")
        }
        .padding(.vertical, 20)
        .background(
            Group {
                if scheme == .dark {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.tertiary, lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.quaternary, lineWidth: 1)
                        )
                }
            }
        )
    }
}

enum TileStyle { case neutral, alert, warning }

enum DisplayMode { case percent, chf }

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
        case .alert:    return .red
        case .warning:  return .orange
        case .neutral:  return .primary
        }
    }

    private var tileBackground: some View {
        Group {
            switch style {
            case .alert:
                LinearGradient(colors: [.red.opacity(0.08), .white],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
            case .warning:
                LinearGradient(colors: [.orange.opacity(0.08), .white],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
            case .neutral:
                Color.clear
            }
        }
    }
}

struct AllocationTreeCard: View {
    @ObservedObject var viewModel: AllocationDashboardViewModel
    @State private var displayMode: DisplayMode = .percent
    @State private var expanded: [String: Bool] = [:]

    var body: some View {
        Card {
            VStack(spacing: 0) {
                headerBar
                Divider()
                captionRow
                Divider()
                ScrollView { VStack(spacing: 0) { rows } }
            }
        }
        .onAppear { initializeExpanded() }
    }

    private var SegmentedPicker: some View {
        Picker("", selection: $displayMode) {
            Text("%").tag(DisplayMode.percent)
            Text("CHF").tag(DisplayMode.chf)
        }
        .pickerStyle(.segmented)
        .frame(width: 120)
    }

    @ViewBuilder
    private var rows: some View {
        ForEach(viewModel.assets) { parent in
            AssetRow(node: parent, expanded: binding(for: parent.id))
            if expanded[parent.id] == true, let children = parent.children {
                ForEach(children) { child in
                    AssetRow(node: child, expanded: .constant(false))
                }
            }
        }
    }

    private func binding(for id: String) -> Binding<Bool> {
        return Binding(get: { expanded[id] ?? false },
                       set: { expanded[id] = $0 })
    }

    private func initializeExpanded() {
        for asset in viewModel.assets {
            if expanded[asset.id] == nil { expanded[asset.id] = false }
        }
    }

    // MARK: - Subviews
    private var headerBar: some View {
        HStack(alignment: .top) {
            Text("Asset Classes")
                .font(.headline)
            Spacer()
            VStack(alignment: .leading, spacing: 4) {
                Text("Display mode")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                SegmentedPicker
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 4)
    }

    private var captionRow: some View {
        HStack {
            Spacer().frame(width: 150)
            Caption("TARGET")
            Caption("ACTUAL")
            Caption("DEVIATION")
            Spacer().frame(width: 36)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 4)
    }

    private func Caption(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: 80, alignment: .trailing)
    }
}

struct AssetRow: View {
    let node: AllocationDashboardViewModel.Asset
    @Binding var expanded: Bool
    private let barWidth: CGFloat = 72
    private let maxDev: Double = 100

    var body: some View {
        HStack(spacing: 0) {
            if node.children != nil {
                Button(action: { expanded.toggle() }) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .frame(width: 16)
                .keyboardShortcut(.space, modifiers: [])
            } else {
                Spacer().frame(width: 16)
            }

            Text(node.name)
                .font(node.children != nil ? .body.weight(.semibold) : .subheadline.weight(.regular))
                .padding(.leading, 4)

            Spacer(minLength: 16)

            HStack(spacing: 8) {
                Text(formatPercent(node.targetPct))
                    .font(node.children != nil ? .body.weight(.bold) : .subheadline)
                    .frame(width: 60, alignment: .trailing)

                Text(formatPercent(node.actualPct))
                    .font(node.children != nil ? .body.weight(.bold) : .subheadline)
                    .frame(width: 60, alignment: .trailing)

                deviationBar(node.deviationPct)
                    .frame(width: barWidth)
                    .padding(.horizontal, 4)

                Text(formatSignedPercent(node.deviationPct))
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 24)
        .background(node.children != nil ? Color.gray.opacity(0.07) : Color.white)
        .accessibilityElement(children: .combine)
    }

    private func deviationBar(_ dev: Double) -> some View {
        ZStack {
            Capsule().fill(.quaternary)
            Capsule().fill(colorFor(dev))
                .frame(width: min(barWidth / 2, abs(dev) * barWidth / maxDev))
                .offset(x: dev < 0 ? barWidth / 2 : -barWidth / 2)
        }
        .frame(width: barWidth, height: 6)
    }

    private func colorFor(_ dev: Double) -> Color {
        let magnitude = abs(dev)
        if magnitude <= 5 { return .numberGreen }
        if magnitude <= 10 { return .numberAmber }
        return .numberRed
    }

    private func formatPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }

    private func formatSignedPercent(_ value: Double) -> String {
        String(format: "%+.1f%%", value)
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
