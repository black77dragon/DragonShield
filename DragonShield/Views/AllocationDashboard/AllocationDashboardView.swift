import SwiftUI
import Charts

struct AllocationDashboardView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = AllocationDashboardViewModel()

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 32) {
                    OverviewBar(portfolioTotal: viewModel.portfolioTotalFormatted,
                                outOfRange: "\(viewModel.outOfRangeCount)",
                                largestDev: String(format: "%.1f%%", viewModel.largestDeviation),
                                rebalAmount: viewModel.rebalanceAmountFormatted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                    HStack(alignment: .top, spacing: 24) {
                        AllocationTreeCard(viewModel: viewModel)
                            .frame(minWidth: 340)
                            .layoutPriority(1)

                        VStack(spacing: 24) {
                            DeviationChartsCard(bubbles: viewModel.bubbles,
                                               highlighted: $viewModel.highlightedId)
                            RebalanceListCard(actions: viewModel.actions)
                        }
                        .frame(minWidth: 300)
                    }
                }
                .padding(.horizontal, 24)
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

enum DisplayMode: String { case percent, chf }

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
    @State private var displayMode: DisplayMode = Self.loadMode()
    @State private var expanded: [String: Bool] = [:]
    private let gap: CGFloat = 8

    var body: some View {
        Card {
            GeometryReader { geo in
                let nameW = geo.size.width * 0.36
                let targetW = geo.size.width * 0.18
                let actualW = geo.size.width * 0.18
                let devW    = geo.size.width * 0.28

                VStack(spacing: 0) {
                    HeaderBar()
                    CaptionRow(nameWidth: nameW,
                               targetWidth: targetW,
                               actualWidth: actualW,
                               deviationWidth: devW,
                               gap: gap)
                    Divider()
                    ScrollView { VStack(spacing: 0) { rows(nameW,targetW,actualW,devW) } }
                }
            }
        }
        .onAppear { initializeExpanded() }
        .onChange(of: displayMode) { _, _ in saveMode() }
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
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func rows(_ nameW: CGFloat,
                      _ targetW: CGFloat,
                      _ actualW: CGFloat,
                      _ devW: CGFloat) -> some View {
        ForEach(viewModel.assets) { parent in
            AssetRow(node: parent,
                     mode: displayMode,
                     expanded: binding(for: parent.id),
                     nameWidth: nameW,
                     targetWidth: targetW,
                     actualWidth: actualW,
                     deviationWidth: devW)
            if expanded[parent.id] == true, let children = parent.children {
                ForEach(children) { child in
                    AssetRow(node: child,
                             mode: displayMode,
                             expanded: .constant(false),
                             nameWidth: nameW,
                             targetWidth: targetW,
                             actualWidth: actualW,
                             deviationWidth: devW)
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

    private static let modeKey = "AllocationDisplayMode"
    private static func loadMode() -> DisplayMode {
        if let raw = UserDefaults.standard.string(forKey: modeKey),
           let mode = DisplayMode(rawValue: raw) {
            return mode
        }
        return .percent
    }
    private func saveMode() {
        UserDefaults.standard.set(displayMode.rawValue, forKey: Self.modeKey)
    }

    struct CaptionRow: View {
        let nameWidth: CGFloat
        let targetWidth: CGFloat
        let actualWidth: CGFloat
        let deviationWidth: CGFloat
        let gap: CGFloat

        var body: some View {
            HStack(spacing: gap) {
                Spacer().frame(width: nameWidth + 16)
                Text("TARGET")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: targetWidth, alignment: .trailing)
                    .lineLimit(1)
                Text("ACTUAL")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: actualWidth, alignment: .trailing)
                    .lineLimit(1)
                Text("DEVIATION")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: deviationWidth, alignment: .center)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .overlay(alignment: .bottom) {
                Divider()
                    .background(Color.systemGray4)
            }
        }
    }
}

struct AssetRow: View {
    let node: AllocationDashboardViewModel.Asset
    let mode: DisplayMode
    @Binding var expanded: Bool
    let nameWidth: CGFloat
    let targetWidth: CGFloat
    let actualWidth: CGFloat
    let deviationWidth: CGFloat
    private let gap: CGFloat = 8

    private var target: Double {
        mode == .percent ? node.targetPct : node.targetChf
    }

    private var actual: Double {
        mode == .percent ? node.actualPct : node.actualChf
    }

    private var deviation: Double { actual - target }

    private var relativeDeviation: Double {
        guard target != 0 else { return 0 }
        return (actual - target) / target
    }

    var body: some View {
        let diffPct = relativeDeviation * 100
        let track = deviationWidth - 24
        let span = track * CGFloat(min(abs(diffPct), 100)) / 100 * 0.5
        let labelInside = span >= track * 0.25

        HStack(spacing: gap) {
            if node.children != nil {
                Button(action: { expanded.toggle() }) {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(expanded ? 90 : 0))
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
                    .lineLimit(1)

                Text("±\(Int(node.tolerancePercent))%")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.systemGray5))
            }
            .frame(width: nameWidth - 16, alignment: .leading)

            Text(formatValue(target))
                .frame(width: targetWidth, alignment: .trailing)
                .font(node.children != nil ? .body.bold() : .subheadline)
                .lineLimit(1)
            Text(formatValue(actual))
                .frame(width: actualWidth, alignment: .trailing)
                .font(node.children != nil ? .body.bold() : .subheadline)
                .lineLimit(1)

            HStack(spacing: labelInside ? 0 : 4) {
                ZStack(alignment: diffPct >= 0 ? .trailing : .leading) {
                    DeviationBar(target: target,
                                 actual: actual,
                                 trackWidth: deviationWidth)
                    if labelInside {
                        Text(formatDeviation(deviation))
                            .font(.caption2)
                            .foregroundStyle(barColor(diffPct))
                            .padding(.horizontal, 2)
                            .lineLimit(1)
                    }
                }
                if !labelInside {
                    Text(formatDeviation(deviation))
                        .font(.caption2)
                        .foregroundStyle(barColor(diffPct))
                        .frame(width: 40, alignment: .trailing)
                        .lineLimit(1)
                } else {
                    Spacer().frame(width: 40)
                }
            }
            .frame(width: deviationWidth, alignment: .trailing)

        }
        .padding(.vertical, node.children != nil ? 6 : 4)
        .padding(.horizontal, 16)
        .background(node.children != nil ? Color.systemGray6 : .clear)
        .accessibilityElement(children: .combine)
    }

    private static let percentFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        return f
    }()

    private static let chfFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        f.groupingSeparator = "'"
        f.usesGroupingSeparator = true
        return f
    }()

    private func formatPercent(_ value: Double) -> String {
        Self.percentFormatter.string(from: NSNumber(value: value)) ?? ""
    }

    private func formatChf(_ value: Double) -> String {
        Self.chfFormatter.string(from: NSNumber(value: value)) ?? ""
    }

    private func short(_ value: Double) -> String {
        let absV = abs(value)
        if absV >= 1_000_000 {
            return String(format: "%.1f M", value / 1_000_000)
        } else if absV >= 1_000 {
            return String(format: "%.0f k", value / 1_000)
        }
        return formatChf(value)
    }

    private func formatSignedPercent(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return sign + (Self.percentFormatter.string(from: NSNumber(value: abs(value))) ?? "") + " %"
    }

    private func formatSignedChf(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return sign + (Self.chfFormatter.string(from: NSNumber(value: abs(value))) ?? "")
    }

    private func formatValue(_ value: Double) -> String {
        mode == .percent ? formatPercent(value) : short(value)
    }

    private func formatDeviation(_ value: Double) -> String {
        if mode == .percent {
            return formatSignedPercent(value)
        } else {
            let sign = value >= 0 ? "+" : "-"
            return sign + short(abs(value))
        }
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

    private var track: CGFloat { trackWidth - 24 }

    private var span: CGFloat {
        let mag = min(abs(diffPercent), 100)
        return track * CGFloat(mag) / 100 * 0.5
    }

    private var offset: CGFloat {
        if diffPercent < 0 { return span / 2 }
        if diffPercent > 0 { return -span / 2 }
        return 0
    }

    var body: some View {
        ZStack {
            Capsule().fill(Color.systemGray5)
                .frame(height: 6)
                .padding(.horizontal, 12)
            Rectangle().fill(Color.black)
                .frame(width: 1, height: 8)
            Capsule().fill(barColor(diffPercent))
                .frame(width: span, height: 6)
                .offset(x: offset)
                .padding(.horizontal, 12)
        }
        .frame(width: trackWidth)
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
