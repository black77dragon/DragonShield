import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct AssetManagementReportView: View {
    @EnvironmentObject private var dbManager: DatabaseManager
    @StateObject private var viewModel: AssetManagementReportViewModel
    @State private var showCashDetails = false
    @State private var showNearCashDetails = false
    @State private var showCurrencyDetails = false
    @State private var showAssetClassDetails = false
    @State private var selectedAssetClass: AssetManagementReportSummary.AssetClassBreakdown?

    private var summary: AssetManagementReportSummary { viewModel.summary }

    init(viewModel: AssetManagementReportViewModel = AssetManagementReportViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                if viewModel.isLoading {
                    loadingState
                } else {
                    cashSection
                    nearCashSection
                    currencySection
                    assetClassSection
                }
                if let message = viewModel.errorMessage {
                    placeholder(message)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.surface.ignoresSafeArea())
        .navigationTitle("Asset Management Report")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.load(using: dbManager)
                } label: {
                    Label("Refresh Report", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
                .help("Recompute the report with the latest portfolio data.")
            }
        }
        .onAppear {
            viewModel.load(using: dbManager)
        }
        .sheet(item: $selectedAssetClass) { breakdown in
            AssetClassPositionsSheet(
                breakdown: breakdown,
                baseCurrency: summary.baseCurrency,
                formatCurrency: { value, currency, decimals in
                    self.formatCurrency(value, currency: currency, decimals: decimals)
                },
                formatNumber: { value, decimals in
                    self.formatNumber(value, decimals: decimals)
                }
            )
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Asset Management Report")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("As of \(reportDateText)")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                Text(reportDateText)
                    .font(.headline)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.tileBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Theme.tileBorder, lineWidth: 1)
                    )
            )
        }
    }

    private var loadingState: some View {
        HStack(spacing: 12) {
            ProgressView().controlSize(.large)
            Text("Building report with live data…")
                .font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.tileBackground)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.tileBorder, lineWidth: 1))
        )
    }

    private var cashSection: some View {
        ReportSectionCard(
            letter: "A",
            header: Text("How much ") + highlight("cash") + Text(" do I have?")
        ) {
            metricRow(
                title: "Total cash",
                amount: summary.totalCashBase,
                currency: summary.baseCurrency
            )
            if summary.cashBreakdown.isEmpty {
                placeholder("No cash accounts matched the configured filters.")
            } else {
                DisclosureGroup(isExpanded: $showCashDetails) {
                    cashBreakdownTable
                } label: {
                    Label("Tap for account level detail", systemImage: "chevron.down.circle")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .animation(.easeInOut(duration: 0.2), value: showCashDetails)
            }
        }
    }

    private var cashBreakdownTable: some View {
        VStack(spacing: 12) {
            tableHeader(columns: ["Account", "Local", summary.baseCurrency])
            ForEach(summary.cashBreakdown) { row in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.accountName)
                                .font(.headline)
                            Text(row.institutionName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(row.currency) \(formatNumber(row.localAmount, decimals: 0))")
                            .font(.body.monospacedDigit())
                            .frame(width: 160, alignment: .trailing)
                        Text(formatCurrency(row.baseAmount, currency: summary.baseCurrency))
                            .font(.body.monospacedDigit())
                            .frame(width: 160, alignment: .trailing)
                    }
                    Divider()
                }
            }
        }
        .padding(.top, 12)
    }

    private var nearCashSection: some View {
        ReportSectionCard(
            letter: "B",
            header: Text("What can I ") + highlight("convert into cash") + Text(" early?")
        ) {
            metricRow(
                title: "Total near cash",
                amount: summary.totalNearCashBase,
                currency: summary.baseCurrency
            )
            if nearCashCategories.isEmpty {
                placeholder("No fixed income or money market holdings detected.")
            } else {
                DisclosureGroup(isExpanded: $showNearCashDetails) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                        ForEach(nearCashCategories) { category in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(category.name)
                                    .font(.headline)
                                Text(formatCurrency(category.totalBase, currency: summary.baseCurrency))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Theme.tileBackground)
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.tileBorder, lineWidth: 1))
                            )
                        }
                    }
                    .padding(.vertical, 4)

                    Divider().padding(.vertical, 8)

                    nearCashDetailTable
                } label: {
                    Label("Tap for near-cash detail", systemImage: "chevron.down.circle")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .animation(.easeInOut(duration: 0.2), value: showNearCashDetails)
            }
        }
    }

    private var nearCashDetailTable: some View {
        VStack(spacing: 12) {
            tableHeader(columns: ["Instrument", "Currency", summary.baseCurrency])
            ForEach(summary.nearCashHoldings) { row in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.name)
                                .font(.headline)
                            Text("\(row.category) • \(row.accountName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(row.currency) \(formatNumber(row.localValue, decimals: 0))")
                            .font(.body.monospacedDigit())
                            .frame(width: 160, alignment: .trailing)
                        Text(formatCurrency(row.baseValue, currency: summary.baseCurrency))
                            .font(.body.monospacedDigit())
                            .frame(width: 160, alignment: .trailing)
                    }
                    Divider()
                }
            }
        }
        .padding(.top, 12)
    }

    private var currencySection: some View {
        ReportSectionCard(
            letter: "C",
            header: Text("In which ") + highlight("currencies") + Text(" am I allocated?")
        ) {
            if summary.currencyAllocations.isEmpty {
                placeholder("No currency exposure available yet.")
            } else {
                DisclosureGroup(isExpanded: $showCurrencyDetails) {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(summary.currencyAllocations) { allocation in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(allocation.currency)
                                        .font(.headline)
                                    Spacer()
                                    Text(formatCurrency(allocation.baseValue, currency: summary.baseCurrency))
                                        .font(.body.monospacedDigit())
                                }
                                ProgressView(value: allocation.percentage, total: 100)
                                    .tint(currencyColor(for: allocation.currency))
                                Text(String(format: "%.1f%% of invested assets", allocation.percentage))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } label: {
                    Label("Tap for currency exposure detail", systemImage: "chevron.down.circle")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .animation(.easeInOut(duration: 0.2), value: showCurrencyDetails)
            }
        }
    }

    private var assetClassSection: some View {
        ReportSectionCard(
            letter: "D",
            header: Text("In which ") + highlight("asset classes") + Text(" am I invested?")
        ) {
            if summary.assetClassBreakdown.isEmpty {
                placeholder("No asset class data available yet.")
            } else {
                DisclosureGroup(isExpanded: $showAssetClassDetails) {
                    VStack(alignment: .leading, spacing: 16) {
                        #if canImport(Charts)
                        Chart(summary.assetClassBreakdown) { item in
                            SectorMark(
                                angle: .value("Value", item.baseValue),
                                innerRadius: .ratio(0.55),
                                angularInset: 1
                            )
                            .cornerRadius(6)
                            .foregroundStyle(by: .value("Asset Class", item.name))
                            .annotation(position: .overlay) {
                                if item.percentage >= 8 {
                                    VStack(spacing: 2) {
                                        Text(item.name)
                                            .font(.caption2.weight(.semibold))
                                            .foregroundColor(.white)
                                        Text(String(format: "%.0f%%", item.percentage))
                                            .font(.caption2)
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                }
                            }
                        }
                        .chartLegend(position: .bottom, spacing: 8)
                        .frame(height: 280)
                        .modifier(ChartDoubleTapModifier(
                            breakdown: summary.assetClassBreakdown,
                            selectionHandler: { selectedAssetClass = $0 }
                        ))
                        #else
                        placeholder("Charts are not supported on this platform.")
                        #endif

                        Text("Double-click a slice (macOS 14+/iOS 17+) or tap a row below to open the position list for that asset class.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(summary.assetClassBreakdown.prefix(4)) { item in
                                Button {
                                    selectedAssetClass = item
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(item.name)
                                            Spacer()
                                            Text(formatCurrency(item.baseValue, currency: summary.baseCurrency))
                                                .font(.subheadline.monospacedDigit())
                                        }
                                        ProgressView(value: item.percentage, total: 100)
                                            .tint(Theme.primaryAccent)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } label: {
                    Label("Tap for asset class detail", systemImage: "chevron.down.circle")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .animation(.easeInOut(duration: 0.2), value: showAssetClassDetails)
            }
        }
    }

    private func metricRow(title: String, amount: Double, currency: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption)
                .kerning(1)
                .foregroundColor(.secondary)
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(formatCurrency(amount, currency: currency))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Text(currency)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func tableHeader(columns: [String]) -> some View {
        HStack {
            ForEach(Array(columns.enumerated()), id: \.offset) { index, title in
                if index == 0 {
                    Text(title.uppercased())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(title.uppercased())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 160, alignment: .trailing)
                }
            }
        }
    }

    private func highlight(_ word: String) -> Text {
        Text(word)
            .fontWeight(.black)
            .foregroundColor(Theme.primaryAccent)
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundColor(.secondary)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [6]))
                    .foregroundColor(Theme.tileBorder)
            )
    }

    private var nearCashCategories: [CategoryAggregate] {
        let grouped = Dictionary(grouping: summary.nearCashHoldings, by: { $0.category })
        return grouped.map { key, rows in
            CategoryAggregate(id: key, name: key, totalBase: rows.reduce(0) { $0 + $1.baseValue })
        }
        .sorted { $0.totalBase > $1.totalBase }
    }

    private var reportDateText: String {
        DateFormatter.assetReportShort.string(from: summary.reportDate)
    }

    private func formatCurrency(_ value: Double, currency: String, decimals: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = decimals
        formatter.minimumFractionDigits = decimals
        return formatter.string(from: NSNumber(value: value)) ?? "\(currency) \(value)"
    }

    private func formatNumber(_ value: Double, decimals: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = decimals
        formatter.minimumFractionDigits = decimals
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(decimals)f", value)
    }

    private func currencyColor(for code: String) -> Color {
        Theme.currencyColors[code.uppercased()] ?? Theme.primaryAccent
    }

    private struct CategoryAggregate: Identifiable {
        let id: String
        let name: String
        let totalBase: Double
    }
}

private struct ReportSectionCard<Content: View>: View {
    let letter: String
    let header: Text
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(letter)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.primaryAccent)
                    )
                header
                    .font(.title2.weight(.semibold))
            }
            content()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Theme.tileBackground)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.tileBorder, lineWidth: 1))
                .shadow(color: Theme.tileShadow.opacity(0.15), radius: 12, x: 0, y: 6)
        )
    }
}

private extension DateFormatter {
    static let assetReportShort: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yy"
        return formatter
    }()
}

private struct AssetClassPositionsSheet: View {
    let breakdown: AssetManagementReportSummary.AssetClassBreakdown
    let baseCurrency: String
    let formatCurrency: (Double, String, Int) -> String
    let formatNumber: (Double, Int) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(breakdown.name)
                        .font(.title2.weight(.bold))
                    Text(String(format: "%.1f%% of portfolio", breakdown.percentage))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(formatCurrency(breakdown.baseValue, baseCurrency, 0))
                    .font(.title3.monospacedDigit())
            }

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(breakdown.positions) { position in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(position.instrumentName)
                                    .font(.headline)
                                Spacer()
                                Text(formatCurrency(position.baseValue, baseCurrency, 0))
                                    .font(.subheadline.monospacedDigit())
                            }
                            Text("\(position.assetSubClass) • \(position.accountName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(spacing: 16) {
                                Text("Quantity: \(formatNumber(position.quantity, 2))")
                                    .font(.caption)
                                Spacer()
                                Text("Local: \(formatCurrency(position.localValue, position.currency, 0))")
                                    .font(.caption.monospacedDigit())
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Theme.tileBackground)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.tileBorder, lineWidth: 1))
                        )
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 420)
    }
}

#if canImport(Charts)
private struct ChartDoubleTapModifier: ViewModifier {
    let breakdown: [AssetManagementReportSummary.AssetClassBreakdown]
    let selectionHandler: (AssetManagementReportSummary.AssetClassBreakdown) -> Void
    private let innerRadiusRatio: Double = 0.55

    func body(content: Content) -> some View {
        if #available(macOS 14.0, iOS 17.0, *) {
            content
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                SpatialTapGesture(count: 2)
                                    .onEnded { value in
                                        let anchor: Anchor<CGRect>?
                                        if #available(macOS 14.0, iOS 17.0, *) {
                                            anchor = proxy.plotFrame
                                        } else {
                                            anchor = proxy.plotAreaFrame
                                        }
                                        guard let resolvedAnchor = anchor else { return }
                                        let plotRect = geo[resolvedAnchor]
                                        let localPoint = CGPoint(
                                            x: value.location.x - plotRect.origin.x,
                                            y: value.location.y - plotRect.origin.y
                                        )
                                        if let match = slice(at: localPoint, plotSize: plotRect.size) {
                                            selectionHandler(match)
                                        }
                                    }
                            )
                    }
                }
        } else {
            content
        }
    }

    private func slice(at location: CGPoint, plotSize: CGSize) -> AssetManagementReportSummary.AssetClassBreakdown? {
        guard !breakdown.isEmpty else { return nil }
        let outerRadius = Double(min(plotSize.width, plotSize.height) / 2)
        let innerRadius = outerRadius * innerRadiusRatio
        let center = CGPoint(x: plotSize.width / 2, y: plotSize.height / 2)
        let dx = Double(location.x - center.x)
        let dy = Double(location.y - center.y)
        let distance = sqrt(dx * dx + dy * dy)
        guard distance >= innerRadius, distance <= outerRadius else { return nil }

        var angle = atan2(dy, dx)
        if angle < 0 { angle += 2 * .pi }

        let total = breakdown.reduce(0) { $0 + max($1.baseValue, 0) }
        guard total > 0 else { return nil }

        var startAngle = 0.0
        for item in breakdown {
            let share = max(item.baseValue, 0) / total
            let endAngle = startAngle + share * 2 * .pi
            if angle >= startAngle, angle < endAngle {
                return item
            }
            startAngle = endAngle
        }
        return breakdown.last
    }
}
#endif

#if DEBUG
struct AssetManagementReportView_Previews: PreviewProvider {
    static var previews: some View {
        let vm = AssetManagementReportViewModel()
        vm.applyPreviewData(.preview)
        return AssetManagementReportView(viewModel: vm)
            .environmentObject(DatabaseManager())
            .frame(width: 900)
    }
}
#endif
