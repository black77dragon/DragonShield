import SwiftUI
#if canImport(Charts)
    import Charts
#endif

private enum PerformanceEventType: String, CaseIterable, Identifiable {
    case inflow = "inflow"
    case outflow = "outflow"
    case market = "market"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .inflow:
            return "Inflow"
        case .outflow:
            return "Outflow"
        case .market:
            return "Market"
        }
    }

    var color: Color {
        switch self {
        case .inflow:
            return DSColor.accentSuccess
        case .outflow:
            return DSColor.accentError
        case .market:
            return DSColor.accentWarning
        }
    }

    static func from(_ value: String) -> PerformanceEventType {
        PerformanceEventType(rawValue: value.lowercased()) ?? .market
    }
}

struct HistoricPerformanceView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var rows: [PortfolioValueHistoryRow] = []
    @State private var events: [PerformanceEventRow] = []
    @State private var isLoading = false
    @State private var selectedRange: PerformanceRange = .sixMonth
    @State private var redesignedHoveredPoint: PerformancePoint? = nil
    @State private var hoveredEvent: PerformanceEventRow? = nil
    @State private var showingDataManager = false
    @State private var showingEventEditor = false
    @State private var editingEvent: PerformanceEventRow? = nil
    @State private var deleteEventTarget: PerformanceEventRow? = nil

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

    private struct PerformanceEventMarker: Identifiable {
        let event: PerformanceEventRow
        let date: Date
        let yValue: Double

        var id: Int { event.id }
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

    private let chartHeight: CGFloat = 300

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
            } else {
                if rows.isEmpty {
                    Text("No daily values recorded yet.")
                        .foregroundColor(.secondary)
                } else {
                    redesignedSection
                    tableSection
                        .padding(.top, 24)
                }
                eventsSection
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
        .sheet(isPresented: $showingEventEditor, onDismiss: loadEvents) {
            HistoricPerformanceEventEditor(existing: editingEvent) {
                loadEvents()
            }
            .environmentObject(dbManager)
        }
        .alert("Delete event?", isPresented: Binding(get: { deleteEventTarget != nil }, set: { if !$0 { deleteEventTarget = nil } })) {
            Button("Delete", role: .destructive) { deleteEvent() }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let target = deleteEventTarget {
                Text("Delete the event on \(Self.dateFormatter.string(from: displayDate(for: target.eventDate)))? This cannot be undone.")
            }
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
            hoveredEvent = nil
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
                let referenceDate = Calendar.current.startOfDay(for: Date())
                let rangeEvents = filteredEvents(events, for: selectedRange, referenceDate: referenceDate)
                let domainEvents = rangeEvents.filter {
                    let date = displayDate(for: $0.eventDate)
                    return date >= domain.lowerBound && date <= domain.upperBound
                }
                let eventMarkers = eventMarkers(for: domainEvents, yDomain: yDomain)

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
                    if let hoveredEvent {
                        let type = PerformanceEventType.from(hoveredEvent.eventType)
                        RuleMark(
                            x: .value("Event", displayDate(for: hoveredEvent.eventDate))
                        )
                        .foregroundStyle(type.color.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                    ForEach(eventMarkers) { marker in
                        let type = PerformanceEventType.from(marker.event.eventType)
                        let isHovered = marker.event.id == hoveredEvent?.id
                        PointMark(
                            x: .value("Event Date", marker.date),
                            y: .value("Event Position", marker.yValue)
                        )
                        .symbolSize(isHovered ? 110 : 70)
                        .foregroundStyle(type.color)
                        .annotation(position: .bottom, alignment: .leading) {
                            if isHovered {
                                eventHoverLabel(for: marker.event)
                            }
                        }
                    }
                    if let highlighted = redesignedHoveredPoint, hoveredEvent == nil {
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
                                        let eventHover = redesignedHoverEvent(eventMarkers, proxy: proxy, geo: geo, location: location)
                                        hoveredEvent = eventHover
                                        if eventHover == nil {
                                            redesignedHoveredPoint = redesignedHoverPoint(points, proxy: proxy, geo: geo, location: location)
                                        } else {
                                            redesignedHoveredPoint = nil
                                        }
                                    case .ended:
                                        redesignedHoveredPoint = nil
                                        hoveredEvent = nil
                                    }
                                }
                            #else
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let eventHover = redesignedHoverEvent(eventMarkers, proxy: proxy, geo: geo, location: value.location)
                                            hoveredEvent = eventHover
                                            if eventHover == nil {
                                                redesignedHoveredPoint = redesignedHoverPoint(points, proxy: proxy, geo: geo, location: value.location)
                                            } else {
                                                redesignedHoveredPoint = nil
                                            }
                                        }
                                        .onEnded { _ in
                                            redesignedHoveredPoint = nil
                                            hoveredEvent = nil
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

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Event Table")
                    .font(.headline)
                    .foregroundColor(DSColor.textPrimary)
                Spacer()
                Button {
                    editingEvent = nil
                    showingEventEditor = true
                } label: {
                    Label("Add Event", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            if events.isEmpty {
                Text("No events recorded yet.")
                    .foregroundColor(DSColor.textSecondary)
            } else {
                eventTableHeader
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(sortedEvents) { event in
                            eventRowView(event)
                            Divider()
                                .overlay(DSColor.border)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .padding(16)
        .background(DSColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DSColor.border, lineWidth: 1))
    }

    private var eventTableHeader: some View {
        HStack {
            Text("Date")
                .frame(width: 120, alignment: .leading)
            Text("Type")
                .frame(width: 110, alignment: .leading)
            Text("Short Description")
                .frame(width: 220, alignment: .leading)
            Text("Long Description")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("")
                .frame(width: 120, alignment: .trailing)
        }
        .font(.caption)
        .foregroundColor(DSColor.textSecondary)
    }

    private var sortedEvents: [PerformanceEventRow] {
        events.sorted {
            if $0.eventDate != $1.eventDate {
                return $0.eventDate > $1.eventDate
            }
            return $0.id > $1.id
        }
    }

    private func eventRowView(_ event: PerformanceEventRow) -> some View {
        let type = PerformanceEventType.from(event.eventType)
        let longDesc = event.longDescription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasLongDesc = !longDesc.isEmpty

        return HStack {
            Text(Self.dateFormatter.string(from: displayDate(for: event.eventDate)))
                .frame(width: 120, alignment: .leading)
            eventTypeChip(type)
                .frame(width: 110, alignment: .leading)
            Text(event.shortDescription)
                .frame(width: 220, alignment: .leading)
                .lineLimit(1)
                .help(event.shortDescription)
            Text(hasLongDesc ? longDesc : "-")
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .foregroundColor(hasLongDesc ? DSColor.textSecondary : DSColor.textTertiary)
                .help(hasLongDesc ? longDesc : "")
            HStack(spacing: 8) {
                Button {
                    editingEvent = event
                    showingEventEditor = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(.bordered)
                Button(role: .destructive) {
                    deleteEventTarget = event
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
            .frame(width: 120, alignment: .trailing)
        }
        .font(.system(size: 12))
    }

    private func eventTypeChip(_ type: PerformanceEventType) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(type.color)
                .frame(width: 8, height: 8)
            Text(type.label)
                .foregroundColor(DSColor.textPrimary)
        }
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

    private func filteredEvents(_ events: [PerformanceEventRow], for range: PerformanceRange, referenceDate: Date) -> [PerformanceEventRow] {
        let capped = events.filter { displayDate(for: $0.eventDate) <= referenceDate }
        guard let start = rangeStartDate(for: range, referenceDate: referenceDate) else {
            return capped.isEmpty ? events : capped
        }
        let filtered = capped.filter { displayDate(for: $0.eventDate) >= start }
        if filtered.isEmpty {
            return capped.isEmpty ? events : capped
        }
        return filtered
    }

    private func eventMarkers(for events: [PerformanceEventRow], yDomain: ClosedRange<Double>) -> [PerformanceEventMarker] {
        guard !events.isEmpty else { return [] }
        let span = max(yDomain.upperBound - yDomain.lowerBound, 1)
        let spacing = max(span * 0.045, 1)
        let topMargin = max(span * 0.06, 1)
        let sorted = events.sorted {
            if $0.eventDate != $1.eventDate { return $0.eventDate < $1.eventDate }
            return $0.id < $1.id
        }
        var dayOffsets: [Date: Int] = [:]
        let calendar = Calendar.current
        return sorted.map { event in
            let localDate = displayDate(for: event.eventDate)
            let dayKey = calendar.startOfDay(for: localDate)
            let index = dayOffsets[dayKey, default: 0]
            dayOffsets[dayKey] = index + 1
            let yValue = max(yDomain.lowerBound, yDomain.upperBound - topMargin - (Double(index) * spacing))
            return PerformanceEventMarker(event: event, date: localDate, yValue: yValue)
        }
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

        private func redesignedHoverEvent(_ markers: [PerformanceEventMarker], proxy: ChartProxy, geo: GeometryProxy, location: CGPoint) -> PerformanceEventRow? {
            guard let plotAnchor = proxy.plotFrame else { return nil }
            let plotFrame = geo[plotAnchor]
            guard plotFrame.contains(location), !markers.isEmpty else { return nil }
            let threshold: CGFloat = 20
            let thresholdSquared = threshold * threshold
            var closest: (event: PerformanceEventRow, distance: CGFloat)?

            for marker in markers {
                guard let xPos = proxy.position(forX: marker.date),
                      let yPos = proxy.position(forY: marker.yValue) else { continue }
                let x = plotFrame.origin.x + xPos
                let y = plotFrame.origin.y + yPos
                let dx = x - location.x
                let dy = y - location.y
                let dist = (dx * dx) + (dy * dy)
                if dist <= thresholdSquared {
                    if closest == nil || dist < closest?.distance ?? .greatestFiniteMagnitude {
                        closest = (marker.event, dist)
                    }
                }
            }
            return closest?.event
        }
    #endif

    private func eventHoverLabel(for event: PerformanceEventRow) -> some View {
        let type = PerformanceEventType.from(event.eventType)
        return VStack(alignment: .leading, spacing: 2) {
            Text(event.shortDescription)
                .font(.caption2.weight(.semibold))
                .foregroundColor(DSColor.textPrimary)
            Text("\(type.label) - \(Self.dateFormatter.string(from: displayDate(for: event.eventDate)))")
                .font(.caption2)
                .foregroundColor(DSColor.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(DSColor.surface))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(DSColor.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
    }

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
            let eventData = dbManager.listPerformanceEvents()
            DispatchQueue.main.async {
                rows = data
                events = eventData
                isLoading = false
            }
        }
    }

    private func loadEvents() {
        DispatchQueue.global().async {
            let eventData = dbManager.listPerformanceEvents()
            DispatchQueue.main.async {
                events = eventData
            }
        }
    }

    private func deleteEvent() {
        guard let target = deleteEventTarget else { return }
        _ = dbManager.deletePerformanceEvent(id: target.id)
        deleteEventTarget = nil
        loadEvents()
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

private struct HistoricPerformanceEventEditor: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) private var dismiss
    let existing: PerformanceEventRow?
    let onSave: () -> Void

    @State private var selectedDate: Date
    @State private var selectedType: PerformanceEventType
    @State private var shortDescription: String
    @State private var longDescription: String
    @State private var errorMessage: String? = nil

    init(existing: PerformanceEventRow?, onSave: @escaping () -> Void) {
        self.existing = existing
        self.onSave = onSave
        let initialDate = existing?.eventDate ?? Date()
        _selectedDate = State(initialValue: initialDate)
        _selectedType = State(initialValue: PerformanceEventType.from(existing?.eventType ?? ""))
        _shortDescription = State(initialValue: existing?.shortDescription ?? "")
        _longDescription = State(initialValue: existing?.longDescription ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existing == nil ? "Add Performance Event" : "Edit Performance Event")
                .font(.title2)
                .bold()

            DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                #if os(macOS)
                    .datePickerStyle(.field)
                #else
                    .datePickerStyle(.compact)
                #endif

            Picker("Type", selection: $selectedType) {
                ForEach(PerformanceEventType.allCases) { item in
                    Text(item.label).tag(item)
                }
            }
            .pickerStyle(.segmented)

            TextField("Short description", text: $shortDescription)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 360)

            VStack(alignment: .leading, spacing: 6) {
                Text("Long description")
                    .font(.caption)
                    .foregroundColor(DSColor.textSecondary)
                TextEditor(text: $longDescription)
                    .frame(minHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(DSColor.border, lineWidth: 1)
                    )
            }

            if let msg = errorMessage {
                Text(msg)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(minWidth: 480)
    }

    private func save() {
        let trimmedShort = shortDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedShort.isEmpty {
            errorMessage = "Enter a short description."
            return
        }
        let trimmedLong = longDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDate = storageDate(for: selectedDate)
        let longValue = trimmedLong.isEmpty ? nil : trimmedLong

        let ok: Bool
        if let existing {
            ok = dbManager.updatePerformanceEvent(
                id: existing.id,
                date: normalizedDate,
                type: selectedType.rawValue,
                shortDescription: trimmedShort,
                longDescription: longValue
            )
        } else {
            ok = dbManager.createPerformanceEvent(
                date: normalizedDate,
                type: selectedType.rawValue,
                shortDescription: trimmedShort,
                longDescription: longValue
            ) != nil
        }

        if ok {
            onSave()
            dismiss()
        } else {
            errorMessage = "Failed to save event."
        }
    }

    private func storageDate(for date: Date) -> Date {
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = TimeZone.current
        let comps = localCalendar.dateComponents([.year, .month, .day], from: date)
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        var utcComps = DateComponents()
        utcComps.year = comps.year
        utcComps.month = comps.month
        utcComps.day = comps.day
        utcComps.hour = 0
        utcComps.minute = 0
        utcComps.second = 0
        utcComps.timeZone = utcCalendar.timeZone
        return utcCalendar.date(from: utcComps) ?? date
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
