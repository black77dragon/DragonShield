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
    let width: CGFloat
    @ObservedObject var viewModel: AllocationDashboardViewModel
    @State private var displayMode: DisplayMode = Self.loadMode()
    @State private var expanded: [String: Bool] = [:]

    // Column layout ratios
    private let gap: CGFloat = 8

    private var nameCol: CGFloat { max(width * 0.36, 160) }
    private var targetCol: CGFloat { width * 0.18 }
    private var actualCol: CGFloat { width * 0.18 }
    private var deviationCol: CGFloat { width * 0.28 }

    var body: some View {
        Card {
            VStack(spacing: 0) {
                HeaderBar()
                CaptionRow(nameWidth: nameCol,
                           targetWidth: targetCol,
                           actualWidth: actualCol,
                           deviationWidth: deviationCol,
                           gap: gap)
                Divider()
                ScrollView { VStack(spacing: 0) { rows } }
            }
        }
        .frame(width: width)
        .onAppear { initializeExpanded() }
        .onChange(of: displayMode) { _ in saveMode() }
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
                     mode: displayMode,
                     expanded: binding(for: parent.id),
                     nameWidth: nameCol,
                     targetWidth: targetCol,
                     actualWidth: actualCol,
                     deviationWidth: deviationCol,
                     gap: gap)
            if expanded[parent.id] == true, let children = parent.children {
                ForEach(children) { child in
                    AssetRow(node: child,
                             mode: displayMode,
                             expanded: .constant(false),
                             nameWidth: nameCol,
                             targetWidth: targetCol,
                             actualWidth: actualCol,
                             deviationWidth: deviationCol,
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
                Text("ACTUAL")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: actualWidth, alignment: .trailing)
                Text("DEVIATION")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: deviationWidth, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
            .overlay(Rectangle().fill(Color(.systemGray4)).frame(height: 1), alignment: .bottom)
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
    let gap: CGFloat

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

    private var diffPercent: Double { relativeDeviation * 100 }

    var body: some View {
        HStack(spacing: gap) {
            if node.children != nil {
                Button(action: { expanded.toggle() }) {
                    Image(systemName: "chevron.right")
                        .rotationEffect(expanded ? .degrees(90) : .zero)
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .frame(width: 16)
                .keyboardShortcut(.space, modifiers: [])
            } else {
                Spacer().frame(width: 16)
            }

            NameCell(node: node)
                .frame(width: nameWidth - 16, alignment: .leading)
                .padding(.leading, node.children == nil ? 12 : 0)

            Text(formatValue(target))
                .frame(width: targetWidth, alignment: .trailing)
                .font(node.children != nil ? .body.bold() : .subheadline)
                .lineLimit(1)
            Text(formatValue(actual))
                .frame(width: actualWidth, alignment: .trailing)
                .font(node.children != nil ? .body.bold() : .subheadline)
                .lineLimit(1)
            DeviationBar(diffPercent: diffPercent,
                         label: formatDeviation(deviation))
                .frame(width: deviationWidth, alignment: .trailing)
        }
        .frame(height: node.children != nil ? 28 : 24)
        .padding(.vertical, node.children != nil ? 6 : 4)
        .padding(.horizontal, 16)
        .background(node.children != nil ? Color(.systemGray6) : .clear)
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

    private func formatSignedPercent(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return sign + (Self.percentFormatter.string(from: NSNumber(value: abs(value))) ?? "") + " %"
    }

    private func formatSignedChf(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return sign + (Self.chfFormatter.string(from: NSNumber(value: abs(value))) ?? "")
    }

    private func formatValue(_ value: Double) -> String {
        mode == .percent ? formatPercent(value) : formatChf(value)
    }

    private func formatDeviation(_ value: Double) -> String {
        mode == .percent ? formatSignedPercent(value) : formatSignedChf(value)
    }

}

fileprivate func barColor(_ diffPercent: Double) -> Color {
    let mag = abs(diffPercent)
    if mag <= 10 { return .numberGreen }
    if mag <= 20 { return .numberAmber }
    return .numberRed
}

struct DeviationBar: View {
    let diffPercent: Double
    let label: String

    var body: some View {
        GeometryReader { geo in
            let track = geo.size.width - 12
            let span = track / 2 * CGFloat(min(abs(diffPercent), 100)) / 100
            let sign: CGFloat = diffPercent >= 0 ? 1 : -1
            let color = barColor(diffPercent)
            let inside = span >= track * 0.25
            let textOffset = sign * (span / 2 + (inside ? -4 : 4))

            ZStack {
                Capsule().fill(Color(.systemGray5))
                    .frame(width: track, height: 6)
                Rectangle().fill(Color.black)
                    .frame(width: 1, height: 8)
                Capsule().fill(color)
                    .frame(width: span, height: 6)
                    .offset(x: sign * span / 2)
                Text(label)
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(color)
                    .offset(x: textOffset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct NameCell: View {
    let node: AllocationDashboardViewModel.Asset

    var body: some View {
        HStack(spacing: 4) {
            Text(node.name)
                .font(node.children != nil ? .body.bold() : .subheadline)
                .lineLimit(1)
            Text("±\(Int(node.tolerancePercent))%")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color(.systemGray5)))
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
