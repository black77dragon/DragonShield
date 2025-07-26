import SwiftUI
import Charts

struct AllocationDashboardView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = AllocationDashboardViewModel()

    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let leftWidth = max(540, totalWidth * 0.55)
            let rightWidth = totalWidth - leftWidth - 32

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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                HeaderBar()
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

    private func HeaderBar() -> some View {
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
}

struct AssetRow: View {
    let node: AllocationDashboardViewModel.Asset
    @Binding var expanded: Bool

    private let columnWidth: CGFloat = 48
    private let trackWidth: CGFloat = 96
    private let maxDev: Double = 1.0

    var body: some View {
        HStack(spacing: 6) {
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
                .frame(minWidth: 140, alignment: .leading)

            Text(formatPercent(node.targetPct))
                .frame(width: columnWidth, alignment: .trailing)
                .font(node.children != nil ? .body.weight(.bold) : .subheadline)
            Text(formatPercent(node.actualPct))
                .frame(width: columnWidth, alignment: .trailing)
                .font(node.children != nil ? .body.weight(.bold) : .subheadline)

            deviationBar(node.deviationPct)
                .frame(width: trackWidth)

            Text(formatSigned(node.deviationPct))
                .frame(width: 36, alignment: .trailing)
                .font(node.children != nil ? .body.weight(.bold) : .subheadline)

            Spacer()
        }
        .padding(.vertical, node.children != nil ? 8 : 6)
        .padding(.leading, 16)
        .background(node.children != nil ? Color.gray.opacity(0.07) : Color.white)
        .accessibilityElement(children: .combine)
    }

    private func deviationBar(_ dev: Double) -> some View {
        let maxSpan = trackWidth / 2
        let span = CGFloat(min(abs(dev), maxDev)) * maxSpan
        let offset = dev < 0 ? span : -span

        return ZStack {
            Capsule().fill(.quaternary)
            Capsule().fill(colorFor(dev))
                .frame(width: span)
                .offset(x: offset)
        }
        .frame(width: trackWidth, height: 6)
    }

    private func colorFor(_ dev: Double) -> Color {
        let tol = 5.0
        let mag = abs(dev)
        if mag <= tol { return .numberGreen }
        if mag <= tol * 2 { return .numberAmber }
        return .numberRed
    }

    private func formatPercent(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func formatSigned(_ value: Double) -> String {
        String(format: "%+.1f", value)
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
