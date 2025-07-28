import SwiftUI
import Charts

struct AllocationDashboardView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = AllocationDashboardViewModel()

    var body: some View {
        GeometryReader { _ in
            ScrollView {
                VStack(spacing: 24) {
                    OverviewBar(portfolioTotal: viewModel.portfolioTotalFormatted,
                                outOfRange: "\(viewModel.outOfRangeCount)",
                                largestDev: String(format: "%.1f%%", viewModel.largestDeviation),
                                rebalAmount: viewModel.rebalanceAmountFormatted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                    HStack(alignment: .top, spacing: 24) {
                        AllocationTreeCard(viewModel: viewModel)
                            .frame(minWidth: 360)
                            .layoutPriority(1)

                        VStack(spacing: 32) {
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
    @State private var sortColumn: SortColumn = .actual
    @State private var sortAscending = false

    @State private var nameWidth: CGFloat = Self.defaults[.name]!
    @State private var targetWidth: CGFloat = Self.defaults[.target]!
    @State private var actualWidth: CGFloat = Self.defaults[.actual]!
    @State private var deltaWidth: CGFloat = Self.defaults[.deltaVal]!
    @State private var barWidth: CGFloat = Self.defaults[.bar]!


    private enum ColumnKey: String { case name, target, actual, deltaVal, bar }
    private static let defaults: [ColumnKey: CGFloat] = [
        .name: 200, .target: 110, .actual: 110, .deltaVal: 110, .bar: 130
    ]
    private static let minWidths: [ColumnKey: CGFloat] = [
        .name: 160, .target: 80, .actual: 80, .deltaVal: 80, .bar: 120
    ]
    private static let maxWidths: [ColumnKey: CGFloat] = [
        .name: 380, .target: 250, .actual: 250, .deltaVal: 250, .bar: 260
    ]
    private static let widthsKey = "ui.assetAllocation.columnWidths"

    enum SortColumn { case target, actual, delta }

    private let gap: CGFloat = 10

    var body: some View {
        Card {
            GeometryReader { geo in
                let sidePad: CGFloat = 6
                let available = geo.size.width - sidePad * 2
                let spacing = 16 + gap * 4 + 4
                let total = nameWidth + targetWidth + actualWidth + barWidth + deltaWidth + spacing
                let tableWidth = max(available, total)
                let compact = tableWidth < 1024
                let needsScroll = available < total

                let content = VStack(spacing: 0) {
                    HeaderBar()
                    CaptionRow(nameWidth: $nameWidth,
                               targetWidth: $targetWidth,
                               actualWidth: $actualWidth,
                               trackWidth: $barWidth,
                               deltaWidth: $deltaWidth,
                               gap: gap,
                               sortColumn: $sortColumn,
                               sortAscending: $sortAscending)
                    Divider()
                    ScrollView {
                        VStack(spacing: 0) {
                            rows(compact)
                        }
                    }
                }
                .frame(width: tableWidth, alignment: .leading)
                .padding(.horizontal, sidePad)

                if needsScroll {
                    ScrollView(.horizontal) { content }
                } else {
                    content
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .onAppear { initializeExpanded(); loadWidths() }
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
            Text("Asset Class Allocation")
                .font(.headline)
            Spacer()
            VStack(alignment: .leading, spacing: 4) {
                Text("Display mode")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    SegmentedPicker
                    Button(action: resetWidths) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .help("Reset column widths")
                }
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func rows(_ compact: Bool) -> some View {
        ForEach(sortedAssets) { parent in
            AssetRow(node: parent,
                     mode: displayMode,
                     compact: compact,
                     expanded: binding(for: parent.id),
                     nameWidth: nameWidth,
                     targetWidth: targetWidth,
                     actualWidth: actualWidth,
                     trackWidth: barWidth,
                     deltaWidth: deltaWidth,
                     gap: gap)
            if expanded[parent.id] == true, let children = parent.children {
                ForEach(children) { child in
                    AssetRow(node: child,
                             mode: displayMode,
                             compact: compact,
                             expanded: .constant(false),
                             nameWidth: nameWidth,
                             targetWidth: targetWidth,
                             actualWidth: actualWidth,
                             trackWidth: barWidth,
                             deltaWidth: deltaWidth,
                            gap: gap)
                }
            }
        }
    }

    private var sortedAssets: [AllocationDashboardViewModel.Asset] {
        let key: (AllocationDashboardViewModel.Asset) -> Double
        switch sortColumn {
        case .target:
            key = { displayMode == .percent ? $0.targetPct : $0.targetChf }
        case .actual:
            key = { displayMode == .percent ? $0.actualPct : $0.actualChf }
        case .delta:
            key = { displayMode == .percent ? $0.deviationPct : $0.deviationChf }
        }
        return viewModel.assets.sorted {
            sortAscending ? key($0) < key($1) : key($0) > key($1)
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

    private func loadWidths() {
        if let dict = UserDefaults.standard.dictionary(forKey: Self.widthsKey) as? [String: Double] {
            nameWidth = CGFloat(dict[ColumnKey.name.rawValue] ?? Double(Self.defaults[.name]!))
            targetWidth = CGFloat(dict[ColumnKey.target.rawValue] ?? Double(Self.defaults[.target]!))
            actualWidth = CGFloat(dict[ColumnKey.actual.rawValue] ?? Double(Self.defaults[.actual]!))
            deltaWidth = CGFloat(dict[ColumnKey.deltaVal.rawValue] ?? Double(Self.defaults[.deltaVal]!))
            barWidth = CGFloat(dict[ColumnKey.bar.rawValue] ?? Double(Self.defaults[.bar]!))
        }
    }

    private func resetWidths() {
        UserDefaults.standard.removeObject(forKey: Self.widthsKey)
        withAnimation {
            nameWidth = Self.defaults[.name]!
            targetWidth = Self.defaults[.target]!
            actualWidth = Self.defaults[.actual]!
            deltaWidth = Self.defaults[.deltaVal]!
            barWidth = Self.defaults[.bar]!
        }
    }

    struct CaptionRow: View {
        @Binding var nameWidth: CGFloat
        @Binding var targetWidth: CGFloat
        @Binding var actualWidth: CGFloat
        @Binding var trackWidth: CGFloat
        @Binding var deltaWidth: CGFloat
        let gap: CGFloat
        @Binding var sortColumn: SortColumn
        @Binding var sortAscending: Bool

        @State private var startName: CGFloat?
        @State private var startTarget: CGFloat?
        @State private var startActual: CGFloat?
        @State private var startDelta: CGFloat?
        @State private var startBar: CGFloat?

        var body: some View {
            HStack(spacing: gap) {
                Spacer().frame(width: nameWidth + 16)
                    .overlay(alignment: .trailing) { grip(.name) }
                sortHeader("TARGET", column: .target)
                    .frame(width: targetWidth, alignment: .trailing)
                    .overlay(alignment: .trailing) { grip(.target) }
                sortHeader("ACTUAL", column: .actual)
                    .frame(width: actualWidth, alignment: .trailing)
                    .overlay(alignment: .trailing) { grip(.actual) }
                Text("DEVIATION")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: trackWidth, alignment: .center)
                    .lineLimit(1)
                    .overlay(alignment: .trailing) { grip(.bar) }
                sortHeader("\u{0394}", column: .delta)
                    .frame(width: deltaWidth, alignment: .trailing)
                    .overlay(alignment: .trailing) { grip(.deltaVal) }
            }
            .padding(.vertical, 4)
            .overlay(alignment: .bottom) {
                Divider()
                    .background(Color.systemGray4)
            }
        }

        private func sortHeader(_ title: String, column: SortColumn) -> some View {
            Button(action: { toggle(column) }) {
                HStack(spacing: 2) {
                    Text(title)
                    Image(systemName: icon(for: column))
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(column == sortColumn ? Color.primary : Color.secondary)
            }
            .buttonStyle(.plain)
        }

        private func grip(_ key: ColumnKey) -> some View {
            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
                .font(.system(size: 8))
                .frame(width: 6)
                .padding(.trailing, -3)
                .gesture(dragGesture(for: key))
#if os(macOS)
                .cursor(.resizeLeftRight)
#endif
        }

        private func dragGesture(for key: ColumnKey) -> some Gesture {
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    updateWidth(for: key, delta: value.translation.width)
                }
                .onEnded { _ in
                    saveWidths()
                    clearStarts()
                }
        }

        private func updateWidth(for key: ColumnKey, delta: CGFloat) {
            switch key {
            case .name:
                if startName == nil { startName = nameWidth }
                nameWidth = clamped(startName! + delta, key)
            case .target:
                if startTarget == nil { startTarget = targetWidth }
                targetWidth = clamped(startTarget! + delta, key)
            case .actual:
                if startActual == nil { startActual = actualWidth }
                actualWidth = clamped(startActual! + delta, key)
            case .deltaVal:
                if startDelta == nil { startDelta = deltaWidth }
                deltaWidth = clamped(startDelta! + delta, key)
            case .bar:
                if startBar == nil { startBar = trackWidth }
                trackWidth = clamped(startBar! + delta, key)
            }
        }

        private func clamped(_ value: CGFloat, _ key: ColumnKey) -> CGFloat {
            let minV = AllocationTreeCard.minWidths[key] ?? 80
            let maxV = AllocationTreeCard.maxWidths[key] ?? 250
            return min(max(value, minV), maxV)
        }

        private func saveWidths() {
            let dict: [String: Double] = [
                ColumnKey.name.rawValue: Double(nameWidth),
                ColumnKey.target.rawValue: Double(targetWidth),
                ColumnKey.actual.rawValue: Double(actualWidth),
                ColumnKey.deltaVal.rawValue: Double(deltaWidth),
                ColumnKey.bar.rawValue: Double(trackWidth)
            ]
            UserDefaults.standard.set(dict, forKey: AllocationTreeCard.widthsKey)
        }

        private func clearStarts() {
            startName = nil; startTarget = nil; startActual = nil; startDelta = nil; startBar = nil
        }

        private func icon(for column: SortColumn) -> String {
            if column != sortColumn { return "arrow.up.arrow.down" }
            return sortAscending ? "arrow.up" : "arrow.down"
        }

        private func toggle(_ column: SortColumn) {
            if sortColumn == column {
                sortAscending.toggle()
            } else {
                sortColumn = column
                sortAscending = false
            }
        }
    }
}

struct AssetRow: View {
    let node: AllocationDashboardViewModel.Asset
    let mode: DisplayMode
    let compact: Bool
    @Binding var expanded: Bool
    let nameWidth: CGFloat
    let targetWidth: CGFloat
    let actualWidth: CGFloat
    let trackWidth: CGFloat
    let deltaWidth: CGFloat
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

    var body: some View {
        let diffPct = relativeDeviation * 100
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
            .frame(width: max(0, nameWidth - 16), alignment: .leading)

            Text(formatValue(target))
                .frame(width: targetWidth, alignment: .trailing)
                .font(node.children != nil ? .body.bold() : .subheadline)
                .lineLimit(1)
            Text(formatValue(actual))
                .frame(width: actualWidth, alignment: .trailing)
                .font(node.children != nil ? .body.bold() : .subheadline)
                .lineLimit(1)

            HStack(spacing: 4) {
                DeviationBar(target: target,
                             actual: actual,
                             trackWidth: trackWidth)
                    .frame(width: trackWidth)
                Text(formatDeviation(deviation))
                    .font(.caption2)
                    .foregroundStyle(barColor(diffPct))
                    .frame(width: deltaWidth, alignment: .trailing)
                    .lineLimit(1)
            }

        }
        .padding(.vertical, node.children != nil ? 6 : 4)
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

    private func short(_ value: Double) -> String {
        let absV = abs(value)
        if absV >= 1_000_000 {
            return String(format: "%.1f\u{202f}M", value / 1_000_000)
        } else if absV >= 1_000 {
            return String(format: "%.0f\u{202f}k", value / 1_000)
        }
        if absV == 0 { return "0" }
        return String(format: "%.0f", value)
    }

    private func formatPercent(_ value: Double) -> String {
        Self.percentFormatter.string(from: NSNumber(value: value)) ?? ""
    }

    private func formatChf(_ value: Double) -> String {
        if compact { return short(value) }
        if value == 0 { return "0" }
        return Self.chfFormatter.string(from: NSNumber(value: value)) ?? ""
    }

    private func formatSignedPercent(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return sign + (Self.percentFormatter.string(from: NSNumber(value: abs(value))) ?? "") + " %"
    }

    private func formatSignedChf(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        if value == 0 { return "0" }
        if compact { return sign + short(abs(value)) }
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
    let target: Double
    let actual: Double
    var trackWidth: CGFloat

    private var diffPercent: Double {
        guard target != 0 else { return 0 }
        return (actual - target) / target * 100
    }

    private var track: CGFloat { trackWidth - 8 }

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
                .padding(.horizontal, 4)
            Rectangle().fill(Color.black)
                .frame(width: 1, height: 8)
            Capsule().fill(barColor(diffPercent))
                .frame(width: span, height: 6)
                .offset(x: offset)
                .padding(.horizontal, 4)
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
