import SwiftUI
import Charts

struct AllocationDashboardView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = AllocationDashboardViewModel()

    var body: some View {
        GeometryReader { geo in
            let sidePad: CGFloat = 32
            let usableWidth = geo.size.width - sidePad * 2

            ScrollView {
                VStack(spacing: 32) {
                    OverviewBar(portfolioTotal: viewModel.portfolioTotalFormatted,
                                outOfRange: "\(viewModel.outOfRangeCount)",
                                largestDev: String(format: "%.1f%%", viewModel.largestDeviation),
                                rebalAmount: viewModel.rebalanceAmountFormatted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                    HStack(alignment: .top, spacing: 32) {
                        AllocationTreeCard(viewModel: viewModel,
                                           width: usableWidth * 0.45)
                        VStack(spacing: 32) {
                            DeviationChartsCard(bubbles: viewModel.bubbles,
                                               highlighted: $viewModel.highlightedId)
                            RebalanceListCard(actions: viewModel.actions)
                        }
                        .frame(width: usableWidth * 0.55)
                    }
                }
                .padding(.horizontal, sidePad)
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
    let width: CGFloat
    @State private var displayMode: DisplayMode = .percent
    @State private var expanded: [String: Bool] = [:]

    // column distribution ratios
    private var nameCol: CGFloat { width * 0.40 }
    private var numCol : CGFloat { width * 0.12 }
    private var barCol : CGFloat { width * 0.24 }
    private var pad    : CGFloat { width * 0.02 }

    var body: some View {
        Card {
            VStack(spacing: 0) {
                HeaderBar()
                CaptionRow(numWidth: numCol, barWidth: barCol)
                Divider()
                ScrollView { VStack(spacing: 0) { rows } }
            }
        }
        .frame(width: width)
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

    private func CaptionRow(numWidth: CGFloat, barWidth: CGFloat) -> some View {
        HStack(spacing: pad) {
            Spacer().frame(width: nameCol)
            Caption("TARGET", width: numWidth)
            Caption("ACTUAL", width: numWidth)
            Caption("DEVIATION", width: barWidth)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private func Caption(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(width: width, alignment: .trailing)
    }

    @ViewBuilder
    private var rows: some View {
        ForEach(viewModel.assets) { parent in
            AssetRow(node: parent,
                     expanded: binding(for: parent.id),
                     nameCol: nameCol,
                     numCol: numCol,
                     barCol: barCol,
                     pad: pad)
            if expanded[parent.id] == true, let children = parent.children {
                ForEach(children) { child in
                    AssetRow(node: child,
                             expanded: .constant(false),
                             nameCol: nameCol,
                             numCol: numCol,
                             barCol: barCol,
                             pad: pad)
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
    let nameCol: CGFloat
    let numCol: CGFloat
    let barCol: CGFloat
    let pad: CGFloat

    var body: some View {
        HStack(spacing: pad) {
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
                .frame(width: nameCol, alignment: .leading)

            Text(formatPercent(node.targetPct))
                .frame(width: numCol, alignment: .trailing)
                .font(node.children != nil ? .body.weight(.bold) : .subheadline)
            Text(formatPercent(node.actualPct))
                .frame(width: numCol, alignment: .trailing)
                .font(node.children != nil ? .body.weight(.bold) : .subheadline)

            DeviationBar(dev: node.deviationPct, trackWidth: barCol)
                .frame(width: barCol)

            Text(formatSigned(node.deviationPct))
                .frame(width: 36, alignment: .trailing)
                .font(node.children != nil ? .body.weight(.bold) : .subheadline)

            Spacer()
        }
        .padding(.vertical, node.children != nil ? 8 : 6)
        .background(node.children != nil ? Color.gray.opacity(0.07) : .clear)
        .accessibilityElement(children: .combine)
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

struct DeviationBar: View {
    var dev: Double          // -1...+1 (-100%...+100%)
    var trackWidth: CGFloat  // supplied by parent

    var body: some View {
        let half = trackWidth / 2
        let span = min(abs(dev), 1.0) * half
        let offset = dev < 0 ? span : -span

        return ZStack {
            Capsule().fill(.quaternary)
            Capsule().fill(colorFor(dev))
                .frame(width: span)
                .offset(x: offset)
        }
        .frame(height: 6)
    }

    private func colorFor(_ dev: Double) -> Color {
        let tol = 5.0
        let mag = abs(dev * 100)
        if mag <= tol { return .numberGreen }
        if mag <= tol * 2 { return .numberAmber }
        return .numberRed
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
