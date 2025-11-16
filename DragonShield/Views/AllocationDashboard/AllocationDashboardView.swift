import Charts
import Foundation
import SwiftUI
#if os(macOS)
    import AppKit
#endif

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
        .onReceive(NotificationCenter.default.publisher(for: .targetsUpdated)) { _ in
            viewModel.load(using: dbManager)
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
        case .alert: return .red
        case .warning: return .orange
        case .neutral: return .primary
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
    @State private var showValidationDetails = false
    @EnvironmentObject private var dbManager: DatabaseManager

    enum SortColumn { case target, actual, delta }

    private let gap: CGFloat = 10

    private let minName: CGFloat = 120
    private let minNumeric: CGFloat = 60
    private let minBar: CGFloat = 120
    private let statusColumnWidth: CGFloat = 28
    private let deviationBarColumnWidth: CGFloat = 120

    private func updateWidths(for tableWidth: CGFloat) {
        let spacing: CGFloat = 16 + gap * 6 + 4 + statusColumnWidth + deviationBarColumnWidth
        let available = tableWidth - spacing
        guard available > 0 else { return }
        let oldTotal = widths.total
        if oldTotal == 0 { return }
        let ratio = available / oldTotal
        widths.name *= ratio
        widths.target *= ratio
        widths.actual *= ratio
        widths.bar *= ratio
        widths.delta *= ratio

        widths.name = max(minName, widths.name)
        widths.target = max(minNumeric, widths.target)
        widths.actual = max(minNumeric, widths.actual)
        widths.bar = max(minBar, widths.bar)
        widths.delta = max(minNumeric, widths.delta)

        var diff = available - widths.total
        if abs(diff) > 0.1 {
            let adj = max(0, widths.total - (minName + minNumeric * 3 + minBar))
            guard adj > 0 else { return }
            let f = diff / adj
            widths.name += (widths.name - minName) * f
            widths.target += (widths.target - minNumeric) * f
            widths.actual += (widths.actual - minNumeric) * f
            widths.bar += (widths.bar - minBar) * f
            widths.delta += (widths.delta - minNumeric) * f
            diff = available - widths.total
            if abs(diff) > 0.1 {
                widths.name += diff
            }
        }
    }

    private struct ColumnWidths {
        var name: CGFloat
        var target: CGFloat
        var actual: CGFloat
        var bar: CGFloat
        var delta: CGFloat

        var total: CGFloat { name + target + actual + bar + delta }
    }

    @State private var widths = ColumnWidths(name: 160, target: 90, actual: 90, bar: 200, delta: 80)

    var body: some View {
        Card {
            GeometryReader { geo in
                let sidePad: CGFloat = 6
                let tableWidth = geo.size.width - sidePad * 2
                Color.clear
                    .onAppear { updateWidths(for: tableWidth) }
                    .onChange(of: geo.size.width, initial: false) { _, newVal in
                        updateWidths(for: newVal - sidePad * 2)
                    }
                let compact = tableWidth < 1024

                VStack(spacing: 0) {
                    HeaderBar()
                    CaptionRow(nameWidth: widths.name,
                               targetWidth: widths.target,
                               actualWidth: widths.actual,
                               trackWidth: widths.bar,
                               deltaWidth: widths.delta,
                               statusWidth: statusColumnWidth,
                               barWidth: deviationBarColumnWidth,
                               gap: gap,
                               sortColumn: $sortColumn,
                               sortAscending: $sortAscending)
                    Divider()
                    ScrollView {
                        VStack(spacing: 0) {
                            rows(widths.name, widths.target, widths.actual, widths.bar, widths.delta, statusColumnWidth, deviationBarColumnWidth, compact)
                        }
                    }
                    Divider()
                    TotalsRow(nameWidth: widths.name,
                              targetWidth: widths.target,
                              actualWidth: widths.actual,
                              trackWidth: widths.bar,
                              deltaWidth: widths.delta,
                              statusWidth: statusColumnWidth,
                              barWidth: deviationBarColumnWidth,
                              gap: gap,
                              totalTargetPct: viewModel.totalTargetPercent,
                              totalTargetChf: viewModel.totalTargetChf,
                              totalActualChf: viewModel.totalActualChf)
                }
                .frame(width: tableWidth, alignment: .leading)
                .padding(.horizontal, sidePad)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
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
            Button("Validation Details") { showValidationDetails = true }
                .disabled(viewModel.validationFindings.isEmpty)
                .foregroundColor(validationColor)
                .help(validationTooltip)
            VStack(alignment: .leading, spacing: 4) {
                Text("Display mode")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                SegmentedPicker
            }
        }
        .padding(.horizontal, 16)
        .sheet(isPresented: $showValidationDetails) {
            ValidationDetailsSheet(findings: viewModel.validationFindings,
                                   classNames: viewModel.classNames,
                                   subClassNames: viewModel.subClassNames)
        }
    }

    private var validationColor: Color {
        switch viewModel.worstSeverity {
        case .error: return .red
        case .warning: return .orange
        case .none: return .gray
        }
    }

    private var validationTooltip: String {
        switch viewModel.worstSeverity {
        case .error: return "Validation errors present. Click for details."
        case .warning: return "Validation warnings present. Click for details."
        case .none: return "No validation findings."
        }
    }

    @ViewBuilder
    private func rows(_ nameWidth: CGFloat,
                      _ targetWidth: CGFloat,
                      _ actualWidth: CGFloat,
                      _ trackWidth: CGFloat,
                      _ deltaWidth: CGFloat,
                      _ statusWidth: CGFloat,
                      _ barWidth: CGFloat,
                      _ compact: Bool) -> some View
    {
        ForEach(sortedAssets) { parent in
            VStack(spacing: 0) {
                AssetRow(node: parent,
                         mode: displayMode,
                         compact: compact,
                         expanded: binding(for: parent.id),
                         nameWidth: nameWidth,
                         targetWidth: targetWidth,
                         actualWidth: actualWidth,
                         trackWidth: trackWidth,
                         deltaWidth: deltaWidth,
                         statusWidth: statusWidth,
                         barWidth: barWidth,
                         gap: gap)
            }
            if expanded[parent.id] == true, let children = parent.children {
                ForEach(children) { child in
                    AssetRow(node: child,
                             mode: displayMode,
                             compact: compact,
                             expanded: .constant(false),
                             nameWidth: nameWidth,
                             targetWidth: targetWidth,
                             actualWidth: actualWidth,
                             trackWidth: trackWidth,
                             deltaWidth: deltaWidth,
                             statusWidth: statusWidth,
                             barWidth: barWidth,
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
           let mode = DisplayMode(rawValue: raw)
        {
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
        let trackWidth: CGFloat
        let deltaWidth: CGFloat
        let statusWidth: CGFloat
        let barWidth: CGFloat
        let gap: CGFloat
        @Binding var sortColumn: SortColumn
        @Binding var sortAscending: Bool

        var body: some View {
            HStack(spacing: gap) {
                Spacer().frame(width: nameWidth + 16)
                sortHeader("TARGET", column: .target)
                    .frame(width: targetWidth, alignment: .trailing)
                sortHeader("ACTUAL", column: .actual)
                    .frame(width: actualWidth, alignment: .trailing)
                Text("DEVIATION")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: trackWidth, alignment: .center)
                    .lineLimit(1)
                sortHeader("\u{0394}", column: .delta)
                    .frame(width: deltaWidth, alignment: .trailing)
                Text("St")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: statusWidth, alignment: .center)
                Text("%-Deviation Bar")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: barWidth, alignment: .leading)
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

struct TotalsRow: View {
    let nameWidth: CGFloat
    let targetWidth: CGFloat
    let actualWidth: CGFloat
    let trackWidth: CGFloat
    let deltaWidth: CGFloat
    let statusWidth: CGFloat
    let barWidth: CGFloat
    let gap: CGFloat
    let totalTargetPct: Double
    let totalTargetChf: Double
    let totalActualChf: Double
    private let warningTol: Double = 0.1
    private let errorTol: Double = 1.0

    private var chfFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "'"
        f.maximumFractionDigits = 0
        return f
    }

    private var targetColor: Color {
        let diff = abs(totalTargetPct - 100)
        if diff > errorTol { return .red }
        if diff > warningTol { return .orange }
        return .primary
    }

    var body: some View {
        HStack(spacing: gap) {
            Spacer().frame(width: 16)
            Text("TOTAL")
                .font(.caption.bold())
                .frame(width: nameWidth, alignment: .leading)
            Text(String(format: "%.1f %%", totalTargetPct))
                .font(.caption.bold())
                .foregroundColor(targetColor)
                .frame(width: targetWidth, alignment: .trailing)
                .help("Portfolio Target % total = \(String(format: "%.1f", totalTargetPct))%; expected 100% ± \(warningTol).")
            Text(chfFormatter.string(from: NSNumber(value: totalTargetChf)) ?? "")
                .font(.caption.bold())
                .frame(width: actualWidth, alignment: .trailing)
            Spacer().frame(width: trackWidth)
            Text(chfFormatter.string(from: NSNumber(value: totalActualChf)) ?? "")
                .font(.caption.bold())
                .frame(width: deltaWidth, alignment: .trailing)
            Spacer().frame(width: statusWidth)
            Spacer().frame(width: barWidth)
        }
        .padding(.vertical, 4)
    }
}

struct AssetRow: View {
    let node: AllocationDashboardViewModel.Asset
    let mode: DisplayMode
    let compact: Bool
    @Binding var expanded: Bool
    @Environment(\.openWindow) private var openWindow
    let nameWidth: CGFloat
    let targetWidth: CGFloat
    let actualWidth: CGFloat
    let trackWidth: CGFloat
    let deltaWidth: CGFloat
    let statusWidth: CGFloat
    let barWidth: CGFloat
    let gap: CGFloat

    private var classId: Int? {
        guard node.id.hasPrefix("class-") else { return nil }
        return Int(node.id.dropFirst(6))
    }

    private var target: Double {
        mode == .percent ? node.targetPct : node.targetChf
    }

    private var showBullet: Bool {
        (mode == .percent && node.targetKind == .percent) ||
            (mode == .chf && node.targetKind == .amount)
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

            HStack(spacing: 2) {
                Text(formatValue(target))
                if showBullet {
                    Text("\u{25CF}")
                        .font(.system(size: 7))
                        .foregroundStyle(.primary)
                }
                if let cid = classId {
                    Button { openWindow(id: "targetEdit", value: cid) } label: {
                        Image(systemName: "pencil.circle")
                            .foregroundColor(.accentColor)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 24, height: 24)
                    .accessibilityLabel("Edit targets for \(node.name)")
                    .keyboardShortcut(.defaultAction)
                }
            }
            .alignmentGuide(.trailing) { d in d[.trailing] }
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
                Text(statusEmoji(for: node))
                    .frame(width: statusWidth, alignment: .center)
                Text(percentBar(for: node))
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: barWidth, alignment: .leading)
            }
        }
        .padding(.vertical, node.children != nil ? 6 : 4)
        .background(node.children != nil ? Color.systemGray6 : .clear)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { if let cid = classId { openWindow(id: "targetEdit", value: cid) } }
        .focusable()
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
        } else if absV >= 1000 {
            return String(format: "%.0f\u{202f}k", value / 1000)
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

    private enum ValidationStatus { case compliant, warning, error }

    private func statusEmoji(for asset: AllocationDashboardViewModel.Asset) -> String {
        switch status(for: asset) {
        case .compliant: return "🟢"
        case .warning: return "🟠"
        case .error: return "🔴"
        }
    }

    private func status(for asset: AllocationDashboardViewModel.Asset) -> ValidationStatus {
        let own = status(from: abs(asset.deviationPct), tolerance: asset.tolerancePercent)
        guard let children = asset.children else { return own }
        return children.map { status(for: $0) }.reduce(own) { worst($0, $1) }
    }

    private func status(from deviation: Double, tolerance: Double) -> ValidationStatus {
        if deviation <= tolerance { return .compliant }
        if deviation <= tolerance * 2 { return .warning }
        return .error
    }

    private func worst(_ a: ValidationStatus, _ b: ValidationStatus) -> ValidationStatus {
        if a == .error || b == .error { return .error }
        if a == .warning || b == .warning { return .warning }
        return .compliant
    }

    private func percentBar(for asset: AllocationDashboardViewModel.Asset) -> String {
        let dev = abs(asset.deviationPct)
        let filled = min(10, Int(round(dev / 10)))
        let empty = max(0, 10 - filled)
        return "[" + String(repeating: "■", count: filled) + String(repeating: "□", count: empty) + "]"
    }
}

private func barColor(_ diffPercent: Double) -> Color {
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
            .chartXScale(domain: -25 ... 25)
            .chartYScale(domain: 0 ... 40)
            .frame(height: 240)
        }
    }
}

struct ValidationDetailsSheet: View {
    let findings: [DatabaseManager.ValidationFinding]
    let classNames: [Int: String]
    let subClassNames: [Int: String]
    @State private var filter: SeverityFilter = .all
    @Environment(\.dismiss) private var dismiss

    enum SeverityFilter: String, CaseIterable { case all = "All", errors = "Errors", warnings = "Warnings" }

    private var filtered: [DatabaseManager.ValidationFinding] {
        switch filter {
        case .all: return findings
        case .errors: return findings.filter { $0.severity == "error" }
        case .warnings: return findings.filter { $0.severity == "warning" }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Validation Details")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(width: 32, height: 32)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(ScaleButtonStyle())
            }

            Picker("", selection: $filter) {
                ForEach(SeverityFilter.allCases, id: \.rawValue) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)

            if filtered.isEmpty {
                Text("No validation findings at this time.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section("Portfolio-level") {
                        ForEach(filtered.filter { $0.entityType == "portfolio" }) { f in
                            findingRow(f)
                        }
                    }
                    Section("Asset Classes") {
                        ForEach(filtered.filter { $0.entityType == "class" }) { f in
                            findingRow(f, name: classNames[f.entityId])
                        }
                    }
                    Section("Sub-Classes") {
                        ForEach(filtered.filter { $0.entityType == "subclass" }) { f in
                            findingRow(f, name: subClassNames[f.entityId])
                        }
                    }
                }
                Button("Copy to clipboard") { copyToClipboard() }
                    .padding(.top, 8)
            }
        }
        .padding()
        .frame(minWidth: 640, minHeight: 500)
    }

    @ViewBuilder
    private func findingRow(_ f: DatabaseManager.ValidationFinding, name: String? = nil) -> some View {
        HStack {
            Text(f.severity.uppercased())
                .font(.caption.bold())
                .foregroundColor(f.severity == "error" ? .red : .orange)
                .padding(4)
                .background(f.severity == "error" ? Color.red.opacity(0.1) : Color.orange.opacity(0.1))
                .cornerRadius(4)
            VStack(alignment: .leading) {
                Text("\(f.code): \(f.message)")
                if let name = name { Text(name).font(.caption).foregroundColor(.secondary) }
                Text(f.computedAt).font(.caption2).foregroundColor(.secondary)
            }
        }
    }

    private func copyToClipboard() {
        let text = filtered.map { "[\($0.severity.uppercased())] \($0.code): \($0.message)" }.joined(separator: "\n")
        #if os(macOS)
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(text, forType: .string)
        #endif
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
