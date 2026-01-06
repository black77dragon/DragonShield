import SwiftUI
#if canImport(Charts)
    import Charts
#endif

struct HistoricPerformanceView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var rows: [PortfolioValueHistoryRow] = []
    @State private var isLoading = false
    @State private var selectedRange: PerformanceRange = .sixMonth
    @State private var redesignedHoveredPoint: PerformancePoint? = nil
    @State private var showingDataManager = false

    private enum PerformanceRange: String, CaseIterable, Identifiable {
        case oneDay = "1D"
        case fiveDay = "5D"
        case oneMonth = "1M"
        case sixMonth = "6M"
        case yearToDate = "YTD"
        case oneYear = "1Y"
        case fiveYear = "5Y"
        case max = "MAX"

        var id: String { rawValue }
        var label: String { rawValue }

        var displayLabel: String {
            switch self {
            case .oneDay:
                return "Heute"
            default:
                return rawValue
            }
        }
    }

    private struct PerformancePoint: Identifiable {
        let date: Date
        let totalValueChf: Double

        var id: Date { date }
    }

    private struct PerformanceSummary {
        let latestValue: Double
        let deltaValue: Double
        let deltaPercent: Double
    }

    private static let valueFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.groupingSeparator = "'"
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yy"
        f.locale = Locale(identifier: "de_CH")
        f.timeZone = .current
        return f
    }()

    private static let shortAxisDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM"
        f.locale = Locale(identifier: "de_CH")
        f.timeZone = .current
        return f
    }()

    private static let longAxisDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yy"
        f.locale = Locale(identifier: "de_CH")
        f.timeZone = .current
        return f
    }()

    private static let currencyDetailFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.groupingSeparator = "'"
        f.decimalSeparator = "."
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    private static let axisCompactFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.groupingSeparator = "'"
        f.decimalSeparator = "."
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        return f
    }()

    private static let percentFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    private let chartHeight: CGFloat = 240

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Historic Performance")
                    .font(.title2)
                    .bold()
                Spacer()
                Button {
                    showingDataManager = true
                } label: {
                    Label("Manage Data", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.bordered)
            }

            if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else if rows.isEmpty {
                Text("No daily values recorded yet.")
                    .foregroundColor(.secondary)
            } else {
                redesignedSection
                tableSection
                    .padding(.top, 24)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: reload)
        .sheet(isPresented: $showingDataManager, onDismiss: reload) {
            HistoricPerformanceDataView()
                .environmentObject(dbManager)
        }
    }

    private var redesignedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            redesignedCard
        }
    }

    @ViewBuilder
    private var redesignedCard: some View {
        let points = redesignedPoints
        let today = Calendar.current.startOfDay(for: Date())
        let filtered = filteredPoints(points, for: selectedRange, referenceDate: today)
        let summary = performanceSummary(for: filtered)
        let trendColor = (summary?.deltaValue ?? 0) >= 0 ? DSColor.accentSuccess : DSColor.accentError

        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Total Asset Value (CHF)")
                        .font(.title3)
                        .foregroundColor(DSColor.textPrimary)
                    Text(summary.map { formatCurrencyDetailed($0.latestValue) } ?? "CHF -")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(DSColor.textPrimary)
                        .monospacedDigit()
                    HStack(spacing: 6) {
                        if let summary {
                            Text("\(formatSignedCurrency(summary.deltaValue)) (\(formatPercent(summary.deltaPercent)))")
                                .foregroundColor(trendColor)
                        } else {
                            Text("-")
                                .foregroundColor(DSColor.textSecondary)
                        }
                        Text(selectedRange.displayLabel)
                            .foregroundColor(DSColor.textPrimary)
                    }
                    .font(.subheadline)
                }
                Spacer()
                performanceRangeSelector
            }
            redesignedChart(points: filtered, accent: trendColor)
        }
        .padding(24)
        .background(DSColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(DSColor.border, lineWidth: 1))
    }

    private var performanceRangeSelector: some View {
        HStack(spacing: 4) {
            ForEach(PerformanceRange.allCases) { range in
                rangeButton(range)
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 12).fill(DSColor.surfaceSecondary))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DSColor.border, lineWidth: 1))
    }

    private func rangeButton(_ range: PerformanceRange) -> some View {
        let isSelected = selectedRange == range
        return Button {
            selectedRange = range
            redesignedHoveredPoint = nil
        } label: {
            Text(range.label)
                .font(.footnote.weight(.semibold))
                .foregroundColor(isSelected ? DSColor.textPrimary : DSColor.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(minWidth: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? DSColor.surface : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? DSColor.borderStrong : Color.clear, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(isSelected ? 0.12 : 0.0), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func redesignedChart(points: [PerformancePoint], accent: Color) -> some View {
        #if canImport(Charts)
            if points.isEmpty {
                Text("No data available for this range.")
                    .foregroundColor(DSColor.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: chartHeight)
            } else {
                let domain = redesignedDomain(points)
                let yDomain = redesignedYDomain(points)
                let gradient = LinearGradient(
                    colors: [accent.opacity(0.25), accent.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Chart {
                    ForEach(points) { point in
                        AreaMark(
                            x: .value("Date", point.date),
                            yStart: .value("Base", yDomain.lowerBound),
                            yEnd: .value("CHF", point.totalValueChf)
                        )
                        .foregroundStyle(gradient)
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("CHF", point.totalValueChf)
                        )
                        .foregroundStyle(accent)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineJoin: .round))
                    }
                    if let highlighted = redesignedHoveredPoint {
                        PointMark(
                            x: .value("Date", highlighted.date),
                            y: .value("CHF", highlighted.totalValueChf)
                        )
                        .symbolSize(70)
                        .foregroundStyle(accent)
                        .annotation(position: .top, alignment: .leading) {
                            redesignedHoverLabel(for: highlighted)
                        }
                    }
                }
                .chartXScale(domain: domain)
                .chartYScale(domain: yDomain)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine()
                            .foregroundStyle(DSColor.border.opacity(0.6))
                        AxisTick()
                            .foregroundStyle(DSColor.border.opacity(0.4))
                        AxisValueLabel {
                            if let val = value.as(Double.self) {
                                Text(formatCompactAxisValue(val))
                                    .foregroundColor(DSColor.textTertiary)
                                    .font(.system(size: 11))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 9)) { value in
                        AxisTick()
                            .foregroundStyle(DSColor.border.opacity(0.4))
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(axisLabel(for: date, range: selectedRange))
                                    .foregroundColor(DSColor.textTertiary)
                                    .font(.system(size: 10))
                                    .rotationEffect(.degrees(45))
                                    .fixedSize(horizontal: true, vertical: true)
                            }
                        }
                    }
                }
                .chartPlotStyle { plotArea in
                    plotArea.clipped()
                }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            #if os(macOS)
                                .onContinuousHover { phase in
                                    switch phase {
                                    case .active(let location):
                                        redesignedHoveredPoint = redesignedHoverPoint(points, proxy: proxy, geo: geo, location: location)
                                    case .ended:
                                        redesignedHoveredPoint = nil
                                    }
                                }
                            #else
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            redesignedHoveredPoint = redesignedHoverPoint(points, proxy: proxy, geo: geo, location: value.location)
                                        }
                                        .onEnded { _ in
                                            redesignedHoveredPoint = nil
                                        }
                                )
                            #endif
                    }
                }
                .frame(height: chartHeight + 40)
            }
        #else
            Text("Charts not available on this platform.")
                .foregroundColor(.secondary)
        #endif
    }

    private var tableSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Table")
                .font(.headline)
                .foregroundColor(DSColor.textPrimary)
            HStack {
                Text("Date")
                    .frame(width: 120, alignment: .leading)
                Text("Total Asset Value (CHF)")
                    .frame(width: 200, alignment: .trailing)
                Spacer()
            }
            .font(.caption)
            .foregroundColor(DSColor.textSecondary)

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(rows) { row in
                        HStack {
                            Text(Self.dateFormatter.string(from: displayDate(for: row.valueDate)))
                                .frame(width: 120, alignment: .leading)
                            Text(formatValue(row.totalValueChf))
                                .frame(width: 200, alignment: .trailing)
                                .monospacedDigit()
                            Spacer()
                        }
                        .font(.system(size: 12))
                        Divider()
                            .overlay(DSColor.border)
                    }
                }
            }
            .frame(maxHeight: 260)
        }
        .padding(16)
        .background(DSColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DSColor.border, lineWidth: 1))
    }

    private var redesignedPoints: [PerformancePoint] {
        rows.map { row in
            PerformancePoint(date: displayDate(for: row.valueDate), totalValueChf: row.totalValueChf)
        }
        .sorted { $0.date < $1.date }
    }

    private func filteredPoints(_ points: [PerformancePoint], for range: PerformanceRange, referenceDate: Date) -> [PerformancePoint] {
        let capped = points.filter { $0.date <= referenceDate }
        guard let start = rangeStartDate(for: range, referenceDate: referenceDate) else {
            return capped.isEmpty ? points : capped
        }
        let filtered = capped.filter { $0.date >= start }
        if filtered.isEmpty {
            return capped.isEmpty ? points : capped
        }
        return filtered
    }

    private func rangeStartDate(for range: PerformanceRange, referenceDate: Date) -> Date? {
        let calendar = Calendar.current
        let anchor = calendar.startOfDay(for: referenceDate)
        switch range {
        case .oneDay:
            return calendar.date(byAdding: .day, value: -1, to: anchor)
        case .fiveDay:
            return calendar.date(byAdding: .day, value: -5, to: anchor)
        case .oneMonth:
            return calendar.date(byAdding: .month, value: -1, to: anchor)
        case .sixMonth:
            return calendar.date(byAdding: .month, value: -6, to: anchor)
        case .yearToDate:
            let year = calendar.component(.year, from: anchor)
            return calendar.date(from: DateComponents(year: year, month: 1, day: 1))
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: anchor)
        case .fiveYear:
            return calendar.date(byAdding: .year, value: -5, to: anchor)
        case .max:
            return nil
        }
    }

    private func performanceSummary(for points: [PerformancePoint]) -> PerformanceSummary? {
        guard let lastPoint = points.last else { return nil }
        let startPoint = points.first ?? lastPoint
        let delta = lastPoint.totalValueChf - startPoint.totalValueChf
        let percent = startPoint.totalValueChf != 0 ? (delta / startPoint.totalValueChf) * 100 : 0
        return PerformanceSummary(latestValue: lastPoint.totalValueChf, deltaValue: delta, deltaPercent: percent)
    }

    private func formatCurrencyDetailed(_ value: Double) -> String {
        let formatted = Self.currencyDetailFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
        return "CHF \(formatted)"
    }

    private func formatSignedCurrency(_ value: Double) -> String {
        let formatted = Self.currencyDetailFormatter.string(from: NSNumber(value: abs(value))) ?? String(format: "%.2f", abs(value))
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)CHF \(formatted)"
    }

    private func formatPercent(_ value: Double) -> String {
        let formatted = Self.percentFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
        return "\(formatted) %"
    }

    private func formatCompactAxisValue(_ value: Double) -> String {
        Self.axisCompactFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }

    private func axisLabel(for date: Date, range: PerformanceRange) -> String {
        switch range {
        case .fiveYear, .max:
            return Self.longAxisDateFormatter.string(from: date)
        default:
            return Self.shortAxisDateFormatter.string(from: date)
        }
    }

    #if canImport(Charts)
        private func redesignedHoverPoint(_ points: [PerformancePoint], proxy: ChartProxy, geo: GeometryProxy, location: CGPoint) -> PerformancePoint? {
            guard let plotAnchor = proxy.plotFrame else { return nil }
            let plotFrame = geo[plotAnchor]
            guard plotFrame.contains(location), !points.isEmpty else { return nil }
            let xPosition = location.x - plotFrame.origin.x
            guard let date = proxy.value(atX: xPosition, as: Date.self) else { return nil }
            return points.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
        }
    #endif

    private func redesignedHoverLabel(for point: PerformancePoint) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(formatCurrencyDetailed(point.totalValueChf))
                .font(.caption2.weight(.semibold))
                .foregroundColor(DSColor.textPrimary)
            Text(Self.dateFormatter.string(from: point.date))
                .font(.caption2)
                .foregroundColor(DSColor.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(DSColor.surface))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(DSColor.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
    }

    private func redesignedDomain(_ points: [PerformancePoint]) -> ClosedRange<Date> {
        guard let first = points.first?.date, let last = points.last?.date else {
            let today = Calendar.current.startOfDay(for: Date())
            return today ... today
        }
        if first == last {
            let calendar = Calendar.current
            let start = calendar.date(byAdding: .day, value: -1, to: first) ?? first
            let end = calendar.date(byAdding: .day, value: 1, to: last) ?? last
            return start ... end
        }
        return first ... last
    }

    private func redesignedYDomain(_ points: [PerformancePoint]) -> ClosedRange<Double> {
        guard !points.isEmpty else { return 0 ... 1 }
        let values = points.map(\.totalValueChf)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 0
        let span = max(maxValue - minValue, 1)
        let padding = span * 0.15
        let lower = minValue - padding
        let upper = maxValue + padding
        return lower ... upper
    }

    private func reload() {
        isLoading = true
        DispatchQueue.global().async {
            let data = dbManager.listPortfolioValueHistory()
            DispatchQueue.main.async {
                rows = data
                isLoading = false
            }
        }
    }

    private func formatValue(_ value: Double) -> String {
        let formatted = Self.valueFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
        return "CHF \(formatted)"
    }

    private func displayDate(for storedDate: Date) -> Date {
        let utc = TimeZone(secondsFromGMT: 0) ?? .current
        let calendar = Calendar(identifier: .gregorian)
        var comps = calendar.dateComponents(in: utc, from: storedDate)
        comps.timeZone = TimeZone.current
        comps.hour = 0
        comps.minute = 0
        comps.second = 0
        return calendar.date(from: comps) ?? storedDate
    }
}

#if DEBUG
    struct HistoricPerformanceView_Previews: PreviewProvider {
        static var previews: some View {
            let manager = DatabaseManager()
            HistoricPerformanceView()
                .environmentObject(manager)
        }
    }
#endif
