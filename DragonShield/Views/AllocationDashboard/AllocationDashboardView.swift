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
                        AllocationTreeCard(width: usableWidth * 0.45, viewModel: viewModel)

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
    let width: CGFloat
    @ObservedObject var viewModel: AllocationDashboardViewModel
    @State private var displayMode: DisplayMode = .percent
    @State private var expanded: [String: Bool] = [:]

    // Final column layout based on 640pt reference width
    private let targetCol: CGFloat = 52
    private let actualCol: CGFloat = 52
    private let trackCol:  CGFloat = 128
    private let deltaCol:  CGFloat = 40
    private let gap:       CGFloat = 10

    private var nameCol: CGFloat {
        max(width - 16 - gap * 5 - targetCol - actualCol - trackCol - deltaCol, 160)
    }

    var body: some View {
        Card {
            VStack(spacing: 0) {
                HeaderBar()
                CaptionRow(nameWidth: nameCol,
                           targetWidth: targetCol,
                           actualWidth: actualCol,
                           trackWidth: trackCol,
                           deltaWidth: deltaCol,
                           gap: gap)
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

    @ViewBuilder
    private var rows: some View {
        ForEach(viewModel.assets) { parent in
            AssetRow(node: parent,
                     expanded: binding(for: parent.id),
                     nameWidth: nameCol,
                     targetWidth: targetCol,
                     actualWidth: actualCol,
                     trackWidth: trackCol,
                     deltaWidth: deltaCol,
                     gap: gap)
            if expanded[parent.id] == true, let children = parent.children {
                ForEach(children) { child in
                    AssetRow(node: child,
                             expanded: .constant(false),
                             nameWidth: nameCol,
                             targetWidth: targetCol,
                             actualWidth: actualCol,
                             trackWidth: trackCol,
                             deltaWidth: deltaCol,
                             gap: gap)
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

    struct CaptionRow: View {
        let nameWidth: CGFloat
        let targetWidth: CGFloat
        let actualWidth: CGFloat
        let trackWidth: CGFloat
        let deltaWidth: CGFloat
        let gap: CGFloat

        var body: some View {
            HStack(spacing: gap) {
                Spacer().frame(width: nameWidth + 16)
                Text("TARGET")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: targetWidth, alignment: .trailing)
                Text("ACTUAL")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: actualWidth, alignment: .trailing)
                Text("DEVIATION")
                    .font(.caption2.weight(.semibold))
                    .frame(width: trackWidth + gap + deltaWidth, alignment: .center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 4)
        }
    }
}

struct AssetRow: View {
    let node: AllocationDashboardViewModel.Asset
    @Binding var expanded: Bool
    let nameWidth: CGFloat
    let targetWidth: CGFloat
    let actualWidth: CGFloat
    let trackWidth: CGFloat
    let deltaWidth: CGFloat
    let gap: CGFloat

    var body: some View {
        HStack(spacing: gap) {
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

            HStack(spacing: 4) {
                Text(node.name)
                    .font(node.children != nil ? .body.bold() : .subheadline)

                Text("±\(Int(node.tolerancePercent))%")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color(.systemGray6)))
            }
            .frame(width: nameWidth - 16, alignment: .leading)

            Text(formatPercent(node.targetPct))
                .frame(width: targetWidth, alignment: .trailing)
                .font(node.children != nil ? .body.bold() : .subheadline)
            Text(formatPercent(node.actualPct))
                .frame(width: actualWidth, alignment: .trailing)
                .font(node.children != nil ? .body.bold() : .subheadline)
            DeviationBar(target: node.targetPct,
                         actual: node.actualPct,
                         trackWidth: trackWidth)
                .frame(width: trackWidth)

            Text(formatSigned(node.relativeDev * 100))
                .frame(width: deltaWidth, alignment: .trailing)
                .foregroundStyle(barColor(node.relativeDev * 100))

        }
        .padding(.vertical, node.children != nil ? 8 : 6)
        .background(node.children != nil ? Color.gray.opacity(0.07) : .clear)
        .accessibilityElement(children: .combine)
    }

    private func formatPercent(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func formatSigned(_ value: Double) -> String {
        String(format: "%+.1f", value)
    }

}

fileprivate func barColor(_ diffPercent: Double) -> Color {
    let mag = abs(diffPercent)
    if mag <= 10 { return .numberGreen }
    if mag <= 20 { return .numberAmber }
    return .numberRed
}

struct DeviationBar: View {
    let target: Double
    let actual: Double
    var trackWidth: CGFloat

    private var diffPercent: Double {
        guard target != 0 else { return 0 }
        return (actual - target) / target * 100
    }

    private var span: CGFloat {
        let mag = min(abs(diffPercent), 100)
        return trackWidth * CGFloat(mag) / 100 * 0.5
    }

    private var offset: CGFloat {
        if diffPercent < 0 { return span / 2 }
        if diffPercent > 0 { return -span / 2 }
        return 0
    }

    var body: some View {
        ZStack {
            Capsule().fill(.quaternary)
                .frame(width: trackWidth, height: 6)
            Rectangle().fill(Color.black.opacity(0.6))
                .frame(width: 1, height: 8)
            Capsule().fill(barColor(diffPercent))
                .frame(width: span, height: 6)
                .offset(x: offset)
        }
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
