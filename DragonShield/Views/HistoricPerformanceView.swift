import SwiftUI
#if canImport(Charts)
    import Charts
#endif

struct HistoricPerformanceView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var rows: [PortfolioValueHistoryRow] = []
    @State private var isLoading = false
    @State private var timeScale: TimeScale = .daily
    @State private var showingDataManager = false
    @State private var hoveredPoint: PerformancePoint? = nil
    @State private var autoScaleOnAppear = true
    @AppStorage("historicPerformance.chartScale") private var chartScale: Double = 1.2
    @AppStorage("historicPerformance.yAxisScale") private var yAxisScale: Double = 1.0
    @AppStorage("historicPerformance.yAxisMinEnabled") private var yAxisMinEnabled = false
    @AppStorage("historicPerformance.yAxisMinValue") private var yAxisMinValue: Double = 0
    @AppStorage("historicPerformance.yAxisMaxEnabled") private var yAxisMaxEnabled = false
    @AppStorage("historicPerformance.yAxisMaxValue") private var yAxisMaxValue: Double = 0

    private enum TimeScale: String, CaseIterable, Identifiable {
        case daily
        case monthly

        var id: String { rawValue }
        var label: String {
            switch self {
            case .daily: return "Daily"
            case .monthly: return "Monthly"
            }
        }
    }

    private struct PerformancePoint: Identifiable {
        let date: Date
        let totalValueChf: Double

        var id: Date { date }
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

    private static let axisInputFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = false
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()

    private static let axisValueFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.groupingSeparator = "'"
        f.decimalSeparator = "."
        f.minimumFractionDigits = 3
        f.maximumFractionDigits = 3
        return f
    }()

    private let chartHeight: CGFloat = 240
    private let chartMinWidth: CGFloat = 640
    private let dailyPointSpacing: CGFloat = 18
    private let monthlyPointSpacing: CGFloat = 36
    private let chartTodayAnchor = "historicPerformance.chart.today"
    private let yAxisWidth: CGFloat = 108

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
                Picker("Time Scale", selection: $timeScale) {
                    ForEach(TimeScale.allCases) { scale in
                        Text(scale.label).tag(scale)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)
                .onChange(of: timeScale) { _, _ in hoveredPoint = nil }
                HStack(spacing: 12) {
                    Toggle("Custom Y-Min", isOn: $yAxisMinEnabled)
                    TextField("Min CHF", value: $yAxisMinValue, formatter: Self.axisInputFormatter)
                        .frame(width: 140)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!yAxisMinEnabled)
                    Toggle("Custom Y-Max", isOn: $yAxisMaxEnabled)
                    TextField("Max CHF", value: $yAxisMaxValue, formatter: Self.axisInputFormatter)
                        .frame(width: 140)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!yAxisMaxEnabled)
                    Button("Auto-Scale Y") { autoScaleYAxis() }
                        .buttonStyle(.bordered)
                }
                HStack(spacing: 12) {
                    Text("Timeline Scale")
                    Slider(value: $chartScale, in: 0.4 ... 3, step: 0.1)
                        .frame(width: 180)
                    Text("\(chartScale, specifier: "%.1f")x")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 12) {
                    Text("Y Scale")
                    Slider(value: $yAxisScale, in: 0.5 ... 2.5, step: 0.1)
                        .frame(width: 180)
                    Text("\(yAxisScale, specifier: "%.1f")x")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                chartSection
                    .padding(.top, 16)
                tableSection
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

    @ViewBuilder
    private var chartSection: some View {
        #if canImport(Charts)
            let points = chartPoints
            let domain = chartDomain(points)
            let today = Calendar.current.startOfDay(for: Date())
            let todayLineValue = todayValue(points)
            let yDomain = chartYDomain(points)
            let yAxisTicks = yAxisTickValues(for: yDomain)
            GeometryReader { geo in
                ScrollViewReader { scrollProxy in
                    HStack(spacing: 0) {
                        yAxisView(domain: domain, yDomain: yDomain, today: today, yAxisTicks: yAxisTicks)
                            .frame(width: yAxisWidth, height: chartHeight)
                            .padding(.bottom, 4)
                        Rectangle()
                            .fill(DSColor.border)
                            .frame(width: 1, height: chartHeight)
                            .padding(.bottom, 4)
                        ScrollView(.horizontal, showsIndicators: true) {
                            chartView(points: points, domain: domain, yDomain: yDomain, today: today, todayLineValue: todayLineValue, yAxisTicks: yAxisTicks)
                                .frame(width: chartWidth(for: points, domain: domain, availableWidth: max(geo.size.width - yAxisWidth - 1, 0)), height: chartHeight)
                                .padding(.bottom, 4)
                        }
                        .scrollIndicators(.visible)
                    }
                    .background(DSColor.surface)
                    .overlay(Rectangle().stroke(DSColor.border, lineWidth: 1))
                    .onAppear {
                        DispatchQueue.main.async {
                            scrollProxy.scrollTo(chartTodayAnchor, anchor: .trailing)
                        }
                    }
                    .onChange(of: rows.count) { _, _ in
                        DispatchQueue.main.async {
                            scrollProxy.scrollTo(chartTodayAnchor, anchor: .trailing)
                        }
                    }
                    .onChange(of: timeScale) { _, _ in
                        DispatchQueue.main.async {
                            scrollProxy.scrollTo(chartTodayAnchor, anchor: .trailing)
                        }
                    }
                    .onChange(of: chartScale) { _, _ in
                        DispatchQueue.main.async {
                            scrollProxy.scrollTo(chartTodayAnchor, anchor: .trailing)
                        }
                    }
                }
            }
            .frame(height: chartHeight + 24)
        #else
            Text("Charts not available on this platform.")
                .foregroundColor(.secondary)
        #endif
    }

    private var tableSection: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Date")
                    .frame(width: 120, alignment: .leading)
                Text("Total Asset Value (CHF)")
                    .frame(width: 200, alignment: .trailing)
                Spacer()
            }
            .font(.caption)
            .foregroundColor(.secondary)

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
                    }
                }
            }
            .frame(maxHeight: 260)
        }
    }

    private func reload() {
        isLoading = true
        DispatchQueue.global().async {
            let data = dbManager.listPortfolioValueHistory()
            DispatchQueue.main.async {
                rows = data
                isLoading = false
                if autoScaleOnAppear {
                    yAxisMinEnabled = false
                    yAxisMaxEnabled = false
                    yAxisScale = 1.0
                    autoScaleOnAppear = false
                }
            }
        }
    }

    private func formatValue(_ value: Double) -> String {
        let formatted = Self.valueFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
        return "CHF \(formatted)"
    }

    private func formatAxisValue(_ value: Double) -> String {
        let millions = value / 1_000_000
        let formatted = Self.axisValueFormatter.string(from: NSNumber(value: millions)) ?? String(format: "%.3f", millions)
        return "mCHF \(formatted)"
    }

    #if canImport(Charts)
        @ViewBuilder
        private func todayAnchorView(proxy: ChartProxy, geo: GeometryProxy, today: Date) -> some View {
            if let plotAnchor = proxy.plotFrame,
               let xPosition = proxy.position(forX: today) {
                let plotFrame = geo[plotAnchor]
                Color.clear
                    .frame(width: 1, height: 1)
                    .position(x: plotFrame.origin.x + xPosition, y: plotFrame.maxY - 1)
                    .id(chartTodayAnchor)
            }
        }
    #endif

    private func buildChartPoints() -> [PerformancePoint] {
        switch timeScale {
        case .daily:
            return rows.map { row in
                PerformancePoint(date: displayDate(for: row.valueDate), totalValueChf: row.totalValueChf)
            }
            .sorted { $0.date < $1.date }
        case .monthly:
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
            let grouped = Dictionary(grouping: rows) { row -> DateComponents in
                var comps = calendar.dateComponents([.year, .month], from: row.valueDate)
                comps.day = 1
                return comps
            }
            return grouped.compactMap { comps, rowsInMonth in
                guard let monthDate = calendar.date(from: comps) else { return nil }
                let sorted = rowsInMonth.sorted { $0.valueDate < $1.valueDate }
                guard let last = sorted.last else { return nil }
                return PerformancePoint(date: displayDate(for: monthDate), totalValueChf: last.totalValueChf)
            }
            .sorted { $0.date < $1.date }
        }
    }

    private var chartPoints: [PerformancePoint] { buildChartPoints() }

    private func autoScaleYAxis() {
        let points = chartPoints
        guard let minValue = points.map(\.totalValueChf).min(),
              let maxValue = points.map(\.totalValueChf).max() else {
            return
        }
        let delta = maxValue - minValue
        let padding = delta * 0.1
        yAxisMinValue = minValue - padding
        yAxisMaxValue = maxValue + padding
        yAxisMinEnabled = true
        yAxisMaxEnabled = true
    }

    #if canImport(Charts)
        private func chartView(points: [PerformancePoint], domain: ClosedRange<Date>, yDomain: ClosedRange<Double>, today: Date, todayLineValue: Double?, yAxisTicks: [Double]) -> some View {
            Chart {
                ForEach(yAxisTicks, id: \.self) { tick in
                    RuleMark(y: .value("Grid", tick))
                        .foregroundStyle(Color.gray.opacity(0.2))
                }
                ForEach(points) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("CHF", point.totalValueChf)
                    )
                    .foregroundStyle(Color.accentColor)
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("CHF", point.totalValueChf)
                    )
                    .foregroundStyle(Color.accentColor)
                    .symbolSize(hoveredPoint?.id == point.id ? 70 : 40)
                    .annotation(position: .top, alignment: .center) {
                        if hoveredPoint?.id == point.id {
                            hoverLabel(for: point)
                        }
                    }
                }
                if let todayLineValue {
                    RuleMark(y: .value("Today", todayLineValue))
                        .foregroundStyle(Color.red)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                }
                RuleMark(x: .value("Today", today))
                    .foregroundStyle(Color.red)
                    .lineStyle(StrokeStyle(lineWidth: 3, dash: [6, 4]))
                    .annotation(position: .bottom, alignment: .center) {
                        Image(systemName: "triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
            }
            .chartXAxis {
                if timeScale == .daily {
                    let weekly = weeklyTickDates(domain: domain)
                    let ticks = uniqueSortedDates(weekly + [today])
                    AxisMarks(values: ticks) { value in
                        if let date = value.as(Date.self) {
                            let isToday = Calendar.current.isDate(date, inSameDayAs: today)
                            AxisGridLine()
                                .foregroundStyle(isToday ? Color.red.opacity(0.35) : Color.gray.opacity(0.2))
                            AxisTick()
                                .foregroundStyle(isToday ? Color.red : Color.gray.opacity(0.7))
                            AxisValueLabel {
                                if isToday {
                                    Text(Self.dateFormatter.string(from: date))
                                        .foregroundColor(.red)
                                        .fixedSize(horizontal: true, vertical: true)
                                } else {
                                    Text(Self.dateFormatter.string(from: date))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: true, vertical: true)
                                }
                            }
                        }
                    }
                } else {
                    AxisMarks(values: .stride(by: .month, count: 1)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(Self.dateFormatter.string(from: date))
                            }
                        }
                    }
                    AxisMarks(values: [today]) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.red.opacity(0.35))
                        AxisTick()
                            .foregroundStyle(Color.red)
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(Self.dateFormatter.string(from: date))
                                    .foregroundColor(.red)
                                    .fixedSize(horizontal: true, vertical: true)
                            }
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .chartXScale(domain: domain)
            .chartYScale(domain: yDomain)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        todayAnchorView(proxy: proxy, geo: geo, today: today)
                        Rectangle().fill(Color.clear).contentShape(Rectangle())
                            #if os(macOS)
                                .modifier(HoverTracking(points: points, proxy: proxy, geo: geo, onHover: { point in
                                    hoveredPoint = point
                                }))
                            #endif
                    }
                }
            }
        }

        private func yAxisView(domain: ClosedRange<Date>, yDomain: ClosedRange<Double>, today: Date, yAxisTicks: [Double]) -> some View {
            Chart {
                PointMark(
                    x: .value("Date", domain.lowerBound),
                    y: .value("CHF", yDomain.lowerBound)
                )
                .opacity(0)
                PointMark(
                    x: .value("Date", domain.upperBound),
                    y: .value("CHF", yDomain.upperBound)
                )
                .opacity(0)
            }
            .chartXAxis {
                if timeScale == .daily {
                    let weekly = weeklyTickDates(domain: domain)
                    let ticks = uniqueSortedDates(weekly + [today])
                    AxisMarks(values: ticks) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(Self.dateFormatter.string(from: date))
                                    .foregroundColor(.clear)
                                    .fixedSize(horizontal: true, vertical: true)
                            }
                        }
                    }
                } else {
                    AxisMarks(values: .stride(by: .month, count: 1)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(Self.dateFormatter.string(from: date))
                                    .foregroundColor(.clear)
                                    .fixedSize(horizontal: true, vertical: true)
                            }
                        }
                    }
                    AxisMarks(values: [today]) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(Self.dateFormatter.string(from: date))
                                    .foregroundColor(.clear)
                                    .fixedSize(horizontal: true, vertical: true)
                            }
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: yAxisTicks) { value in
                    AxisTick()
                    AxisValueLabel {
                        if let val = value.as(Double.self) {
                            Text(formatAxisValue(val))
                        }
                    }
                }
            }
            .chartXScale(domain: domain)
            .chartYScale(domain: yDomain)
        }

        private func yAxisTickValues(for domain: ClosedRange<Double>) -> [Double] {
            let span = max(domain.upperBound - domain.lowerBound, 1)
            let targetTickCount = 5
            let rawStep = span / Double(max(targetTickCount - 1, 1))
            let step = niceAxisStep(rawStep)
            if !step.isFinite || step <= 0 {
                return [domain.lowerBound, domain.upperBound].sorted()
            }
            let start = ceil(domain.lowerBound / step) * step
            let end = floor(domain.upperBound / step) * step
            var ticks: [Double] = []
            var value = start
            var guardCount = 0
            while value <= end + (step * 0.5), guardCount < 12 {
                ticks.append(value)
                value += step
                guardCount += 1
            }
            if ticks.isEmpty {
                return [domain.lowerBound, domain.upperBound].sorted()
            }
            if ticks.count == 1 {
                let expanded = [domain.lowerBound, ticks[0], domain.upperBound]
                return Array(Set(expanded)).sorted()
            }
            return ticks
        }

        private func niceAxisStep(_ value: Double) -> Double {
            guard value.isFinite, value > 0 else { return 1 }
            let exponent = floor(log10(value))
            let fraction = value / pow(10, exponent)
            let niceFraction: Double
            if fraction <= 1 {
                niceFraction = 1
            } else if fraction <= 2 {
                niceFraction = 2
            } else if fraction <= 5 {
                niceFraction = 5
            } else {
                niceFraction = 10
            }
            return niceFraction * pow(10, exponent)
        }
    #endif

    private func hoverLabel(for point: PerformancePoint) -> some View {
        Text(formatValue(point.totalValueChf))
            .font(.caption2)
            .foregroundColor(DSColor.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(DSColor.surface))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(DSColor.border, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
    }

    private func chartWidth(for points: [PerformancePoint], domain: ClosedRange<Date>, availableWidth: CGFloat) -> CGFloat {
        let baseSpacing = timeScale == .daily ? dailyPointSpacing : monthlyPointSpacing
        let spacing = baseSpacing * CGFloat(chartScale)
        let unitCount = max(1, timeScale == .daily ? daysBetween(domain.lowerBound, domain.upperBound) : monthsBetween(domain.lowerBound, domain.upperBound))
        let targetWidth = CGFloat(unitCount) * spacing + 140
        let scaledWidth = availableWidth * CGFloat(chartScale)
        let minimumWidth = max(availableWidth, max(chartMinWidth, max(targetWidth, scaledWidth)))
        if points.isEmpty {
            return max(minimumWidth, chartMinWidth)
        }
        return minimumWidth
    }

    private func daysBetween(_ start: Date, _ end: Date) -> Int {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        return max(calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0, 1)
    }

    private func monthsBetween(_ start: Date, _ end: Date) -> Int {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.month], from: start, to: end)
        return max(comps.month ?? 0, 1)
    }

    #if canImport(Charts) && os(macOS)
        private struct HoverTracking: ViewModifier {
            let points: [PerformancePoint]
            let proxy: ChartProxy
            let geo: GeometryProxy
            let onHover: (PerformancePoint?) -> Void

            func body(content: Content) -> some View {
                if #available(macOS 13.0, *) {
                    content.onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            onHover(updateHover(location))
                        case .ended:
                            onHover(nil)
                        }
                    }
                } else {
                    content.onHover { isHovering in
                        if !isHovering {
                            onHover(nil)
                        }
                    }
                }
            }

            private func updateHover(_ location: CGPoint) -> PerformancePoint? {
                guard let plotAnchor = proxy.plotFrame else { return nil }
                let plotFrame = geo[plotAnchor]
                guard plotFrame.contains(location), !points.isEmpty else { return nil }
                let xPosition = location.x - plotFrame.origin.x
                guard let date = proxy.value(atX: xPosition, as: Date.self) else { return nil }
                return points.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
            }
        }
    #endif

    private func chartDomain(_ points: [PerformancePoint]) -> ClosedRange<Date> {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        let today = calendar.startOfDay(for: Date())
        var minStart = calendar.date(byAdding: .weekOfYear, value: -8, to: today) ?? today
        if let weekStart = calendar.dateInterval(of: .weekOfYear, for: minStart)?.start {
            minStart = weekStart
        }

        var lower = minStart
        if let first = points.first?.date, first < lower { lower = first }

        var upper = calendar.date(byAdding: .weekOfYear, value: 3, to: today) ?? today
        if let last = points.last?.date, last > upper { upper = last }

        if lower > upper { lower = upper }
        return lower ... upper
    }

    private func todayValue(_ points: [PerformancePoint]) -> Double? {
        let today = Calendar.current.startOfDay(for: Date())
        if let exact = points.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            return exact.totalValueChf
        }
        let prior = points.filter { $0.date <= today }.sorted { $0.date < $1.date }.last
        return prior?.totalValueChf
    }

    private func chartYDomain(_ points: [PerformancePoint]) -> ClosedRange<Double> {
        guard !points.isEmpty else { return 0 ... 1 }
        let values = points.map { $0.totalValueChf }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 0
        let span = max(maxValue - minValue, 1)
        let center = (minValue + maxValue) / 2
        let paddedSpan = span * 1.2
        let scaledSpan = max(paddedSpan * yAxisScale, 1)

        var lower = center - (scaledSpan / 2)
        var upper = center + (scaledSpan / 2)

        if yAxisMinEnabled { lower = yAxisMinValue }
        if yAxisMaxEnabled { upper = yAxisMaxValue }

        if upper <= lower {
            if yAxisMinEnabled && !yAxisMaxEnabled {
                upper = lower + max(scaledSpan * 0.1, 1)
            } else if !yAxisMinEnabled && yAxisMaxEnabled {
                lower = upper - max(scaledSpan * 0.1, 1)
            } else {
                upper = lower + max(scaledSpan * 0.1, 1)
            }
        }
        return lower ... upper
    }

    private func weeklyTickDates(domain: ClosedRange<Date>) -> [Date] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        let start = calendar.startOfDay(for: domain.lowerBound)
        let end = calendar.startOfDay(for: domain.upperBound)
        let weekday = calendar.component(.weekday, from: start)
        let daysToAdd = (calendar.firstWeekday - weekday + 7) % 7
        var cursor = calendar.date(byAdding: .day, value: daysToAdd, to: start) ?? start
        var dates: [Date] = []
        while cursor <= end {
            dates.append(cursor)
            cursor = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) ?? cursor.addingTimeInterval(7 * 86_400)
        }
        return dates
    }

    private func uniqueSortedDates(_ dates: [Date]) -> [Date] {
        let sorted = dates.sorted()
        var result: [Date] = []
        for date in sorted {
            if let last = result.last, Calendar.current.isDate(last, inSameDayAs: date) { continue }
            result.append(date)
        }
        return result
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
