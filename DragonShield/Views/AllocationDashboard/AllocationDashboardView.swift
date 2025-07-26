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

    private let targetWidth: CGFloat = 52
    private let actualWidth: CGFloat = 52
    private let trackWidth: CGFloat = 128
    private let deltaWidth: CGFloat = 40
    private let iconWidth:  CGFloat = 24
    private let gap: CGFloat = 10

    private var nameCol: CGFloat {
        max(width - (targetWidth + actualWidth + trackWidth + deltaWidth + iconWidth)
            - gap * 5, 160)
    }
    private var numCol: CGFloat { targetWidth } // same for target and actual
    private var barCol: CGFloat { trackWidth }

    var body: some View {
        Card {
            VStack(spacing: 0) {
                HeaderBar()
                CaptionRow(nameWidth: nameCol,
                           numWidth: numCol,
                           trackWidth: trackWidth,
                           deltaWidth: deltaWidth,
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
                     numWidth: numCol,
                     trackWidth: barCol,
                     deltaWidth: deltaWidth,
                     iconWidth: iconWidth,
                     gap: gap)
            if expanded[parent.id] == true, let children = parent.children {
                ForEach(children) { child in
                    AssetRow(node: child,
                             expanded: .constant(false),
                             nameWidth: nameCol,
                             numWidth: numCol,
                             trackWidth: barCol,
                             deltaWidth: deltaWidth,
                             iconWidth: iconWidth,
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
        let numWidth: CGFloat
        let trackWidth: CGFloat
        let deltaWidth: CGFloat
        let gap: CGFloat

        var body: some View {
            HStack(spacing: gap) {
                Spacer(minLength: nameWidth)
                Text("TARGET")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: numWidth, alignment: .trailing)
                Text("ACTUAL")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: numWidth, alignment: .trailing)
                Text("DEVIATION")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: trackWidth + gap + deltaWidth,
                           alignment: .center)
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
    let numWidth: CGFloat
    let trackWidth: CGFloat
    let deltaWidth: CGFloat
    let iconWidth: CGFloat
    let gap: CGFloat

    var body: some View {
        let tolPct = 5.0
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

            Text(node.name)
                .font(node.children != nil ? .body.bold() : .subheadline)
                .frame(width: nameWidth - 16, alignment: .leading)

            Text(formatPercent(node.targetPct))
                .frame(width: numWidth, alignment: .trailing)
                .font(node.children != nil ? .body.bold() : .subheadline)
            Text(formatPercent(node.actualPct))
                .frame(width: numWidth, alignment: .trailing)
                .font(node.children != nil ? .body.bold() : .subheadline)

            DeviationBar(dev: node.deviationPct / 100.0, trackWidth: trackWidth)
                .frame(width: trackWidth)

            Text(formatSigned(node.deviationPct))
                .frame(width: deltaWidth, alignment: .trailing)
                .foregroundStyle(colorFor(node.deviationPct / 100.0))

            Image(systemName: node.deviationPct > tolPct ? "plus" :
                                 node.deviationPct < -tolPct ? "minus" : "checkmark")
                .font(.caption2.weight(.bold))
                .foregroundColor(.white)
                .padding(4)
                .background(Circle().fill(iconColor(node.deviationPct / 100.0)))
                .frame(width: iconWidth)
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

    private func colorFor(_ dev: Double) -> Color {
        let tol = 0.05
        let mag = abs(dev)
        if mag <= tol { return .numberGreen }
        if mag <= tol * 2 { return .numberAmber }
        return .numberRed
    }

    private func iconColor(_ dev: Double) -> Color {
        let tol = 0.05
        if dev > tol { return .numberGreen }
        if dev < -tol { return .numberRed }
        return .gray
    }
}

struct DeviationBar: View {
    var dev: Double
    var trackWidth: CGFloat

    var body: some View {
        let half = trackWidth / 2
        let span = min(abs(dev), 1.0) * half
        let offset = dev < 0 ? span : -span

        ZStack {
            Capsule().fill(.quaternary)
                .frame(width: trackWidth, height: 6)
            Rectangle().fill(.black.opacity(0.6))
                .frame(width: 1, height: 8)
            Capsule().fill(colorFor(dev))
                .frame(width: span, height: 6)
                .offset(x: offset)
        }
        .frame(height: 8)
    }

    private func colorFor(_ dev: Double) -> Color {
        let tol = 0.05
        let mag = abs(dev)
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
