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
                }
                chartSection
                tableSection
            }
        }
        .padding(16)
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
            Chart {
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
                    .symbolSize(18)
                }
                if let todayLineValue {
                    RuleMark(y: .value("Today", todayLineValue))
                        .foregroundStyle(Color.red)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
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
                                .foregroundStyle(isToday ? Color.red.opacity(0.5) : Color.gray.opacity(0.2))
                            AxisTick()
                                .foregroundStyle(isToday ? Color.red : Color.gray.opacity(0.7))
                            AxisValueLabel {
                                Text(Self.dateFormatter.string(from: date))
                                    .foregroundColor(isToday ? .red : .secondary)
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
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let val = value.as(Double.self) {
                            Text(formatValue(val))
                        }
                    }
                }
            }
            .chartXScale(domain: domain)
            .chartYScale(domain: yDomain)
            .frame(height: 240)
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
            }
        }
    }

    private func formatValue(_ value: Double) -> String {
        let formatted = Self.valueFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
        return "CHF \(formatted)"
    }

    private func buildChartPoints() -> [PerformancePoint] {
        switch timeScale {
        case .daily:
            return rows.map { row in
                PerformancePoint(date: displayDate(for: row.valueDate), totalValueChf: row.totalValueChf)
            }
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

        var upper = today
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
        let padding = span * 0.06

        var lower = minValue - padding
        var upper = maxValue + padding

        if yAxisMinEnabled { lower = yAxisMinValue }
        if yAxisMaxEnabled { upper = yAxisMaxValue }

        if upper <= lower {
            if yAxisMinEnabled && !yAxisMaxEnabled {
                upper = lower + max(padding, 1)
            } else if !yAxisMinEnabled && yAxisMaxEnabled {
                lower = upper - max(padding, 1)
            } else {
                upper = lower + max(padding, 1)
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
