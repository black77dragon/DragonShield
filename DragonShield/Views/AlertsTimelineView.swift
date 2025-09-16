import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct AlertsTimelineView: View {
    var onOpen: ((Int) -> Void)? = nil
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var forwardDays: Int = 90
    @State private var severityFilter: String = "all" // all|info|warning|critical
    @State private var selectedAlertId: Int? = nil
    @State private var info: String? = nil
    @State private var triggerTypes: [AlertTriggerTypeRow] = []
    @State private var selectedTypes: Set<String> = []

    private var minDate: Date { Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date() }
    private var maxDate: Date { Calendar.current.date(byAdding: .day, value: forwardDays, to: Date()) ?? Date() }
    private var todayCET: Date {
        let tz = TimeZone(identifier: "Europe/Zurich") ?? .current
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.timeZone = tz; df.dateFormat = "yyyy-MM-dd"
        let ymd = df.string(from: Date())
        return df.date(from: ymd) ?? Date()
    }
    private var todayShortLabel: String {
        let tz = TimeZone(identifier: "Europe/Zurich") ?? .current
        let df = DateFormatter(); df.locale = Locale(identifier: "de_CH"); df.timeZone = tz; df.dateFormat = "d.M."
        return df.string(from: todayCET)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Picker("Ahead", selection: $forwardDays) {
                    Text("30d").tag(30)
                    Text("90d").tag(90)
                    Text("365d").tag(365)
                }.pickerStyle(.segmented).frame(width: 220)
                Picker("Severity", selection: $severityFilter) {
                    Text("All").tag("all")
                    Text("Info").tag("info")
                    Text("Warning").tag("warning")
                    Text("Critical").tag("critical")
                }.frame(width: 220)
                if !triggerTypes.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(triggerTypes, id: \.code) { t in
                                let isOn = selectedTypes.contains(t.code)
                                Button(action: {
                                    if isOn { selectedTypes.remove(t.code) } else { selectedTypes.insert(t.code) }
                                }) {
                                    Text(t.displayName)
                                        .font(.caption)
                                        .foregroundColor(isOn ? .white : .primary)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(isOn ? Color.accentColor : Color.gray.opacity(0.15)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxHeight: 28)
                    }
                    .frame(width: 320)
                }
                Spacer()
            }
            .padding(.horizontal, 4)
            .onAppear {
                let types = dbManager.listAlertTriggerTypes()
                triggerTypes = types
                selectedTypes = Set(types.map { $0.code })
            }

#if canImport(Charts)
            VStack(alignment: .leading, spacing: 8) {
                Text("Timeline").font(.headline)
                Chart {
                    contents()
                    // Vertical line for today
                    RuleMark(x: .value("Date", todayCET))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(Color.gray.opacity(0.6))
                }
                .chartXAxis {
                    AxisMarks(values: .automatic)
                    // Custom axis mark and label for today
                    AxisMarks(values: [todayCET]) { _ in
                        AxisGridLine().foregroundStyle(Color.gray.opacity(0.4))
                        AxisTick().foregroundStyle(Color.gray.opacity(0.8))
                        AxisValueLabel {
                            Text(todayShortLabel)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .chartXScale(domain: minDate ... maxDate)
                .chartLegend(position: .bottom, alignment: .center)
                .chartPlotStyle { plot in
                    plot.background(Color.white)
                }
                .id(forwardDays) // force redraw when range changes
                .frame(height: 260)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.15), lineWidth: 1))
#else
            Text("Charts not available on this platform.")
                .foregroundColor(.secondary)
#endif

            if let id = selectedAlertId, let row = dbManager.getAlert(id: id) {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Selected: \(row.name)").font(.headline)
                    Text("Severity: \(row.severity.rawValue.capitalized)")
                    Text("Type: \(row.triggerTypeCode)")
                    Text("Subject: \(subjectSummary(for: row))")
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.06)))
            }
            // Details of items in the current window (Recent + Upcoming)
            TimelineDetailsTable(items: buildItems(), onOpen: onOpen)
                .padding(.top, 8)
            if let msg = info { Text(msg).font(.caption).foregroundColor(.secondary) }
        }
        .padding(12)
    }

#if canImport(Charts)
    @ChartContentBuilder
    private func contents() -> some ChartContent {
        ForEach(Array(expandItems(buildItems()).enumerated()), id: \.offset) { _, e in
            PointMark(
                x: .value("Date", e.item.when),
                y: .value("Series", e.yCat)
            )
            .foregroundStyle(color(for: e.item.severity).opacity(e.item.series == "Upcoming" ? 0.5 : 0.9))
            .symbol(Circle())
            .symbolSize(e.item.series == "Upcoming" ? 70 : 60)
            .annotation(position: e.annotateTop ? .top : .bottom) { Text("(\(e.item.refIndex))").font(.caption2) }
        }
    }

    private func color(for severity: String) -> Color {
        switch severity.lowercased() {
        case "critical": return .red
        case "warning": return .orange
        default: return .blue
        }
    }

    private func dateOnly(_ ymd: String) -> Date? {
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.timeZone = TimeZone(secondsFromGMT: 0); df.dateFormat = "yyyy-MM-dd"
        return df.date(from: ymd)
    }
#endif
}

// (removed old cards layout)


#if canImport(Charts)
// MARK: - Data helpers and table
private struct TimelineItem: Identifiable, Hashable {
    let id: Int
    let refIndex: Int
    let when: Date
    let series: String // "Events" | "Upcoming"
    let alertId: Int
    let alertName: String
    let severity: String
}

private extension AlertsTimelineView {
    func buildItems() -> [TimelineItem] {
        let dfIso = ISO8601DateFormatter()
        // Cache alert types by id to avoid repeated DB lookups
        var typeCache: [Int: String] = [:]
        func typeOf(_ alertId: Int) -> String? {
            if let v = typeCache[alertId] { return v }
            if let a = dbManager.getAlert(id: alertId) { typeCache[alertId] = a.triggerTypeCode; return a.triggerTypeCode }
            return nil
        }

        let upcomingRaw = dbManager.listUpcomingDateAlerts(limit: 500)
            .filter { severityFilter == "all" || $0.severity == severityFilter }
            .filter { u in
                // Type filter (by alertId via cache)
                if selectedTypes.isEmpty { return true }
                if let code = typeOf(u.alertId) { return selectedTypes.contains(code) } else { return false }
            }
            .compactMap { u -> (Int, String, String, Date)? in
                guard let d = dateOnly(u.upcomingDate), d >= minDate && d <= maxDate else { return nil }
                return (u.alertId, u.alertName, u.severity, d)
            }
        let eventsRaw = dbManager.listAlertEvents(limit: 500)
            .filter { severityFilter == "all" || $0.severity == severityFilter }
            .filter { e in
                if selectedTypes.isEmpty { return true }
                if let code = typeOf(e.alertId) { return selectedTypes.contains(code) } else { return false }
            }
            .compactMap { e -> (Int, String, String, Date)? in
                guard let d = dfIso.date(from: e.occurredAt), d >= minDate && d <= maxDate else { return nil }
                return (e.alertId, e.alertName, e.severity, d)
            }
        var items: [TimelineItem] = []
        for (aid, name, sev, d) in eventsRaw { items.append(TimelineItem(id: items.count+1, refIndex: 0, when: d, series: "Events", alertId: aid, alertName: name, severity: sev)) }
        let eventIds = Set(eventsRaw.map { $0.0 })
        for (aid, name, sev, d) in upcomingRaw where !eventIds.contains(aid) { items.append(TimelineItem(id: items.count+1, refIndex: 0, when: d, series: "Upcoming", alertId: aid, alertName: name, severity: sev)) }
        items.sort { (a, b) in
            if a.when == b.when { return a.series < b.series } else { return a.when < b.when }
        }
        for i in 0..<items.count { items[i] = TimelineItem(id: items[i].id, refIndex: i+1, when: items[i].when, series: items[i].series, alertId: items[i].alertId, alertName: items[i].alertName, severity: items[i].severity) }
        return items
    }


    // Expand items that share the same (day, series) into alternating above/below lanes
    func expandItems(_ items: [TimelineItem]) -> [(item: TimelineItem, yCat: String, annotateTop: Bool)] {
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.timeZone = TimeZone(secondsFromGMT: 0); df.dateFormat = "yyyy-MM-dd"
        var out: [(TimelineItem, String, Bool)] = []
        let grouped = Dictionary(grouping: items) { (df.string(from: $0.when) + "|" + $0.series) }
        for (_, group) in grouped {
            for (idx, it) in group.enumerated() {
                let lane = (idx % 2 == 0) ? "+" : "-"
                let yCat = (idx == 0) ? it.series : (it.series + " " + lane)
                let annotateTop = (lane == "+")
                out.append((it, yCat, annotateTop))
            }
        }
        return out
    }

    private func subjectSummary(for alert: AlertRow) -> String {
        switch alert.scopeType {
        case .Instrument:
            let name = dbManager.getInstrumentName(id: alert.scopeId) ?? "Instrument #\(alert.scopeId)"
            return name
        case .PortfolioTheme:
            return dbManager.getPortfolioTheme(id: alert.scopeId)?.name ?? "Theme #\(alert.scopeId)"
        case .AssetClass:
            return dbManager.fetchAssetClassDetails(id: alert.scopeId)?.name ?? "AssetClass #\(alert.scopeId)"
        case .Portfolio:
            return dbManager.fetchPortfolios().first(where: { $0.id == alert.scopeId })?.name ?? "Portfolio #\(alert.scopeId)"
        case .Account:
            return dbManager.fetchAccountDetails(id: alert.scopeId)?.accountName ?? "Account #\(alert.scopeId)"
        case .Global:
            return "Global"
        case .MarketEvent:
            if let code = alert.subjectReference, let event = dbManager.getEventCalendar(code: code) {
                return "\(event.title) [\(code)]"
            }
            return alert.subjectReference ?? "Market Event"
        case .EconomicSeries:
            return alert.subjectReference ?? "Economic Series"
        case .CustomGroup:
            return alert.subjectReference ?? "Custom Group"
        case .NotApplicable:
            if let reference = alert.subjectReference, !reference.isEmpty { return reference }
            return "Not applicable"
        }
    }
}

private struct TimelineDetailsTable: View {
    let items: [TimelineItem]
    var onOpen: ((Int) -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Details").font(.headline)
            Table(items) {
                TableColumn("Ref") { Text("(\($0.refIndex))") }.width(40)
                TableColumn("When") { Text($0.when, style: .date) }.width(140)
                TableColumn("Series") { Text($0.series) }.width(90)
                TableColumn("Alert") { r in
                    let id = r.alertId
                    Button(action: { onOpen?(id) }) { Text(r.alertName) }
                        .buttonStyle(.plain)
                }
                TableColumn("Severity") { Text($0.severity.capitalized) }.width(100)
            }
            .frame(minHeight: 160)
        }
    }
}
#endif
