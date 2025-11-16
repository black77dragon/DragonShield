import SwiftUI
#if os(macOS)
    import AppKit
#endif
#if os(iOS)
    import UIKit
#endif

private let isoOutputFormatter: DateFormatter = {
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = TimeZone(secondsFromGMT: 0)
    df.dateFormat = "yyyy-MM-dd"
    return df
}()

private let displayDateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.locale = Locale(identifier: "de_CH")
    df.dateFormat = "dd.MM.yy"
    return df
}()

private func dateFromISO(_ value: String?) -> Date? {
    guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
    return isoOutputFormatter.date(from: raw)
}

private enum AlertColumn: String, CaseIterable {
    case enabled
    case name
    case severity
    case subject
    case triggerType
    case triggerDate
    case actions

    var title: String {
        switch self {
        case .enabled: return "Enabled"
        case .name: return "Name"
        case .severity: return "Severity"
        case .subject: return "Subject"
        case .triggerType: return "Type"
        case .triggerDate: return "Trigger Date"
        case .actions: return "Actions"
        }
    }

    var defaultWidth: CGFloat {
        switch self {
        case .enabled: return 70
        case .name: return 240
        case .severity: return 100
        case .subject: return 240
        case .triggerType: return 150
        case .triggerDate: return 140
        case .actions: return 170
        }
    }

    var minWidth: CGFloat {
        switch self {
        case .enabled: return 50
        case .name: return 160
        case .severity: return 70
        case .subject: return 160
        case .triggerType: return 120
        case .triggerDate: return 110
        case .actions: return 150
        }
    }

    var maxWidth: CGFloat {
        switch self {
        case .enabled: return 160
        case .name: return 1000
        case .severity: return 220
        case .subject: return 1000
        case .triggerType: return 500
        case .triggerDate: return 320
        case .actions: return 320
        }
    }

    var headerAlignment: Alignment {
        switch self {
        case .enabled: return .center
        case .severity: return .center
        case .triggerDate: return .center
        case .actions: return .leading
        default: return .leading
        }
    }

    var cellAlignment: Alignment {
        switch self {
        case .enabled: return .center
        case .severity: return .center
        case .triggerDate: return .center
        case .actions: return .leading
        default: return .leading
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .enabled: return 6
        case .actions: return 6
        default: return 8
        }
    }
}

struct AlertsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var alertRows: [AlertListRow] = []
    @State private var alertSortField: AlertSortField = .name
    @State private var alertSortAscending: Bool = true
    @State private var nearAlertIds: Set<Int> = []
    @State private var exceededAlertIds: Set<Int> = []
    @State private var triggerTypes: [AlertTriggerTypeRow] = []
    @State private var allTags: [TagRow] = []
    @State private var includeDisabled = true
    @State private var error: String?
    @State private var info: String?

    @State private var editing: AlertRow? = nil
    @State private var confirmDelete: AlertListRow? = nil
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""

    // 0=Alerts, 1=Timeline, 2=Events View, 3=Threshold Events
    @State private var page: Int = 0
    @State private var showTriggerTypes: Bool = false

    @AppStorage("alertsTableColumnWidths") private var storedAlertsTableColumnWidths: Data = .init()
    @State private var alertColumnWidths: [AlertColumn: CGFloat] = [:]
    @State private var draftAlertColumnWidths: [AlertColumn: CGFloat] = [:]
    @State private var dragStartAlertColumnWidths: [AlertColumn: CGFloat] = [:]
    @State private var didRestoreAlertColumnWidths = false

    private var sortedAlertRows: [AlertListRow] {
        alertRows.sorted { lhs, rhs in
            if lhs.id == rhs.id { return false }
            let ascending = alertSortAscending
            switch alertSortField {
            case .enabled:
                if lhs.enabled == rhs.enabled {
                    return tieBreak(lhs, rhs, ascending: ascending)
                }
                return ascending ? (lhs.enabled && !rhs.enabled) : (!lhs.enabled && rhs.enabled)
            case .name:
                return compare(lhs.name, rhs.name, ascending: ascending, lhsRow: lhs, rhsRow: rhs)
            case .severity:
                return compare(lhs.severity, rhs.severity, ascending: ascending, lhsRow: lhs, rhsRow: rhs)
            case .subject:
                return compare(lhs.subject, rhs.subject, ascending: ascending, lhsRow: lhs, rhsRow: rhs)
            case .triggerType:
                return compare(lhs.triggerType, rhs.triggerType, ascending: ascending, lhsRow: lhs, rhsRow: rhs)
            case .triggerDate:
                return compare(lhs.triggerDateSortKey, rhs.triggerDateSortKey, ascending: ascending, lhsRow: lhs, rhsRow: rhs)
            }
        }
    }

    private let alertResizeHandleWidth: CGFloat = 6

    private var alertsTableHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(AlertColumn.allCases.enumerated()), id: \.element) { _, column in
                headerCell(for: column)
                    .frame(width: width(for: column), alignment: column.headerAlignment)
                    .padding(.horizontal, column.horizontalPadding)
                resizeHandle(for: column)
            }
        }
        .font(.footnote)
        .foregroundColor(.secondary)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    @ViewBuilder
    private func headerCell(for column: AlertColumn) -> some View {
        switch column {
        case .enabled:
            sortHeader(column.title, field: .enabled, alignment: column.headerAlignment)
        case .name:
            sortHeader(column.title, field: .name, alignment: column.headerAlignment)
        case .severity:
            sortHeader(column.title, field: .severity, alignment: column.headerAlignment)
        case .subject:
            sortHeader(column.title, field: .subject, alignment: column.headerAlignment)
        case .triggerType:
            sortHeader(column.title, field: .triggerType, alignment: column.headerAlignment)
        case .triggerDate:
            sortHeader(column.title, field: .triggerDate, alignment: column.headerAlignment)
        case .actions:
            Text(column.title)
                .font(.footnote.bold())
                .frame(maxWidth: .infinity, alignment: column.headerAlignment)
        }
    }

    private func width(for column: AlertColumn) -> CGFloat {
        if let pending = draftAlertColumnWidths[column] {
            return pending
        }
        if let stored = alertColumnWidths[column] {
            return stored
        }
        return column.defaultWidth
    }

    private func clampedWidth(_ proposed: CGFloat, for column: AlertColumn) -> CGFloat {
        max(column.minWidth, min(column.maxWidth, proposed))
    }

    private func setWidth(_ width: CGFloat, for column: AlertColumn) {
        alertColumnWidths[column] = clampedWidth(width, for: column)
        persistAlertColumnWidths()
    }

    private func resizeHandle(for column: AlertColumn) -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.001))
            .frame(width: alertResizeHandleWidth, height: 22)
            .overlay(Rectangle().fill(Color.gray.opacity(0.25)).frame(width: 1))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                if dragStartAlertColumnWidths[column] == nil {
                    let initial = alertColumnWidths[column] ?? column.defaultWidth
                    dragStartAlertColumnWidths[column] = initial
                }
                let base = dragStartAlertColumnWidths[column] ?? column.defaultWidth
                let updated = clampedWidth(base + value.translation.width, for: column)
                draftAlertColumnWidths[column] = round(updated)
            }.onEnded { _ in
                if let pending = draftAlertColumnWidths[column] {
                    setWidth(pending, for: column)
                }
                draftAlertColumnWidths.removeValue(forKey: column)
                dragStartAlertColumnWidths.removeValue(forKey: column)
            })
            .onTapGesture(count: 2) {
                autoFit(column)
            }
            .padding(.vertical, 2)
    }

    private func resizeSpacer(for _: AlertColumn) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: alertResizeHandleWidth, height: 1)
    }

    private func autoFit(_ column: AlertColumn) {
        switch column {
        case .name:
            let padding: CGFloat = column.horizontalPadding * 2
            let maxWidth = sortedAlertRows.reduce(column.defaultWidth) { partial, row in
                let measured = measureText(row.name) + padding
                return max(partial, min(column.maxWidth, measured))
            }
            setWidth(maxWidth, for: column)
        case .subject:
            let padding: CGFloat = column.horizontalPadding * 2
            let maxWidth = sortedAlertRows.reduce(column.defaultWidth) { partial, row in
                let measured = measureText(row.subject) + padding
                return max(partial, min(column.maxWidth, measured))
            }
            setWidth(maxWidth, for: column)
        default:
            setWidth(column.defaultWidth, for: column)
        }
        draftAlertColumnWidths.removeValue(forKey: column)
        dragStartAlertColumnWidths.removeValue(forKey: column)
    }

    private func restoreAlertColumnWidths() {
        guard !didRestoreAlertColumnWidths else { return }
        didRestoreAlertColumnWidths = true
        var defaults = Dictionary(uniqueKeysWithValues: AlertColumn.allCases.map { ($0, $0.defaultWidth) })
        if !storedAlertsTableColumnWidths.isEmpty,
           let decoded = try? JSONDecoder().decode([String: Double].self, from: storedAlertsTableColumnWidths)
        {
            for (key, value) in decoded {
                guard let column = AlertColumn(rawValue: key) else { continue }
                defaults[column] = clampedWidth(CGFloat(value), for: column)
            }
        }
        alertColumnWidths = defaults
    }

    private func persistAlertColumnWidths() {
        var payload: [String: Double] = [:]
        for (column, width) in alertColumnWidths {
            payload[column.rawValue] = Double(width)
        }
        if let data = try? JSONEncoder().encode(payload) {
            storedAlertsTableColumnWidths = data
        }
    }

    private func measureText(_ text: String) -> CGFloat {
        #if os(macOS)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
            ]
            let nsText = text as NSString
            return ceil(nsText.size(withAttributes: attributes).width)
        #else
            let font = UIFont.systemFont(ofSize: UIFont.systemFontSize)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
            ]
            let nsText = text as NSString
            return ceil(nsText.size(withAttributes: attributes).width)
        #endif
    }

    private func alertRowView(_ row: AlertListRow, index: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(AlertColumn.allCases, id: \.self) { column in
                cell(for: column, row: row)
                    .frame(width: width(for: column), alignment: column.cellAlignment)
                    .padding(.horizontal, column.horizontalPadding)
                resizeSpacer(for: column)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground(for: index))
    }

    @ViewBuilder
    private func cell(for column: AlertColumn, row: AlertListRow) -> some View {
        switch column {
        case .enabled:
            Toggle("", isOn: enabledBinding(for: row))
                .labelsHidden()
        case .name:
            HStack(spacing: 6) {
                if exceededAlertIds.contains(row.alert.id) {
                    Text("‼️")
                } else if nearAlertIds.contains(row.alert.id) {
                    Text("⚠️")
                }
                Text(row.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .severity:
            Text(row.severity.capitalized)
                .frame(maxWidth: .infinity, alignment: .center)
        case .subject:
            Text(row.subject)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .triggerType:
            Text(row.triggerType)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .triggerDate:
            Text(row.triggerDateDisplay)
                .frame(maxWidth: .infinity, alignment: .center)
        case .actions:
            HStack(spacing: 8) {
                Button("Edit") { openEdit(row.alert) }
                    .buttonStyle(.link)
                Button("Delete", role: .destructive) { confirmDelete = row }
                    .buttonStyle(.link)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func enabledBinding(for row: AlertListRow) -> Binding<Bool> {
        Binding(
            get: { row.enabled },
            set: { value in
                _ = dbManager.updateAlert(row.alert.id, fields: ["enabled": value])
                load()
            }
        )
    }

    private func rowBackground(for index: Int) -> Color {
        let base = Color.gray.opacity(0.04)
        return index.isMultiple(of: 2) ? Color.clear : base
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                headerRow(alignment: .horizontal)
                headerRow(alignment: .stacked)
            }
            if let err = error { Text(err).foregroundColor(.red).font(.caption) }

            switch page {
            case 0:
                VStack(spacing: 0) {
                    alertsTableHeader
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(sortedAlertRows.enumerated()), id: \.element.id) { index, row in
                                alertRowView(row, index: index)
                                if index < sortedAlertRows.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                }
                .background(Color(nsColor: .textBackgroundColor))
                .frame(minHeight: 360)
                .overlay(alignment: .bottomLeading) {
                    Text(info ?? "Toggle enabled in table. Use Edit to adjust details. Params JSON must be valid.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            case 1:
                AlertsTimelineView(onOpen: { id in
                    openEditById(id)
                })
                .environmentObject(dbManager)
                .frame(minHeight: 420)
            case 2:
                EventsListView(onOpen: { id in openEditById(id) })
                    .environmentObject(dbManager)
                    .frame(minHeight: 480)
            default:
                ThresholdEventsView(onOpen: { id in openEditById(id) })
                    .environmentObject(dbManager)
                    .frame(minHeight: 480)
            }
        }
        .padding(16)
        .onAppear {
            restoreAlertColumnWidths()
            load()
        }
        .sheet(item: $editing) { item in
            AlertEditorView(alert: item,
                            triggerTypes: triggerTypes,
                            allTags: allTags,
                            onSave: { updated, tagIds in
                                if let _ = dbManager.getAlert(id: updated.id) {
                                    let ok = dbManager.updateAlert(updated.id, fields: fieldsDict(from: updated))
                                    let ok2 = dbManager.setAlertTags(alertId: updated.id, tagIds: Array(tagIds))
                                    if ok, ok2 { info = "Saved \(updated.name)"; error = nil } else { error = "Failed to save alert"; info = nil }
                                } else {
                                    if let created = dbManager.createAlert(updated) {
                                        let ok2 = dbManager.setAlertTags(alertId: created.id, tagIds: Array(tagIds))
                                        if ok2 { info = "Created \(created.name)"; error = nil } else { error = "Failed to link tags" }
                                    } else { error = "Failed to create alert (check JSON)"; info = nil }
                                }
                                load(); editing = nil
                            }, onCancel: { editing = nil })
                .environmentObject(dbManager)
                .frame(minWidth: 1000, minHeight: 720)
        }
        .navigationTitle("Alerts & Events")
        .frame(minWidth: 1100, minHeight: 700)
        .toast(isPresented: $showToast, message: toastMessage)
        .sheet(isPresented: $showTriggerTypes) {
            NavigationView {
                AlertTriggerTypeSettingsView()
                    .environmentObject(dbManager)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showTriggerTypes = false
                                triggerTypes = dbManager.listAlertTriggerTypes()
                            }
                        }
                    }
            }
            .frame(minWidth: 1100, minHeight: 680)
        }
        .alert(item: $confirmDelete) { row in
            Alert(
                title: Text("A disturbance in the Force?"),
                message: Text("Delete ‘\(row.name)’? This alert will be lost faster than Alderaan. This action cannot be undone."),
                primaryButton: .destructive(Text("Yes, execute Order 66")) {
                    performDelete(row)
                },
                secondaryButton: .cancel(Text("Do. Or do not. Cancel."))
            )
        }
    }

    private enum HeaderAlignment { case horizontal, stacked }

    @ViewBuilder
    private func headerRow(alignment: HeaderAlignment) -> some View {
        switch alignment {
        case .horizontal:
            HStack(spacing: 12) {
                pickerTabs
                Spacer(minLength: 8)
                headerActions
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .stacked:
            VStack(alignment: .leading, spacing: 8) {
                pickerTabs
                headerActions
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var pickerTabs: some View {
        Picker("", selection: $page) {
            Text("Alerts").tag(0)
            Text("Timeline").tag(1)
            Text("Events View").tag(2)
            Text("Threshold Events").tag(3)
        }
        .pickerStyle(.segmented)
        .frame(minWidth: 240)
        .layoutPriority(1)
    }

    @ViewBuilder
    private var headerActions: some View {
        HStack(spacing: 10) {
            if page == 0 {
                Toggle("Show disabled", isOn: $includeDisabled)
                    .onChange(of: includeDisabled) { _, _ in load() }
                Button("Edit Alert Types") { showTriggerTypes = true }
                Button("Add Alert") { openNew() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.67, green: 0.89, blue: 0.67))
                    .foregroundColor(.black)
            }
            Button("Close") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(Color.gray)
                .foregroundColor(.white)
                .keyboardShortcut("w", modifiers: .command)
                .help("Close")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private enum AlertSortField { case enabled, name, severity, subject, triggerType, triggerDate }

    @ViewBuilder
    private func sortHeader(_ title: String, field: AlertSortField, alignment: Alignment = .leading) -> some View {
        let isActive = alertSortField == field
        let arrowName = alertSortAscending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill"
        Button(action: { toggleSort(field) }) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.footnote.bold())
                    .foregroundColor(isActive ? .primary : .secondary)
                if isActive {
                    Image(systemName: arrowName)
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: alignment)
        }
        .buttonStyle(.plain)
    }

    private func toggleSort(_ field: AlertSortField) {
        if alertSortField == field {
            alertSortAscending.toggle()
        } else {
            alertSortField = field
            alertSortAscending = true
        }
    }

    private func compare(_ lhs: String, _ rhs: String, ascending: Bool, lhsRow: AlertListRow, rhsRow: AlertListRow) -> Bool {
        let comparison = lhs.localizedCaseInsensitiveCompare(rhs)
        if comparison == .orderedSame {
            return tieBreak(lhsRow, rhsRow, ascending: ascending)
        }
        return ascending ? (comparison == .orderedAscending) : (comparison == .orderedDescending)
    }

    private func tieBreak(_ lhs: AlertListRow, _ rhs: AlertListRow, ascending: Bool) -> Bool {
        let cmp = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        if cmp == .orderedSame {
            return ascending ? (lhs.id < rhs.id) : (lhs.id > rhs.id)
        }
        return ascending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
    }

    // MARK: - Formatting helpers

    private func triggerDateInfo(for row: AlertRow) -> (display: String, sortKey: String) {
        guard triggerTypeRequiresDate(row.triggerTypeCode) else { return ("", "") }
        guard let data = row.paramsJson.data(using: .utf8),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let dateStr = obj["date"] as? String, !dateStr.isEmpty,
              let date = isoOutputFormatter.date(from: dateStr) else { return ("", "") }
        let display = displayDateFormatter.string(from: date)
        let sortKey = isoOutputFormatter.string(from: date)
        return (display, sortKey)
    }

    private let defaultDateTriggerCodes: Set<String> = ["date", "calendar_event", "macro_indicator_threshold"]

    private func triggerTypeRequiresDate(_ code: String) -> Bool {
        if let requiresDate = triggerTypes.first(where: { $0.code == code })?.requiresDate {
            return requiresDate || defaultDateTriggerCodes.contains(code)
        }
        return defaultDateTriggerCodes.contains(code)
    }

    private func subjectDisplay(for row: AlertRow) -> String {
        switch row.scopeType {
        case .Instrument:
            return dbManager.getInstrumentName(id: row.scopeId) ?? "Instrument #\(row.scopeId)"
        case .PortfolioTheme:
            return dbManager.getPortfolioTheme(id: row.scopeId)?.name ?? "Theme #\(row.scopeId)"
        case .AssetClass:
            return dbManager.fetchAssetClassDetails(id: row.scopeId)?.name ?? "AssetClass #\(row.scopeId)"
        case .Account:
            return dbManager.fetchAccountDetails(id: row.scopeId)?.accountName ?? "Account #\(row.scopeId)"
        case .Portfolio:
            let name = dbManager.fetchPortfolios().first(where: { $0.id == row.scopeId })?.name
            return name ?? "Portfolio #\(row.scopeId)"
        case .Global:
            return "Global"
        case .MarketEvent:
            if let code = row.subjectReference, let event = dbManager.getEventCalendar(code: code) {
                return "\(event.title) [\(code)]"
            }
            return row.subjectReference ?? "Market Event"
        case .EconomicSeries:
            return row.subjectReference ?? "Economic Series"
        case .CustomGroup:
            return row.subjectReference ?? "Custom Group"
        case .NotApplicable:
            return row.subjectReference?.isEmpty == false ? row.subjectReference! : "Not applicable"
        }
    }

    private func load() {
        triggerTypes = dbManager.listAlertTriggerTypes()
        allTags = dbManager.listTags()
        let triggerDisplayLookup = Dictionary(uniqueKeysWithValues: triggerTypes.map { ($0.code, $0.displayName) })
        let fetched = dbManager.listAlerts(includeDisabled: includeDisabled)
        var near: Set<Int> = []
        var exceed: Set<Int> = []
        var display: [AlertListRow] = []
        for alert in fetched {
            if dbManager.isAlertExceeded(alert) {
                exceed.insert(alert.id)
            } else if dbManager.isAlertNear(alert) {
                near.insert(alert.id)
            }
            let subject = subjectDisplay(for: alert)
            let dateInfo = triggerDateInfo(for: alert)
            let triggerDisplay = triggerDisplayLookup[alert.triggerTypeCode] ?? alert.triggerTypeCode
            display.append(AlertListRow(alert: alert,
                                        subject: subject,
                                        triggerDisplayName: triggerDisplay,
                                        triggerDateDisplay: dateInfo.display,
                                        triggerDateSortKey: dateInfo.sortKey))
        }
        alertRows = display
        nearAlertIds = near
        exceededAlertIds = exceed
    }

    private func openNew() {
        let now = ISO8601DateFormatter().string(from: Date())
        editing = AlertRow(
            id: -1,
            name: "New Alert",
            enabled: true,
            severity: .info,
            scopeType: .Instrument,
            scopeId: 0,
            subjectReference: nil,
            triggerTypeCode: triggerTypes.first?.code ?? "price",
            paramsJson: "{}",
            nearValue: nil, nearUnit: nil,
            hysteresisValue: nil, hysteresisUnit: nil,
            cooldownSeconds: nil,
            muteUntil: nil,
            scheduleStart: nil,
            scheduleEnd: nil,
            notes: nil,
            createdAt: now,
            updatedAt: now
        )
    }

    private func openEdit(_ row: AlertRow) {
        if let fresh = dbManager.getAlert(id: row.id) { editing = fresh } else { editing = row }
    }

    private func openEditById(_ id: Int) {
        if let fresh = dbManager.getAlert(id: id) {
            editing = fresh
        }
    }

    private func performDelete(_ row: AlertListRow) {
        if dbManager.deleteAlert(id: row.alert.id) {
            info = nil
            toastMessage = "Alert deleted. May the Force rebalance your portfolio."
            showToast = true
        } else {
            error = "Delete failed"
        }
        load()
    }

    private func fieldsDict(from a: AlertRow) -> [String: Any?] {
        let storageScopeType = a.scopeType.storageScopeTypeValue
        let storageScopeId = a.scopeType.storageScopeIdValue(a.scopeId)
        return [
            "name": a.name,
            "enabled": a.enabled,
            "severity": a.severity.rawValue,
            "scope_type": storageScopeType,
            "scope_id": storageScopeId,
            "subject_type": a.scopeType.rawValue,
            "subject_reference": a.subjectReference,
            "trigger_type_code": a.triggerTypeCode,
            "params_json": a.paramsJson,
            "near_value": a.nearValue,
            "near_unit": a.nearUnit,
            "hysteresis_value": a.hysteresisValue,
            "hysteresis_unit": a.hysteresisUnit,
            "cooldown_seconds": a.cooldownSeconds,
            "mute_until": a.muteUntil,
            "schedule_start": a.scheduleStart,
            "schedule_end": a.scheduleEnd,
            "notes": a.notes,
        ]
    }
}

private struct AlertListRow: Identifiable, Hashable {
    let id: Int
    let alert: AlertRow
    let enabled: Bool
    let name: String
    let severity: String
    let subject: String
    let triggerType: String
    let triggerDateDisplay: String
    let triggerDateSortKey: String

    init(alert: AlertRow, subject: String, triggerDisplayName: String, triggerDateDisplay: String, triggerDateSortKey: String) {
        id = alert.id
        self.alert = alert
        enabled = alert.enabled
        name = alert.name
        severity = alert.severity.rawValue
        self.subject = subject
        triggerType = triggerDisplayName
        self.triggerDateDisplay = triggerDateDisplay
        self.triggerDateSortKey = triggerDateSortKey
    }
}

// MARK: - Events View (Configurable List)

private struct EventsListView: View {
    struct Configuration {
        enum Mode: String, CaseIterable { case upcoming, occurred, both }
        var defaultMode: Mode = .upcoming
        var allowedTriggerCodes: Set<String>? = nil
        var hideDatePickers: Bool = false
        var highlightThresholdDelta: Bool = false
        var includeHoldingAbsSnapshots: Bool = false
        var snapshotSeriesName: String? = nil
        var includeDisabledSnapshots: Bool = false
        var includeSeriesColumn: Bool = true
        var includeTriggerColumn: Bool = true
    }

    @EnvironmentObject var dbManager: DatabaseManager
    var onOpen: ((Int) -> Void)?
    var configuration: Configuration

    @State private var severity: String = "all" // all|info|warning|critical
    @State private var subjectType: AlertSubjectType? = nil // nil == All
    @State private var triggerTypes: [AlertTriggerTypeRow] = []
    @State private var selectedTypes: Set<String> = []
    @State private var mode: String
    @State private var fromDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var toDate: Date = Calendar.current.date(byAdding: .day, value: 60, to: Date()) ?? Date()
    @State private var search: String = ""
    @State private var allItems: [Row] = []
    @State private var items: [Row] = []
    #if os(macOS)
        @State private var sortColumn: EventsColumn = .when
        @State private var sortAscending: Bool = true
        private let columnWidthStorageKey: String
        @State private var columnWidths: [String: CGFloat] = [:]
        @State private var didRestoreColumnWidths = false
    #endif

    init(onOpen: ((Int) -> Void)? = nil,
         configuration: Configuration = .standard,
         columnWidthStorageKey: String = "eventsTableColumnWidths")
    {
        self.onOpen = onOpen
        self.configuration = configuration
        _mode = State(initialValue: configuration.defaultMode.rawValue)
        #if os(macOS)
            self.columnWidthStorageKey = columnWidthStorageKey
        #endif
    }

    private struct Row: Identifiable, Hashable {
        let id: Int
        let series: String // Upcoming | Events
        let when: Date
        let alertId: Int
        let name: String
        let severity: String
        let subjectType: AlertSubjectType
        let triggerTypeCode: String
        let triggerDisplayName: String
        let message: String?
        let thresholdDifferenceText: String?
        let thresholdDifferenceValue: Double?
        let thresholdDifferencePercent: Double?
    }

    #if os(macOS)
        private enum EventsColumn: String {
            case when
            case series
            case name
            case severity
            case subjectType
            case trigger
            case thresholdDelta
            case message

            var title: String {
                switch self {
                case .when: return "When"
                case .series: return "Series"
                case .name: return "Name"
                case .severity: return "Severity"
                case .subjectType: return "Subject Type"
                case .trigger: return "Trigger Family"
                case .thresholdDelta: return "Actual vs Threshold"
                case .message: return "Message"
                }
            }

            var defaultWidth: CGFloat {
                switch self {
                case .when: return 110
                case .series: return 90
                case .name: return 220
                case .severity: return 100
                case .subjectType: return 150
                case .trigger: return 150
                case .thresholdDelta: return 150
                case .message: return 220
                }
            }

            var minWidth: CGFloat {
                switch self {
                case .when: return 80
                case .series: return 70
                case .name: return 150
                case .severity: return 80
                case .subjectType: return 110
                case .trigger: return 110
                case .thresholdDelta: return 110
                case .message: return 150
                }
            }

            var maxWidth: CGFloat {
                switch self {
                case .when: return 180
                case .series: return 160
                case .name: return 480
                case .severity: return 200
                case .subjectType: return 320
                case .trigger: return 320
                case .thresholdDelta: return 220
                case .message: return 520
                }
            }

            var alignment: NSTextAlignment {
                switch self {
                case .series, .severity: return .center
                case .thresholdDelta: return .right
                default: return .left
                }
            }

            static func columns(includeThresholdDelta: Bool,
                                includeSeries: Bool,
                                includeTrigger: Bool) -> [EventsColumn]
            {
                var base: [EventsColumn] = [.when]
                if includeSeries {
                    base.append(.series)
                }
                base.append(contentsOf: [.name, .severity, .subjectType])
                if includeTrigger {
                    base.append(.trigger)
                }
                if includeThresholdDelta {
                    base.append(.thresholdDelta)
                }
                base.append(.message)
                return base
            }

            static func defaultWidths(for columns: [EventsColumn]) -> [String: CGFloat] {
                Dictionary(uniqueKeysWithValues: columns.map { ($0.rawValue, $0.defaultWidth) })
            }
        }

        private var columns: [EventsColumn] {
            EventsColumn.columns(includeThresholdDelta: configuration.highlightThresholdDelta,
                                 includeSeries: configuration.includeSeriesColumn,
                                 includeTrigger: configuration.includeTriggerColumn)
        }
    #endif

    var body: some View {
        VStack(spacing: 12) {
            ViewThatFits(in: .horizontal) {
                filtersRow(layout: .horizontal)
                filtersRow(layout: .stacked)
            }
            .onAppear {
                let types = dbManager.listAlertTriggerTypes()
                if let allowed = configuration.allowedTriggerCodes {
                    let filtered = types.filter { allowed.contains($0.code) }
                    triggerTypes = filtered
                    selectedTypes = allowed
                } else {
                    triggerTypes = types
                    selectedTypes = Set(types.map { $0.code })
                }
                load()
                #if os(macOS)
                    restoreColumnWidths()
                #endif
            }
            .onChange(of: severity) { _, _ in applyFilters() }
            .onChange(of: subjectType) { _, _ in applyFilters() }
            .onChange(of: selectedTypes) { _, _ in applyFilters() }
            .onChange(of: mode) { _, _ in applyFilters() }
            .onChange(of: fromDate) { _, _ in applyFilters() }
            .onChange(of: toDate) { _, _ in applyFilters() }
            .onChange(of: search) { _, _ in applyFilters() }
            #if os(macOS)
                .onChange(of: columnWidths) { _, newValue in
                    persistColumnWidths(newValue)
                }
            #endif

            if !triggerTypes.isEmpty {
                triggerTypeChips
            }

            #if os(macOS)
                EventsTableView(rows: sortedRows(),
                                columns: columns,
                                columnWidths: $columnWidths,
                                sortColumn: $sortColumn,
                                sortAscending: $sortAscending,
                                onOpen: onOpen)
                    .frame(minHeight: 380)
            #else
                Text("Events table is only available on macOS.")
                    .frame(minHeight: 380)
            #endif
        }
    }

    private enum FiltersLayout { case horizontal, stacked }

    @ViewBuilder
    private func filtersRow(layout: FiltersLayout) -> some View {
        switch layout {
        case .horizontal:
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                severityPickerView
                subjectTypePickerView
                modePickerView
                if !configuration.hideDatePickers {
                    datePickerView(label: "From", selection: $fromDate)
                    datePickerView(label: "To", selection: $toDate)
                }
                searchFieldView
                Button("Refresh", action: load)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .stacked:
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    severityPickerView
                    subjectTypePickerView
                    modePickerView
                    Spacer(minLength: 0)
                    Button("Refresh", action: load)
                }
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    if !configuration.hideDatePickers {
                        datePickerView(label: "From", selection: $fromDate)
                        datePickerView(label: "To", selection: $toDate)
                    }
                    searchFieldView
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var severityPickerView: some View {
        Picker("Severity", selection: $severity) {
            Text("All").tag("all")
            Text("Info").tag("info")
            Text("Warning").tag("warning")
            Text("Critical").tag("critical")
        }
        .frame(minWidth: 140, maxWidth: 180)
    }

    @ViewBuilder
    private var subjectTypePickerView: some View {
        Picker("Subject Type", selection: Binding(
            get: { subjectType?.rawValue ?? "all" },
            set: { v in subjectType = (v == "all") ? nil : AlertSubjectType(rawValue: v) }
        )) {
            Text("All").tag("all")
            ForEach(AlertSubjectType.allCases) { t in
                Text(t.rawValue).tag(t.rawValue)
            }
        }
        .frame(minWidth: 160, maxWidth: 220)
    }

    @ViewBuilder
    private var modePickerView: some View {
        Picker("Mode", selection: $mode) {
            Text("Upcoming").tag("upcoming")
            Text("Occurred").tag("occurred")
            Text("Both").tag("both")
        }
        .frame(minWidth: 140, maxWidth: 180)
    }

    private func datePickerView(label: String, selection: Binding<Date>) -> some View {
        LabeledContent(label) {
            DatePicker("", selection: selection, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
        }
        .frame(minWidth: 150, maxWidth: 200)
    }

    @ViewBuilder
    private var searchFieldView: some View {
        TextField("Search name…", text: $search)
            .textFieldStyle(.roundedBorder)
            .frame(minWidth: 160, maxWidth: 220)
    }

    private var triggerTypeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(triggerTypes, id: \.code) { t in
                    let isOn = selectedTypes.contains(t.code)
                    Button(action: {
                        if isOn { selectedTypes.remove(t.code) } else { selectedTypes.insert(t.code) }
                        applyFilters()
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
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func load() {
        // Build base rows from DB
        var out: [Row] = []
        let triggerDisplayLookup = Dictionary(uniqueKeysWithValues: triggerTypes.map { ($0.code, $0.displayName) })

        func alertInfo(_ id: Int) -> (AlertSubjectType, String, String, String) {
            if let a = dbManager.getAlert(id: id) {
                let code = a.triggerTypeCode
                let display = triggerDisplayLookup[code] ?? code
                return (a.scopeType, code, a.severity.rawValue, display)
            }
            let fallbackCode = "date"
            let fallbackDisplay = triggerDisplayLookup[fallbackCode] ?? fallbackCode
            return (.Instrument, fallbackCode, "info", fallbackDisplay)
        }

        let allowedCodes = configuration.allowedTriggerCodes

        // Upcoming (date-based)
        let upcoming = dbManager.listUpcomingDateAlerts(limit: 1000)
        for u in upcoming {
            guard let d = dateOnly(u.upcomingDate) else { continue }
            let (subj, trig, sev, trigDisplay) = alertInfo(u.alertId)
            if let allowed = allowedCodes, !allowed.contains(trig) { continue }
            out.append(Row(id: out.count + 1,
                           series: "Upcoming",
                           when: d,
                           alertId: u.alertId,
                           name: u.alertName,
                           severity: sev,
                           subjectType: subj,
                           triggerTypeCode: trig,
                           triggerDisplayName: trigDisplay,
                           message: nil,
                           thresholdDifferenceText: nil,
                           thresholdDifferenceValue: nil,
                           thresholdDifferencePercent: nil))
        }

        // Occurred events (recent window)
        let events = dbManager.listAlertEvents(limit: 1000)
        let isoFraction = ISO8601DateFormatter()
        isoFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoBasic = ISO8601DateFormatter()
        isoBasic.formatOptions = [.withInternetDateTime]
        for e in events {
            let occurredAt = e.occurredAt
            let parsedDate = isoFraction.date(from: occurredAt)
                ?? isoBasic.date(from: occurredAt)
                ?? DateFormatter.iso8601DateTime.date(from: occurredAt)
                ?? DateFormatter.iso8601DateOnly.date(from: occurredAt)
            guard let d = parsedDate else { continue }
            let (subj, trig, sev, trigDisplay) = alertInfo(e.alertId)
            if let allowed = allowedCodes, !allowed.contains(trig) { continue }
            let diff = configuration.highlightThresholdDelta ? thresholdDifference(from: e.measuredJson) : nil
            out.append(Row(id: out.count + 1,
                           series: "Events",
                           when: d,
                           alertId: e.alertId,
                           name: e.alertName,
                           severity: sev,
                           subjectType: subj,
                           triggerTypeCode: trig,
                           triggerDisplayName: trigDisplay,
                           message: e.message,
                           thresholdDifferenceText: diff?.text,
                           thresholdDifferenceValue: diff?.value,
                           thresholdDifferencePercent: diff?.percent))
        }

        if configuration.includeHoldingAbsSnapshots {
            let snapshots = dbManager.listHoldingAbsSnapshots(includeDisabled: configuration.includeDisabledSnapshots)
            for snapshot in snapshots {
                let alert = snapshot.alert
                if let allowed = allowedCodes, !allowed.contains(alert.triggerTypeCode) { continue }
                let trigDisplay = triggerDisplayLookup[alert.triggerTypeCode] ?? alert.triggerTypeCode
                let diffInfo = formatThresholdDifference(value: snapshot.currentValue,
                                                         threshold: snapshot.thresholdValue,
                                                         currencyCode: snapshot.currency)
                let symbol = diffInfo.value >= 0 ? "≥" : "<"
                let currentText = formatCurrency(snapshot.currentValue, currencyCode: snapshot.currency)
                let thresholdText = formatCurrency(snapshot.thresholdValue, currencyCode: snapshot.currency)
                let message = "\(snapshot.instrumentName): \(currentText) \(symbol) \(thresholdText)"
                out.append(Row(id: out.count + 1,
                               series: configuration.snapshotSeriesName ?? "Events",
                               when: snapshot.calculatedAt,
                               alertId: alert.id,
                               name: alert.name,
                               severity: alert.severity.rawValue,
                               subjectType: alert.scopeType,
                               triggerTypeCode: alert.triggerTypeCode,
                               triggerDisplayName: trigDisplay,
                               message: message,
                               thresholdDifferenceText: diffInfo.text,
                               thresholdDifferenceValue: diffInfo.value,
                               thresholdDifferencePercent: diffInfo.percent))
            }
        }

        allItems = out
        applyFilters()
    }

    private func thresholdDifference(from measured: String?) -> (text: String, value: Double, percent: Double?)? {
        guard configuration.highlightThresholdDelta,
              let measured,
              let data = measured.data(using: .utf8),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        guard (obj["kind"] as? String) == "holding_abs" else { return nil }
        let currencyMode = (obj["currency_mode"] as? String ?? "instrument").lowercased()
        var currentValue: Double?
        var thresholdValue: Double?
        var currencyCode: String?
        if currencyMode == "base" {
            currentValue = obj["value_base"] as? Double ?? obj["value"] as? Double ?? obj["comparison_value"] as? Double
            thresholdValue = obj["threshold_base"] as? Double ?? obj["threshold"] as? Double
            currencyCode = (obj["base_currency"] as? String ?? obj["comparison_currency"] as? String)?.uppercased()
        } else {
            currentValue = obj["value_instrument"] as? Double ?? obj["value"] as? Double ?? obj["comparison_value"] as? Double
            thresholdValue = obj["threshold"] as? Double ?? obj["threshold_base"] as? Double
            currencyCode = (obj["instrument_currency"] as? String ?? obj["comparison_currency"] as? String)?.uppercased()
        }
        guard let currentValue, let thresholdValue, let currencyCode else { return nil }
        return formatThresholdDifference(value: currentValue,
                                         threshold: thresholdValue,
                                         currencyCode: currencyCode)
    }

    private func formatThresholdDifference(value: Double, threshold: Double, currencyCode: String) -> (text: String, value: Double, percent: Double?) {
        let difference = value - threshold
        let percent = threshold != 0 ? difference / threshold : nil

        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.currencyCode = currencyCode
        currencyFormatter.maximumFractionDigits = 2
        currencyFormatter.minimumFractionDigits = 2
        let formattedDiff = currencyFormatter.string(from: NSNumber(value: difference)) ?? String(format: "%.2f %@", difference, currencyCode)
        let prefix = difference >= 0 ? "+" : ""

        let percentFormatter = NumberFormatter()
        percentFormatter.numberStyle = .percent
        percentFormatter.maximumFractionDigits = 1
        let percentText = percent.flatMap { percentFormatter.string(from: NSNumber(value: $0)) }

        let text = percentText.map { "\(prefix)\(formattedDiff) (\($0))" } ?? "\(prefix)\(formattedDiff)"
        return (text, difference, percent)
    }

    private func formatCurrency(_ value: Double, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f %@", value, currencyCode)
    }

    #if os(macOS)
        private func sortedRows() -> [Row] {
            items.sorted { lhs, rhs in
                let ascending = sortAscending
                switch sortColumn {
                case .when:
                    return ascending ? lhs.when < rhs.when : lhs.when > rhs.when
                case .series:
                    return compareString(lhs.series, rhs.series, ascending: ascending)
                case .name:
                    return compareString(lhs.name, rhs.name, ascending: ascending)
                case .severity:
                    return compareString(lhs.severity, rhs.severity, ascending: ascending)
                case .subjectType:
                    return compareString(lhs.subjectType.rawValue, rhs.subjectType.rawValue, ascending: ascending)
                case .trigger:
                    return compareString(lhs.triggerDisplayName, rhs.triggerDisplayName, ascending: ascending)
                case .thresholdDelta:
                    return compareDouble(lhs.thresholdDifferenceValue, rhs.thresholdDifferenceValue, ascending: ascending)
                case .message:
                    return compareString(lhs.message ?? "", rhs.message ?? "", ascending: ascending)
                }
            }
        }

        private func compareString(_ lhs: String, _ rhs: String, ascending: Bool) -> Bool {
            let comparison = lhs.localizedCaseInsensitiveCompare(rhs)
            if comparison == .orderedSame {
                return ascending ? lhs < rhs : lhs > rhs
            }
            return ascending ? (comparison == .orderedAscending) : (comparison == .orderedDescending)
        }

        private func compareDouble(_ lhs: Double?, _ rhs: Double?, ascending: Bool) -> Bool {
            switch (lhs, rhs) {
            case (nil, nil):
                return false
            case (nil, _):
                return !ascending
            case (_, nil):
                return ascending
            case let (l?, r?):
                if l == r { return false }
                return ascending ? (l < r) : (l > r)
            }
        }

        private func restoreColumnWidths() {
            guard !didRestoreColumnWidths else { return }
            didRestoreColumnWidths = true
            var defaults = EventsColumn.defaultWidths(for: columns)
            if let data = UserDefaults.standard.data(forKey: columnWidthStorageKey),
               let decoded = try? JSONDecoder().decode([String: Double].self, from: data)
            {
                for (key, value) in decoded {
                    guard columns.contains(where: { $0.rawValue == key }) else { continue }
                    defaults[key] = CGFloat(value)
                }
            }
            DispatchQueue.main.async { self.columnWidths = defaults }
        }

        private func persistColumnWidths(_ widths: [String: CGFloat]) {
            guard !widths.isEmpty,
                  let data = try? JSONEncoder().encode(widths.mapValues { Double($0) }) else { return }
            UserDefaults.standard.set(data, forKey: columnWidthStorageKey)
        }

        private struct EventsTableView: NSViewRepresentable {
            var rows: [Row]
            var columns: [EventsColumn]
            var columnWidths: Binding<[String: CGFloat]>
            var sortColumn: Binding<EventsColumn>
            var sortAscending: Binding<Bool>
            var onOpen: ((Int) -> Void)?

            func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

            func makeNSView(context: Context) -> NSScrollView {
                let scrollView = NSScrollView()
                scrollView.drawsBackground = false
                scrollView.hasVerticalScroller = true
                scrollView.hasHorizontalScroller = true
                scrollView.autohidesScrollers = true

                let tableView = context.coordinator.makeTableView()
                scrollView.documentView = tableView
                context.coordinator.tableView = tableView

                tableView.translatesAutoresizingMaskIntoConstraints = false
                tableView.widthAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.widthAnchor).isActive = true

                if let documentView = scrollView.documentView {
                    documentView.setContentHuggingPriority(.defaultLow, for: .horizontal)
                }

                NotificationCenter.default.addObserver(context.coordinator,
                                                       selector: #selector(Coordinator.columnDidResize(_:)),
                                                       name: NSTableView.columnDidResizeNotification,
                                                       object: tableView)

                return scrollView
            }

            func updateNSView(_: NSScrollView, context: Context) {
                context.coordinator.parent = self
                if !columns.contains(sortColumn.wrappedValue), let fallback = columns.first {
                    sortColumn.wrappedValue = fallback
                }
                guard let tableView = context.coordinator.tableView else { return }
                tableView.reloadData()
                context.coordinator.syncSortDescriptors()
                context.coordinator.syncColumnWidths()
            }

            static func dismantleNSView(_: NSScrollView, coordinator: Coordinator) {
                if let tableView = coordinator.tableView {
                    NotificationCenter.default.removeObserver(coordinator,
                                                              name: NSTableView.columnDidResizeNotification,
                                                              object: tableView)
                }
            }

            final class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
                var parent: EventsTableView
                weak var tableView: NSTableView?
                private let dateFormatter: DateFormatter = {
                    let df = DateFormatter()
                    df.dateFormat = "dd.MM.yy"
                    df.locale = Locale(identifier: "de_CH")
                    return df
                }()

                init(parent: EventsTableView) {
                    self.parent = parent
                }

                func makeTableView() -> NSTableView {
                    let tableView = NSTableView()
                    tableView.delegate = self
                    tableView.dataSource = self
                    tableView.usesAutomaticRowHeights = true
                    tableView.rowSizeStyle = .medium
                    tableView.selectionHighlightStyle = .none
                    tableView.allowsColumnReordering = false
                    tableView.allowsColumnResizing = true
                    tableView.allowsColumnSelection = false
                    tableView.columnAutoresizingStyle = .reverseSequentialColumnAutoresizingStyle
                    tableView.headerView = NSTableHeaderView()
                    tableView.gridStyleMask = []
                    tableView.autoresizingMask = [.width, .height]
                    if #available(macOS 13.0, *) {
                        tableView.style = .fullWidth
                    }
                    tableView.target = self
                    tableView.doubleAction = #selector(handleDoubleClick(_:))

                    for column in parent.columns {
                        tableView.addTableColumn(configureColumn(for: column))
                    }

                    return tableView
                }

                private func configureColumn(for column: EventsColumn) -> NSTableColumn {
                    let identifier = NSUserInterfaceItemIdentifier(column.rawValue)
                    let tableColumn = NSTableColumn(identifier: identifier)
                    tableColumn.title = column.title
                    tableColumn.minWidth = column.minWidth
                    tableColumn.maxWidth = column.maxWidth
                    tableColumn.resizingMask = [.autoresizingMask, .userResizingMask]
                    tableColumn.headerCell.alignment = column.alignment

                    let currentWidth = parent.columnWidths.wrappedValue[column.rawValue] ?? column.defaultWidth
                    tableColumn.width = currentWidth

                    let ascending = parent.sortAscending.wrappedValue
                    switch column {
                    case .when:
                        tableColumn.sortDescriptorPrototype = NSSortDescriptor(key: column.rawValue,
                                                                               ascending: ascending,
                                                                               comparator: { lhs, rhs in
                                                                                   guard let left = lhs as? Date, let right = rhs as? Date else { return .orderedSame }
                                                                                   if left == right { return .orderedSame }
                                                                                   return left < right ? .orderedAscending : .orderedDescending
                                                                               })
                    case .thresholdDelta:
                        tableColumn.sortDescriptorPrototype = NSSortDescriptor(key: column.rawValue,
                                                                               ascending: ascending,
                                                                               comparator: { lhs, rhs in
                                                                                   let left = (lhs as? NSNumber)?.doubleValue ?? 0
                                                                                   let right = (rhs as? NSNumber)?.doubleValue ?? 0
                                                                                   if left == right { return .orderedSame }
                                                                                   return left < right ? .orderedAscending : .orderedDescending
                                                                               })
                    default:
                        tableColumn.sortDescriptorPrototype = NSSortDescriptor(key: column.rawValue,
                                                                               ascending: ascending,
                                                                               selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
                    }

                    return tableColumn
                }

                func numberOfRows(in _: NSTableView) -> Int {
                    parent.rows.count
                }

                func tableView(_: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
                    guard row < parent.rows.count,
                          let column = tableColumn,
                          let spec = EventsColumn(rawValue: column.identifier.rawValue) else { return nil }

                    let item = parent.rows[row]

                    switch spec {
                    case .when:
                        let text = dateFormatter.string(from: item.when)
                        return makeLabelCell(text: text, alignment: .left)
                    case .series:
                        return makeLabelCell(text: item.series, alignment: .center)
                    case .name:
                        return makeButtonCell(title: displayName(for: item), alertId: item.alertId)
                    case .severity:
                        return makeLabelCell(text: item.severity.capitalized, alignment: .center)
                    case .subjectType:
                        return makeLabelCell(text: item.subjectType.rawValue, alignment: .left)
                    case .trigger:
                        return makeLabelCell(text: item.triggerDisplayName, alignment: .left)
                    case .thresholdDelta:
                        let text = item.thresholdDifferenceText ?? "–"
                        let style = thresholdAppearance(for: item)
                        return makeLabelCell(text: text,
                                             alignment: .right,
                                             textColor: style.color,
                                             isBold: style.isBold)
                    case .message:
                        return makeLabelCell(text: item.message ?? "", alignment: .left, maxLines: 2, wrap: true)
                    }
                }

                func tableView(_ tableView: NSTableView, sortDescriptorsDidChange _: [NSSortDescriptor]) {
                    guard let descriptor = tableView.sortDescriptors.first,
                          let key = descriptor.key,
                          let column = EventsColumn(rawValue: key) else { return }
                    DispatchQueue.main.async { [weak tableView, parent = self.parent] in
                        guard let tbl = tableView else { return }
                        parent.sortColumn.wrappedValue = column
                        parent.sortAscending.wrappedValue = descriptor.ascending
                        tbl.reloadData()
                    }
                }

                func syncSortDescriptors() {
                    guard let tableView = tableView else { return }
                    let column = parent.sortColumn.wrappedValue
                    let ascending = parent.sortAscending.wrappedValue
                    let descriptor: NSSortDescriptor
                    switch column {
                    case .when:
                        descriptor = NSSortDescriptor(key: column.rawValue,
                                                      ascending: ascending,
                                                      comparator: { lhs, rhs in
                                                          guard let left = lhs as? Date, let right = rhs as? Date else { return .orderedSame }
                                                          if left == right { return .orderedSame }
                                                          return left < right ? .orderedAscending : .orderedDescending
                                                      })
                    case .thresholdDelta:
                        descriptor = NSSortDescriptor(key: column.rawValue,
                                                      ascending: ascending,
                                                      comparator: { lhs, rhs in
                                                          let left = (lhs as? NSNumber)?.doubleValue ?? 0
                                                          let right = (rhs as? NSNumber)?.doubleValue ?? 0
                                                          if left == right { return .orderedSame }
                                                          return left < right ? .orderedAscending : .orderedDescending
                                                      })
                    default:
                        descriptor = NSSortDescriptor(key: column.rawValue,
                                                      ascending: ascending,
                                                      selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
                    }
                    tableView.sortDescriptors = [descriptor]
                }

                func syncColumnWidths() {
                    guard let tableView = tableView else { return }
                    for column in tableView.tableColumns {
                        guard let spec = EventsColumn(rawValue: column.identifier.rawValue) else { continue }
                        let targetWidth = parent.columnWidths.wrappedValue[spec.rawValue] ?? spec.defaultWidth
                        if abs(column.width - targetWidth) > 0.5 {
                            column.width = targetWidth
                        }
                    }
                }

                @objc func columnDidResize(_ notification: Notification) {
                    guard let tableView = tableView,
                          notification.object as? NSTableView === tableView,
                          let column = notification.userInfo?["NSTableColumn"] as? NSTableColumn,
                          let spec = EventsColumn(rawValue: column.identifier.rawValue) else { return }
                    DispatchQueue.main.async { [parent = self.parent] in
                        var widths = parent.columnWidths.wrappedValue
                        let clamped = max(spec.minWidth, min(spec.maxWidth, column.width))
                        widths[spec.rawValue] = clamped
                        parent.columnWidths.wrappedValue = widths
                    }
                }

                @objc func handleDoubleClick(_ sender: NSTableView) {
                    let index = sender.clickedRow
                    guard index >= 0, index < parent.rows.count else { return }
                    let alertId = parent.rows[index].alertId
                    parent.onOpen?(alertId)
                }

                @objc private func openAlert(_ sender: NSButton) {
                    parent.onOpen?(sender.tag)
                }

                private func displayName(for row: Row) -> String {
                    guard let symbol = statusSymbol(for: row) else { return row.name }
                    return "\(symbol) \(row.name)"
                }

                private func statusSymbol(for row: Row) -> String? {
                    guard let difference = row.thresholdDifferenceValue else { return nil }
                    if difference >= 0 { return "‼️" }
                    guard let percent = row.thresholdDifferencePercent else { return nil }
                    if abs(percent) <= 0.05 { return "⚠️" }
                    return nil
                }

                private func makeLabelCell(text: String,
                                           alignment: NSTextAlignment,
                                           maxLines: Int = 1,
                                           wrap: Bool = false,
                                           textColor: NSColor? = nil,
                                           isBold: Bool = false) -> NSTableCellView
                {
                    let cell = NSTableCellView()
                    let label = NSTextField(labelWithString: text)
                    label.translatesAutoresizingMaskIntoConstraints = false
                    label.alignment = alignment
                    label.lineBreakMode = wrap ? .byWordWrapping : .byTruncatingTail
                    label.maximumNumberOfLines = maxLines
                    label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                    if let textColor {
                        label.textColor = textColor
                    }
                    if isBold {
                        let fontManager = NSFontManager.shared
                        let baseFont = label.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
                        label.font = fontManager.convert(baseFont, toHaveTrait: .boldFontMask)
                    }
                    cell.addSubview(label)
                    NSLayoutConstraint.activate([
                        label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
                        label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
                        label.topAnchor.constraint(equalTo: cell.topAnchor, constant: 2),
                        label.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -2),
                    ])
                    cell.textField = label
                    return cell
                }

                private func makeButtonCell(title: String, alertId: Int) -> NSTableCellView {
                    let cell = NSTableCellView()
                    let button = NSButton(title: title, target: self, action: #selector(openAlert(_:)))
                    button.translatesAutoresizingMaskIntoConstraints = false
                    button.isBordered = false
                    button.bezelStyle = .inline
                    button.setButtonType(.momentaryPushIn)
                    button.alignment = .left
                    button.lineBreakMode = .byTruncatingTail
                    button.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
                    button.tag = alertId
                    cell.addSubview(button)
                    NSLayoutConstraint.activate([
                        button.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                        button.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                        button.topAnchor.constraint(equalTo: cell.topAnchor, constant: 2),
                        button.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -2),
                    ])
                    return cell
                }

                private func thresholdAppearance(for row: Row) -> (color: NSColor?, isBold: Bool) {
                    guard let difference = row.thresholdDifferenceValue else { return (nil, false) }
                    if difference >= 0 {
                        return (NSColor.systemRed, true)
                    }
                    guard let percent = row.thresholdDifferencePercent else { return (nil, false) }
                    if percent > -0.05 {
                        return (NSColor.systemOrange, false)
                    }
                    return (nil, false)
                }
            }
        }
    #endif

    private func applyFilters() {
        let from = configuration.hideDatePickers ? Date.distantPast : stripTime(fromDate)
        let to = configuration.hideDatePickers ? Date.distantFuture : stripTime(toDate).addingTimeInterval(86400 - 1)

        let snapshotSeries = configuration.snapshotSeriesName

        func allowedSeries(_ s: String) -> Bool {
            switch mode {
            case "upcoming":
                return s == "Upcoming"
            case "occurred":
                if s == "Events" { return true }
                if let snapshotSeries, s == snapshotSeries { return true }
                return false
            default: return true
            }
        }

        let searchTerm = search.trimmingCharacters(in: .whitespaces)
        let typeFilterActive = !selectedTypes.isEmpty
        let includePastEvents = (mode == "occurred" || mode == "both")
        let filtered = allItems.filter { r in
            guard allowedSeries(r.series) else { return false }
            if severity != "all", r.severity != severity { return false }
            if let st = subjectType, r.subjectType != st { return false }
            if typeFilterActive, !selectedTypes.contains(r.triggerTypeCode) { return false }
            let lowerBound = (includePastEvents && r.series == "Events") ? Date.distantPast : from
            if !(r.when >= lowerBound && r.when <= to) { return false }
            if !searchTerm.isEmpty {
                if !r.name.localizedCaseInsensitiveContains(searchTerm) { return false }
            }
            return true
        }
        items = filtered
    }

    private func stripTime(_ d: Date) -> Date {
        let cal = Calendar.current
        return cal.startOfDay(for: d)
    }

    private func dateOnly(_ ymd: String) -> Date? {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: ymd)
    }
}

private struct ThresholdEventsView: View {
    var onOpen: ((Int) -> Void)?

    var body: some View {
        EventsListView(onOpen: onOpen,
                       configuration: .thresholdHoldingAbs,
                       columnWidthStorageKey: "thresholdEventsTableColumnWidths")
    }
}

private extension EventsListView.Configuration {
    static let standard = EventsListView.Configuration()
    static let thresholdHoldingAbs: EventsListView.Configuration = {
        var config = EventsListView.Configuration(defaultMode: .both,
                                                  allowedTriggerCodes: ["holding_abs"],
                                                  hideDatePickers: true,
                                                  highlightThresholdDelta: true)
        config.includeHoldingAbsSnapshots = true
        config.snapshotSeriesName = "Snapshot"
        config.includeSeriesColumn = false
        config.includeTriggerColumn = false
        return config
    }()
}

// MARK: - Split sections to reduce type-check load

// Split sections to reduce type-check load (helper views below)

// Dedicated tags list view to simplify type-checking in parent
private struct TagsListView: View {
    let tags: [TagRow]
    @Binding var selected: Set<Int>
    private func binding(for id: Int) -> Binding<Bool> {
        Binding(
            get: { selected.contains(id) },
            set: { val in if val { selected.insert(id) } else { selected.remove(id) } }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(tags) { tag in
                        Toggle(isOn: binding(for: tag.id)) {
                            Text(tag.displayName)
                        }
                    }
                }
            }
            .frame(minHeight: 120)
            Text("Tip: Tags can be maintained in Settings → Tags")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Input styling helpers (file scope)

private extension View {
    func dsField() -> some View {
        padding(6)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            )
    }

    func dsTextEditor() -> some View {
        scrollContentBackground(.hidden)
            .padding(6)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            )
    }
}

private struct AlertEditorView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State var alert: AlertRow
    var triggerTypes: [AlertTriggerTypeRow]
    var allTags: [TagRow]
    var onSave: (AlertRow, Set<Int>) -> Void
    var onCancel: () -> Void
    @State private var selectedTags: Set<Int> = []
    @State private var jsonError: String?
    // Trigger validation propagated from typed subviews
    @State private var triggerValid: Bool = true
    // Evaluate Now banner
    @State private var evalNowMessage: String? = nil
    @State private var evalNowStyle: String = "info" // success | info | error
    // Advanced JSON visibility
    @State private var showAdvancedJSON: Bool = false
    // Near window (thresholds) state
    @State private var nearValueText: String = ""
    @State private var nearUnitText: String = ""
    // Scheduling state
    @State private var scheduleStartDate: Date? = nil
    @State private var scheduleEndDate: Date? = nil
    @State private var muteUntilDate: Date? = nil
    // Holding abs context
    @State private var holdingAbsCurrency: String? = nil
    @State private var holdingAbsQuantity: Double? = nil
    @State private var holdingAbsValue: Double? = nil
    // Scope picker state
    @State private var showScopePicker: Bool = false
    @State private var scopeNames: [String] = []
    @State private var scopeIdMap: [Int: String] = [:]
    @State private var scopeText: String = ""
    private var selectedScopeName: String { scopeIdMap[alert.scopeId] ?? "(none)" }
    @State private var subjectReferenceText: String = ""
    // Instrument picker state
    @State private var instrumentRows: [DatabaseManager.InstrumentRow] = []
    @State private var instrumentQuery: String = ""
    @State private var selectedInstrumentId: Int? = nil
    // Today trigger reset state
    @State private var hasTodayTrigger: Bool = false
    @State private var showResetConfirm: Bool = false

    // MARK: - Validation

    private func isDateStrict(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        let regex = try! NSRegularExpression(pattern: "^\\d{4}-\\d{2}-\\d{2}$")
        guard regex.firstMatch(in: t, range: NSRange(location: 0, length: t.utf16.count)) != nil else { return false }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: t) != nil
    }

    private var formValid: Bool { triggerValid }

    private func instrumentDisplay(_ ins: DatabaseManager.InstrumentRow) -> String {
        var parts: [String] = [ins.name]
        if let t = ins.tickerSymbol, !t.isEmpty { parts.append(t.uppercased()) }
        if let i = ins.isin, !i.isEmpty { parts.append(i.uppercased()) }
        return parts.joined(separator: " • ")
    }

    private func instrumentSearchKey(_ ins: DatabaseManager.InstrumentRow) -> String {
        var tokens: [String] = [ins.name.lowercased()]
        if let ticker = ins.tickerSymbol?.lowercased(), !ticker.isEmpty { tokens.append(ticker) }
        if let isin = ins.isin?.lowercased(), !isin.isEmpty { tokens.append(isin) }
        return tokens.joined(separator: " ")
    }

    private func syncInstrumentSelectionFromAlert() {
        guard alert.scopeType == .Instrument else {
            selectedInstrumentId = nil
            instrumentQuery = ""
            return
        }

        var candidateId: Int?
        if alert.scopeId > 0 {
            candidateId = alert.scopeId
        } else if let reference = alert.subjectReference, let parsed = Int(reference) {
            candidateId = parsed
        }

        if let id = candidateId,
           let match = instrumentRows.first(where: { $0.id == id })
        {
            selectedInstrumentId = id
            instrumentQuery = instrumentDisplay(match)
        } else {
            selectedInstrumentId = nil
            if let ref = alert.subjectReference, !ref.isEmpty {
                instrumentQuery = ref
            } else {
                instrumentQuery = ""
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(alert.id < 0 ? "Create Alert" : "Edit Alert")
                .font(.title2).bold()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.top, .horizontal], 16)
            Divider()
            ScrollView {
                evaluateBannerView
                Form {
                    BasicsSectionView(name: $alert.name,
                                      enabled: $alert.enabled,
                                      severity: Binding(get: { alert.severity }, set: { alert.severity = $0 }),
                                      subjectType: Binding(get: { alert.scopeType }, set: { alert.scopeType = $0 }),
                                      selectedScopeName: selectedScopeName,
                                      requiresNumericScope: alert.scopeType.requiresNumericScope,
                                      subjectReference: $subjectReferenceText,
                                      onChooseScope: { showScopePicker = true })
                    AnyView(TriggerSectionView(triggerTypes: triggerTypes,
                                               triggerTypeCode: Binding(get: { alert.triggerTypeCode }, set: { alert.triggerTypeCode = $0 }),
                                               showAdvancedJSON: $showAdvancedJSON,
                                               paramsJson: $alert.paramsJson,
                                               jsonError: jsonError,
                                               onValidateJSON: { validateJSON() },
                                               onInsertTemplate: { insertTemplate() },
                                               onValidityChange: { ok in triggerValid = ok },
                                               holdingAbsCurrency: holdingAbsCurrency,
                                               holdingsQuantity: holdingAbsQuantity,
                                               holdingsValue: holdingAbsValue))
                    AnyView(ThresholdsSectionView(nearValueText: $nearValueText, nearUnitText: $nearUnitText))
                    AnyView(SchedulingSectionView(scheduleStart: $scheduleStartDate,
                                                  scheduleEnd: $scheduleEndDate,
                                                  muteUntil: $muteUntilDate))
                    AnyView(NotesAndTagsSectionView(notes: Binding(get: { alert.notes }, set: { alert.notes = $0 }),
                                                    allTags: allTags,
                                                    selectedTags: $selectedTags))
                }
                .formStyle(.grouped)
                .padding(16)
            }
        }
        .safeAreaInset(edge: .bottom) {
            ZStack {
                Rectangle().fill(.ultraThinMaterial).frame(height: 56).overlay(Divider(), alignment: .top)
                HStack {
                    Button("Cancel", role: .cancel) { onCancel() }
                    Button("Save") { onSave(alert, selectedTags) }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!formValid)
                    Spacer()
                    Button("Evaluate Now") { evaluateNow() }
                        .disabled(alert.triggerTypeCode != "date")
                        .help("Runs evaluation for this alert now (date alerts supported).")
                    if alert.id > 0 && alert.triggerTypeCode == "date" {
                        Button("Reset Today’s Trigger") { showResetConfirm = true }
                            .disabled(!hasTodayTrigger)
                            .foregroundColor(hasTodayTrigger ? .red : .secondary)
                            .help("Deletes today’s 'triggered' event for this alert.")
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .onAppear {
            subjectReferenceText = alert.subjectReference ?? ""
            if alert.id > 0 {
                let current = dbManager.listTagsForAlert(alertId: alert.id).map { $0.id }
                selectedTags = Set(current)
            } else {
                selectedTags = []
            }
            // Load scope options (start with Instruments by default)
            loadScopeOptions()
            // Trigger validity defaults to true; typed subviews will update it
            triggerValid = true
            // Pre-fill near window state
            nearValueText = alert.nearValue.map { String($0) } ?? ""
            nearUnitText = alert.nearUnit ?? ""
            scheduleStartDate = dateFromISO(alert.scheduleStart)
            scheduleEndDate = dateFromISO(alert.scheduleEnd)
            muteUntilDate = dateFromISO(alert.muteUntil)
            syncScheduleStrings()
            refreshTodayTriggerFlag()
            handleSubjectTypeChange(alert.scopeType)
            syncSubjectReferenceFromScope()
            if !alert.scopeType.requiresNumericScope {
                syncSubjectReferenceFromText()
            }
            updateHoldingAbsContext()
        }
        // Reload available options when scope type changes; clear selection text
        .onChange(of: alert.scopeType) { _, newType in
            alert.scopeId = 0
            scopeText = ""
            loadScopeOptions()
            handleSubjectTypeChange(newType)
            updateHoldingAbsContext()
            syncInstrumentSelectionFromAlert()
        }
        .onChange(of: alert.scopeId) { _, _ in
            syncSubjectReferenceFromScope()
            updateHoldingAbsContext()
            syncInstrumentSelectionFromAlert()
        }
        .onChange(of: subjectReferenceText) { _, _ in
            syncSubjectReferenceFromText()
            updateHoldingAbsContext()
        }
        // Trigger type change and typed params are handled inside subviews
        // If JSON changes externally (e.g., Template), typed subviews will re-render with the new JSON
        .onChange(of: alert.paramsJson) { _, _ in }
        .onChange(of: alert.triggerTypeCode) { _, _ in
            updateHoldingAbsContext()
        }
        // Sync near window state back to alert
        .onChange(of: nearValueText) { _, _ in
            let t = nearValueText.trimmingCharacters(in: .whitespaces)
            alert.nearValue = t.isEmpty ? nil : Double(t)
        }
        .onChange(of: nearUnitText) { _, _ in
            let t = nearUnitText.trimmingCharacters(in: .whitespaces)
            alert.nearUnit = t.isEmpty ? nil : t
        }
        .onChange(of: scheduleStartDate) { _, _ in syncScheduleStrings() }
        .onChange(of: scheduleEndDate) { _, _ in syncScheduleStrings() }
        .onChange(of: muteUntilDate) { _, _ in syncScheduleStrings() }
        // Scope picker sheet
        .sheet(isPresented: $showScopePicker) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Select \(alert.scopeType.rawValue)").font(.headline)
                if alert.scopeType == .Instrument {
                    let pickerItems = instrumentRows.map { row in
                        FloatingSearchPicker.Item(
                            id: AnyHashable(row.id),
                            title: instrumentDisplay(row),
                            subtitle: nil,
                            searchText: instrumentSearchKey(row)
                        )
                    }
                    let binding = Binding<AnyHashable?>(
                        get: { selectedInstrumentId.map { AnyHashable($0) } },
                        set: { newValue in
                            if let value = newValue as? Int,
                               let match = instrumentRows.first(where: { $0.id == value })
                            {
                                selectedInstrumentId = value
                                alert.scopeId = value
                                instrumentQuery = instrumentDisplay(match)
                            } else {
                                selectedInstrumentId = nil
                                alert.scopeId = 0
                                instrumentQuery = ""
                            }
                        }
                    )
                    FloatingSearchPicker(
                        placeholder: "Search instrument, ticker, or ISIN",
                        items: pickerItems,
                        selectedId: binding,
                        showsClearButton: true,
                        emptyStateText: "No instruments",
                        query: $instrumentQuery,
                        onSelection: { _ in
                            showScopePicker = false
                        },
                        onClear: {
                            binding.wrappedValue = nil
                        },
                        selectsFirstOnSubmit: false
                    )
                    .frame(minWidth: 520)
                    .onAppear {
                        instrumentRows = dbManager.fetchAssets()
                        syncInstrumentSelectionFromAlert()
                    }
                } else {
                    MacComboBox(items: scopeNames, text: $scopeText) { idx in
                        guard idx >= 0 && idx < scopeNames.count else { return }
                        if let pair = scopeIdMap.first(where: { $0.value == scopeNames[idx] }) {
                            alert.scopeId = pair.key
                            showScopePicker = false
                        }
                    }
                    .frame(width: 520)
                }
                HStack {
                    Spacer()
                    Button("Close") { showScopePicker = false }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.gray)
                        .foregroundColor(.white)
                }
            }
            .padding(16)
            .frame(width: 600)
        }
        .alert("Reset Today’s Trigger?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) { resetTodaysTrigger() }
            Button("Cancel", role: .cancel) { showResetConfirm = false }
        } message: {
            Text("This will delete today’s trigger event for this alert. This cannot be undone.")
        }
    }

    // MARK: - Small subviews to help type-checking

    private struct DateTriggerForm: View {
        @Binding var paramsJson: String
        var onValidityChange: (Bool) -> Void
        @State private var selectedDate: Date? = nil
        @State private var showPicker: Bool = false
        @State private var tempDate: Date = .init()
        var body: some View {
            LabeledContent("Trigger Date") {
                Button {
                    tempDate = selectedDate ?? Date()
                    showPicker = true
                } label: {
                    HStack {
                        let text = selectedDate.map { displayDateFormatter.string(from: $0) } ?? ""
                        Text(text)
                            .foregroundColor(selectedDate == nil ? .secondary : .primary)
                            .frame(minWidth: 120, alignment: .leading)
                        Spacer()
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showPicker, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 16) {
                        DatePicker("Select Date", selection: $tempDate, displayedComponents: [.date])
                            .datePickerStyle(.graphical)
                        HStack {
                            Button("Clear") {
                                selectedDate = nil
                                syncJSON()
                                showPicker = false
                            }
                            Spacer()
                            Button("Set") {
                                selectedDate = tempDate
                                syncJSON()
                                showPicker = false
                            }
                            .keyboardShortcut(.defaultAction)
                        }
                    }
                    .padding(16)
                    .frame(width: 320)
                }
            }
            .onAppear {
                if let data = paramsJson.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let d = obj["date"] as? String,
                   let parsed = isoOutputFormatter.date(from: d)
                {
                    selectedDate = parsed
                } else {
                    selectedDate = nil
                }
                onValidityChange(true)
            }
            .onChange(of: selectedDate) { _, _ in
                onValidityChange(true)
            }
        }

        private func syncJSON() {
            var dict: [String: Any] = [:]
            if let data = paramsJson.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            {
                dict = obj
            }
            if let selectedDate {
                dict["date"] = isoOutputFormatter.string(from: selectedDate)
            } else {
                dict.removeValue(forKey: "date")
            }
            if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
               let s = String(data: data, encoding: .utf8)
            {
                paramsJson = s
            }
            onValidityChange(true)
        }
    }

    private struct PriceTriggerForm: View {
        @Binding var paramsJson: String
        var onValidityChange: (Bool) -> Void
        @State private var mode: String = "cross"
        @State private var threshold: String = ""
        @State private var bandLower: String = ""
        @State private var bandUpper: String = ""
        @State private var currencyMode: String = "instrument"
        @State private var stalenessDays: String = ""
        var body: some View {
            Group {
                LabeledContent("Mode") {
                    Picker("", selection: $mode) {
                        Text("Cross level").tag("cross")
                        Text("Outside band").tag("outside_band")
                    }.frame(width: 240)
                }
                if mode == "cross" {
                    LabeledContent("Threshold") {
                        HStack(spacing: 8) {
                            TextField("e.g., 75.0", text: $threshold)
                                .textFieldStyle(.plain)
                                .frame(width: 180)
                                .dsField()
                                .foregroundColor(Double(threshold) != nil ? .primary : .red)
                            Picker("", selection: $currencyMode) {
                                Text("Instrument").tag("instrument")
                                Text("Base").tag("base")
                            }.frame(width: 160)
                        }
                    }
                } else {
                    LabeledContent("Band") {
                        HStack(spacing: 8) {
                            TextField("Lower", text: $bandLower)
                                .textFieldStyle(.plain)
                                .frame(width: 120)
                                .dsField()
                                .foregroundColor(Double(bandLower) != nil ? .primary : .red)
                            Text("to").foregroundColor(.secondary)
                            TextField("Upper", text: $bandUpper)
                                .textFieldStyle(.plain)
                                .frame(width: 120)
                                .dsField()
                                .foregroundColor(Double(bandUpper) != nil ? .primary : .red)
                            Picker("", selection: $currencyMode) {
                                Text("Instrument").tag("instrument")
                                Text("Base").tag("base")
                            }.frame(width: 160)
                        }
                    }
                }
                LabeledContent("Staleness Days") {
                    TextField("optional", text: $stalenessDays)
                        .textFieldStyle(.plain)
                        .frame(width: 120)
                        .dsField()
                        .foregroundColor(stalenessDays.isEmpty || Int(stalenessDays) != nil ? .primary : .red)
                }
            }
            .onAppear {
                if let data = paramsJson.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let m = obj["mode"] as? String { mode = m }
                    if let th = obj["threshold"] as? Double { threshold = String(th) }
                    if let lo = obj["band_lower"] as? Double { bandLower = String(lo) }
                    if let up = obj["band_upper"] as? Double { bandUpper = String(up) }
                    if let cm = obj["currency_mode"] as? String { currencyMode = cm }
                    if let st = obj["staleness_days"] as? Int { stalenessDays = String(st) }
                }
                onValidityChange(validate())
            }
            .onChange(of: mode) { _, _ in syncJSON(); onValidityChange(validate()) }
            .onChange(of: threshold) { _, _ in syncJSON(); onValidityChange(validate()) }
            .onChange(of: bandLower) { _, _ in syncJSON(); onValidityChange(validate()) }
            .onChange(of: bandUpper) { _, _ in syncJSON(); onValidityChange(validate()) }
            .onChange(of: currencyMode) { _, _ in syncJSON() }
            .onChange(of: stalenessDays) { _, _ in syncJSON() }
        }

        private func validate() -> Bool {
            if mode == "cross" { return Double(threshold) != nil }
            guard let lo = Double(bandLower), let up = Double(bandUpper) else { return false }
            return lo < up
        }

        private func syncJSON() {
            var dict: [String: Any] = [:]
            if let data = paramsJson.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] { dict = obj }
            dict["mode"] = mode
            if mode == "cross" {
                if let val = Double(threshold) { dict["threshold"] = val; dict.removeValue(forKey: "band_lower"); dict.removeValue(forKey: "band_upper") }
            } else {
                if let lo = Double(bandLower) { dict["band_lower"] = lo }
                if let up = Double(bandUpper) { dict["band_upper"] = up }
                dict.removeValue(forKey: "threshold")
            }
            dict["currency_mode"] = currencyMode
            if let st = Int(stalenessDays) { dict["staleness_days"] = st } else { dict.removeValue(forKey: "staleness_days") }
            if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]), let s = String(data: data, encoding: .utf8) { paramsJson = s }
        }
    }

    private struct HoldingAbsTriggerForm: View {
        @Binding var paramsJson: String
        var onValidityChange: (Bool) -> Void
        let instrumentCurrency: String?
        let holdingsQuantity: Double?
        let holdingsValue: Double?
        @State private var thresholdText: String = ""

        private var labelText: String {
            if let currency = instrumentCurrency { return "Threshold (\(currency))" }
            return "Threshold (Instr. Currency)"
        }

        var body: some View {
            LabeledContent(labelText) {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("", text: $thresholdText)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.large)
                        .frame(width: 200)
                        .multilineTextAlignment(.trailing)
                        .disableAutocorrection(true)
                        .foregroundColor(Double(thresholdText) != nil ? .primary : .red)
                    if let qty = holdingsQuantity {
                        Text("Current quantity: \(formatQuantity(qty))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let currency = instrumentCurrency {
                        if let value = holdingsValue {
                            Text("Current value: \(formatCurrency(value, currency: currency))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Current value unavailable (price missing)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .onAppear {
                if let data = paramsJson.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let th = obj["threshold_chf"] as? Double { thresholdText = formatNumber(th) }
                }
                onValidityChange(Double(thresholdText) != nil)
            }
            .onChange(of: thresholdText) { _, _ in syncJSON(); onValidityChange(Double(thresholdText) != nil) }
        }

        private func syncJSON() {
            var dict: [String: Any] = [:]
            if let data = paramsJson.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] { dict = obj }
            if let th = Double(thresholdText) { dict["threshold_chf"] = th }
            dict["currency_mode"] = "instrument"
            if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]), let s = String(data: data, encoding: .utf8) { paramsJson = s }
        }

        private func formatNumber(_ value: Double) -> String {
            let formatter = NumberFormatter()
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 0
            formatter.usesGroupingSeparator = false
            return formatter.string(from: NSNumber(value: value)) ?? String(value)
        }

        private func formatQuantity(_ quantity: Double) -> String {
            let formatter = NumberFormatter()
            formatter.maximumFractionDigits = 4
            formatter.minimumFractionDigits = 0
            formatter.usesGroupingSeparator = true
            return formatter.string(from: NSNumber(value: quantity)) ?? String(format: "%.4f", quantity)
        }

        private func formatCurrency(_ value: Double, currency: String) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = currency
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 2
            return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f %@", value, currency)
        }
    }

    private struct HoldingPctTriggerForm: View {
        @Binding var paramsJson: String
        var onValidityChange: (Bool) -> Void
        @State private var thresholdPct: String = ""
        var body: some View {
            LabeledContent("Threshold (%)") {
                HStack(spacing: 8) {
                    TextField("e.g., 10", text: $thresholdPct)
                        .textFieldStyle(.plain)
                        .frame(width: 160)
                        .dsField()
                        .foregroundColor(Double(thresholdPct) != nil ? .primary : .red)
                    Text("% of scope").foregroundColor(.secondary)
                }
            }
            .onAppear {
                if let data = paramsJson.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let th = obj["threshold_pct"] as? Double { thresholdPct = String(th) }
                }
                onValidityChange(Double(thresholdPct) != nil)
            }
            .onChange(of: thresholdPct) { _, _ in
                var dict: [String: Any] = [:]
                if let data = paramsJson.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] { dict = obj }
                if let th = Double(thresholdPct) { dict["threshold_pct"] = th }
                if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]), let s = String(data: data, encoding: .utf8) { paramsJson = s }
                onValidityChange(Double(thresholdPct) != nil)
            }
        }
    }

    // MARK: - Section subviews

    private struct BasicsSectionView: View {
        @Binding var name: String
        @Binding var enabled: Bool
        @Binding var severity: AlertSeverity
        @Binding var subjectType: AlertSubjectType
        let selectedScopeName: String
        let requiresNumericScope: Bool
        @Binding var subjectReference: String
        var onChooseScope: () -> Void
        var body: some View {
            Section("Basics") {
                LabeledContent("Name") {
                    TextField("", text: $name)
                        .textFieldStyle(.plain)
                        .frame(minWidth: 420)
                        .dsField()
                }
                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Enabled", isOn: $enabled)
                            .toggleStyle(.checkbox)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text("Severity")
                                .font(.subheadline)
                            SeverityInfoIcon(width: 280)
                        }
                        Picker("", selection: $severity) {
                            ForEach(AlertSeverity.allCases) { Text($0.rawValue.capitalized).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(minWidth: 240, maxWidth: 360)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Subject Type")
                            .font(.subheadline)
                        Picker("", selection: $subjectType) {
                            ForEach(AlertSubjectType.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .labelsHidden()
                        .frame(minWidth: 200, maxWidth: 240)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if requiresNumericScope {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Subject")
                                .font(.subheadline)
                            HStack(spacing: 8) {
                                Text(selectedScopeName)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Button("Choose…") { onChooseScope() }
                            }
                            .frame(minWidth: 200)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Subject Reference")
                                .font(.subheadline)
                            TextField("", text: $subjectReference)
                                .textFieldStyle(.plain)
                                .frame(minWidth: 240)
                                .dsField()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private struct TriggerSectionView: View {
        let triggerTypes: [AlertTriggerTypeRow]
        @Binding var triggerTypeCode: String
        @Binding var showAdvancedJSON: Bool
        @Binding var paramsJson: String
        let jsonError: String?
        var onValidateJSON: () -> Void
        var onInsertTemplate: () -> Void
        var onValidityChange: (Bool) -> Void
        let holdingAbsCurrency: String?
        let holdingsQuantity: Double?
        let holdingsValue: Double?
        var body: some View {
            Section {
                LabeledContent("Trigger Family") {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Picker("", selection: $triggerTypeCode) {
                            ForEach(triggerTypes, id: \.code) { Text($0.displayName).tag($0.code) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 200, alignment: .trailing)
                        .padding(.vertical, 4)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                        )
                    }
                }
                if let current = triggerTypes.first(where: { $0.code == triggerTypeCode }), current.requiresDate {
                    DateTriggerForm(paramsJson: $paramsJson, onValidityChange: onValidityChange)
                }
                if triggerTypeCode == "price" {
                    PriceTriggerForm(paramsJson: $paramsJson, onValidityChange: onValidityChange)
                }
                if triggerTypeCode == "holding_abs" {
                    HoldingAbsTriggerForm(paramsJson: $paramsJson,
                                          onValidityChange: onValidityChange,
                                          instrumentCurrency: holdingAbsCurrency,
                                          holdingsQuantity: holdingsQuantity,
                                          holdingsValue: holdingsValue)
                }
                if triggerTypeCode == "holding_pct" {
                    HoldingPctTriggerForm(paramsJson: $paramsJson, onValidityChange: onValidityChange)
                }
                Toggle("Advanced JSON", isOn: $showAdvancedJSON)
                if showAdvancedJSON {
                    LabeledContent("Params JSON") {
                        VStack(alignment: .leading, spacing: 8) {
                            TextEditor(text: $paramsJson)
                                .font(.system(size: 12, design: .monospaced))
                                .frame(minHeight: 160)
                                .dsTextEditor()
                            HStack(spacing: 8) {
                                Button("Validate") { onValidateJSON() }
                                Button("Template") { onInsertTemplate() }
                                if let err = jsonError { Text(err).foregroundColor(.red).font(.caption) }
                            }
                        }
                        .frame(minWidth: 560)
                    }
                }
            }
            header: {
                TriggerHeaderView(triggerTypes: triggerTypes, triggerTypeCode: $triggerTypeCode)
            }
        }
    }

    private struct TriggerHeaderView: View {
        let triggerTypes: [AlertTriggerTypeRow]
        @Binding var triggerTypeCode: String
        @State private var headerHovered: Bool = false
        @State private var popoverHovered: Bool = false

        private var binding: Binding<Bool> {
            Binding(
                get: { headerHovered || popoverHovered },
                set: { value in
                    if !value {
                        headerHovered = false
                        popoverHovered = false
                    }
                }
            )
        }

        var body: some View {
            HStack(spacing: 6) {
                Text("Trigger")
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                    .popover(isPresented: binding, arrowEdge: .top) {
                        popoverContent
                            .onHover { hovering in
                                popoverHovered = hovering
                                if !hovering && !headerHovered {
                                    DispatchQueue.main.async { popoverHovered = false }
                                }
                            }
                    }
            }
            .font(.headline)
            .onHover { hovering in
                if hovering {
                    headerHovered = true
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                        if !popoverHovered {
                            headerHovered = false
                        }
                    }
                }
            }
        }

        private var popoverContent: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Trigger")
                    .font(.headline)
                Text("Trigger family defines how the alert condition is evaluated and which parameters apply. Choose the family that matches your use case; additional inputs appear below once selected.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                if let current = triggerTypes.first(where: { $0.code == triggerTypeCode }), current.requiresDate {
                    Divider()
                    Text("This trigger fires on a specific date. Set the exact date below to schedule when the alert should activate.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .frame(width: 320)
        }
    }

    private struct SchedulingSectionView: View {
        @Binding var scheduleStart: Date?
        @Binding var scheduleEnd: Date?
        @Binding var muteUntil: Date?
        var body: some View {
            Section("Scheduling") {
                OptionalDateField(title: "Start", date: $scheduleStart)
                OptionalDateField(title: "End", date: $scheduleEnd)
                OptionalDateField(title: "Mute Until", date: $muteUntil)
            }
        }
    }

    private struct OptionalDateField: View {
        let title: String
        @Binding var date: Date?
        @State private var showPicker: Bool = false
        @State private var tempDate: Date = .init()
        var body: some View {
            LabeledContent(title) {
                Button {
                    tempDate = date ?? Date()
                    showPicker = true
                } label: {
                    HStack {
                        let text = date.map { displayDateFormatter.string(from: $0) } ?? ""
                        Text(text)
                            .foregroundColor(date == nil ? .secondary : .primary)
                            .frame(minWidth: 120, alignment: .leading)
                        Spacer()
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showPicker, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 16) {
                        DatePicker("Select Date", selection: $tempDate, displayedComponents: [.date])
                            .datePickerStyle(.graphical)
                        HStack {
                            Button("Clear") {
                                date = nil
                                showPicker = false
                            }
                            Spacer()
                            Button("Set") {
                                date = tempDate
                                showPicker = false
                            }
                            .keyboardShortcut(.defaultAction)
                        }
                    }
                    .padding(16)
                    .frame(width: 320)
                }
            }
        }
    }

    private struct NotesAndTagsSectionView: View {
        @Binding var notes: String?
        let allTags: [TagRow]
        @Binding var selectedTags: Set<Int>
        var body: some View {
            Section("Notes & Tags") {
                ViewThatFits(in: .horizontal) {
                    notesAndTagsRow
                    notesAndTagsColumn
                }
            }
        }

        private var notesEditorBinding: Binding<String> {
            Binding(get: { notes ?? "" }, set: { notes = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 })
        }

        private var notesAndTagsRow: some View {
            HStack(alignment: .top, spacing: 16) {
                notesBlock
                tagsBlock
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        private var notesAndTagsColumn: some View {
            VStack(alignment: .leading, spacing: 12) {
                notesBlock
                tagsBlock
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        private var notesBlock: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text("Notes")
                    .font(.subheadline)
                TextEditor(text: notesEditorBinding)
                    .multilineTextAlignment(.leading)
                    .frame(minHeight: 140)
                    .dsTextEditor()
            }
            .frame(minWidth: 260, maxWidth: .infinity, alignment: .leading)
        }

        private var tagsBlock: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("Tags")
                        .font(.subheadline.weight(.bold))
                    TagsInfoIcon(width: 280)
                }
                TagsListView(tags: allTags, selected: $selectedTags)
            }
            .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)
        }
    }

    private struct SeverityInfoIcon: View {
        let width: CGFloat
        @State private var hoverIcon = false
        @State private var hoverPopover = false

        private var binding: Binding<Bool> {
            Binding(
                get: { hoverIcon || hoverPopover },
                set: { value in
                    if !value {
                        hoverIcon = false
                        hoverPopover = false
                    }
                }
            )
        }

        var body: some View {
            Image(systemName: "info.circle")
                .foregroundColor(.secondary)
                .padding(4)
                .popover(isPresented: binding, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Severity")
                            .font(.headline)
                        Text("Severity controls how prominently an alert is surfaced in lists and notifications.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(width: width)
                    .onHover { hovering in
                        hoverPopover = hovering
                        if !hovering && !hoverIcon {
                            DispatchQueue.main.async { hoverPopover = false }
                        }
                    }
                }
                .onHover { hovering in
                    if hovering {
                        hoverIcon = true
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                            if !hoverPopover {
                                hoverIcon = false
                            }
                        }
                    }
                }
        }
    }

    private struct TagsInfoIcon: View {
        let width: CGFloat
        @State private var hoverIcon = false
        @State private var hoverPopover = false

        private var binding: Binding<Bool> {
            Binding(
                get: { hoverIcon || hoverPopover },
                set: { value in
                    if !value {
                        hoverIcon = false
                        hoverPopover = false
                    }
                }
            )
        }

        var body: some View {
            Image(systemName: "info.circle")
                .foregroundColor(.secondary)
                .padding(4)
                .popover(isPresented: binding, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.headline)
                        Text("Tags let you group and filter alerts. Select all tags that apply; manage tag definitions in Settings → Tags.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(width: width)
                    .onHover { hovering in
                        hoverPopover = hovering
                        if !hovering && !hoverIcon {
                            DispatchQueue.main.async { hoverPopover = false }
                        }
                    }
                }
                .onHover { hovering in
                    if hovering {
                        hoverIcon = true
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                            if !hoverPopover {
                                hoverIcon = false
                            }
                        }
                    }
                }
        }
    }

    private struct ThresholdsSectionView: View {
        @Binding var nearValueText: String
        @Binding var nearUnitText: String
        @State private var headerHovered: Bool = false
        @State private var popoverHovered: Bool = false

        private var infoPopoverBinding: Binding<Bool> {
            Binding(
                get: { headerHovered || popoverHovered },
                set: { newValue in
                    if !newValue {
                        headerHovered = false
                        popoverHovered = false
                    }
                }
            )
        }

        private func handleHeaderHover(_ hovering: Bool) {
            if hovering {
                headerHovered = true
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                    if !popoverHovered {
                        headerHovered = false
                    }
                }
            }
        }

        var body: some View {
            Section {
                LabeledContent("Near Window") {
                    HStack(spacing: 8) {
                        TextField("", text: $nearValueText)
                            .textFieldStyle(.plain)
                            .frame(width: 180)
                            .dsField()
                            .foregroundColor(nearValueText.trimmingCharacters(in: .whitespaces).isEmpty || Double(nearValueText) != nil ? .primary : .red)
                        Picker("", selection: $nearUnitText) {
                            Text("—").tag("")
                            Text("pct").tag("pct")
                            Text("abs").tag("abs")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 140)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .help("Marks this alert as ‘Near’ when the measured value is within the given window of the threshold. Use pct for percent (e.g., 2 = 2%) or abs for absolute units (e.g., CHF). This does not trigger the alert; it only classifies proximity.")
                }
            } header: {
                HStack(spacing: 6) {
                    Text("Thresholds")
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Threshold details")
                        .popover(isPresented: infoPopoverBinding, arrowEdge: .top) {
                            infoPopover
                                .onHover { hovering in
                                    popoverHovered = hovering
                                    if !hovering && !headerHovered {
                                        DispatchQueue.main.async {
                                            popoverHovered = false
                                        }
                                    }
                                }
                        }
                }
                .font(.headline)
                .onHover { hovering in
                    handleHeaderHover(hovering)
                }
            }
        }

        private var infoPopover: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Thresholds")
                    .font(.headline)
                Text("Set an optional near window to flag alerts that are approaching their trigger threshold without firing. Enter a numeric value and choose pct for percentages (e.g. 2 = 2%) or abs for absolute units such as CHF or shares. Leaving the field blank disables the proximity classification.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(width: 320)
        }
    }
}

private extension AlertEditorView {
    // (moved helpers to file scope below)

    private func handleSubjectTypeChange(_ newType: AlertSubjectType) {
        if newType.requiresNumericScope {
            subjectReferenceText = ""
            syncSubjectReferenceFromScope()
        } else {
            alert.scopeId = 0
            subjectReferenceText = alert.subjectReference ?? ""
            syncSubjectReferenceFromText()
        }
    }

    private func syncSubjectReferenceFromScope() {
        guard alert.scopeType.requiresNumericScope else { return }
        alert.subjectReference = alert.scopeId > 0 ? String(alert.scopeId) : nil
    }

    private func syncSubjectReferenceFromText() {
        guard !alert.scopeType.requiresNumericScope else { return }
        let trimmed = subjectReferenceText.trimmingCharacters(in: .whitespacesAndNewlines)
        alert.subjectReference = trimmed.isEmpty ? nil : trimmed
    }

    private func updateHoldingAbsContext() {
        guard alert.triggerTypeCode == "holding_abs" else {
            holdingAbsCurrency = nil
            holdingAbsQuantity = nil
            holdingAbsValue = nil
            return
        }

        guard alert.scopeType == .Instrument else {
            holdingAbsCurrency = nil
            holdingAbsQuantity = nil
            holdingAbsValue = nil
            return
        }

        var instrumentId = alert.scopeId
        if instrumentId <= 0, let reference = alert.subjectReference, let parsed = Int(reference) {
            instrumentId = parsed
        }

        guard instrumentId > 0, let snapshot = dbManager.holdingValueSnapshot(instrumentId: instrumentId) else {
            holdingAbsCurrency = nil
            holdingAbsQuantity = nil
            holdingAbsValue = nil
            return
        }

        holdingAbsCurrency = snapshot.currency
        holdingAbsQuantity = snapshot.quantity
        holdingAbsValue = snapshot.value
    }

    private func syncScheduleStrings() {
        alert.scheduleStart = scheduleStartDate.map { isoOutputFormatter.string(from: $0) }
        alert.scheduleEnd = scheduleEndDate.map { isoOutputFormatter.string(from: $0) }
        alert.muteUntil = muteUntilDate.map { isoOutputFormatter.string(from: $0) }
    }

    private func validateJSON() {
        if let data = alert.paramsJson.data(using: .utf8), (try? JSONSerialization.jsonObject(with: data)) != nil {
            jsonError = nil
        } else { jsonError = "Invalid JSON" }
    }

    private func insertTemplate() {
        switch alert.triggerTypeCode {
        case "date": alert.paramsJson = "{\n  \"date\": \"2025-12-31\"\n}"
        case "price": alert.paramsJson = "{\n  \"mode\": \"cross\",\n  \"threshold\": 75.0,\n  \"currency_mode\": \"instrument\"\n}"
        case "holding_abs": alert.paramsJson = "{\n  \"threshold_chf\": 30000.0,\n  \"currency_mode\": \"base\"\n}"
        case "holding_pct": alert.paramsJson = "{\n  \"threshold_pct\": 10.0\n}"
        default: alert.paramsJson = "{}"
        }
    }

    private func evaluateNow() {
        // For unsaved alerts, run a local preview (no event creation)
        if alert.id < 0 {
            switch alert.triggerTypeCode {
            case "date":
                // Parse date from paramsJson
                var d = ""
                if let data = alert.paramsJson.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dateStr = obj["date"] as? String
                {
                    d = dateStr.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                guard isDateStrict(d) else {
                    evalNowMessage = "Invalid date (use YYYY-MM-DD)"
                    evalNowStyle = "error"
                    jsonError = evalNowMessage
                    return
                }
                let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.timeZone = TimeZone(secondsFromGMT: 0); df.dateFormat = "yyyy-MM-dd"
                let today = df.string(from: Date())
                if let todayDate = df.date(from: today), let triggerDate = df.date(from: d) {
                    if todayDate >= triggerDate {
                        evalNowMessage = "Would trigger now (save to record event)"
                        evalNowStyle = "success"
                    } else {
                        evalNowMessage = "Not due yet (date: \(d))"
                        evalNowStyle = "info"
                    }
                } else {
                    evalNowMessage = "Date parse error"
                    evalNowStyle = "error"
                }
            default:
                evalNowMessage = "Evaluate Now preview only supports date trigger in this phase"
                evalNowStyle = "info"
            }
            #if os(macOS)
                NSSound.beep()
            #endif
            return
        }

        let result = dbManager.evaluateAlertNow(alertId: alert.id)
        #if os(macOS)
            NSSound.beep()
        #endif
        // Classify banner style
        evalNowMessage = result.1
        if result.0 {
            evalNowStyle = "success"
        } else {
            let lower = result.1.lowercased()
            if lower.contains("missing") || lower.contains("invalid") || lower.contains("failed") || lower.contains("not found") {
                evalNowStyle = "error"
            } else {
                evalNowStyle = "info"
            }
        }
        if !result.0 { jsonError = result.1 }
        // Refresh today flag in case we created an event
        refreshTodayTriggerFlag()
    }
}

// MARK: - Scope loader

private extension AlertEditorView {
    @ViewBuilder var evaluateBannerView: some View {
        if let msg = evalNowMessage {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: evalNowStyle == "success" ? "checkmark.seal.fill" : (evalNowStyle == "error" ? "exclamationmark.triangle.fill" : "info.circle.fill"))
                    .foregroundColor(.white)
                    .font(.system(size: 22, weight: .bold))
                Text(msg)
                    .foregroundColor(.white)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(evalNowStyle == "success" ? Color.green.opacity(0.9) : (evalNowStyle == "error" ? Color.red.opacity(0.95) : Color.blue.opacity(0.9)))
            )
            .padding([.horizontal, .top], 16)
        }
    }

    func refreshTodayTriggerFlag() {
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.timeZone = TimeZone(secondsFromGMT: 0); df.dateFormat = "yyyy-MM-dd"
        if let today = df.date(from: df.string(from: Date())), alert.id > 0 {
            hasTodayTrigger = dbManager.hasTriggeredEventOnDay(alertId: alert.id, day: today)
        } else { hasTodayTrigger = false }
    }

    func resetTodaysTrigger() {
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.timeZone = TimeZone(secondsFromGMT: 0); df.dateFormat = "yyyy-MM-dd"
        guard let today = df.date(from: df.string(from: Date())) else { return }
        let deleted = dbManager.deleteTriggeredEventsOnDay(alertId: alert.id, day: today)
        hasTodayTrigger = false
        showResetConfirm = false
        evalNowMessage = deleted > 0 ? "Today’s trigger reset (\(deleted) event(s) removed)." : "No event to reset for today."
        evalNowStyle = deleted > 0 ? "success" : "info"
    }

    func loadScopeOptions(limit: Int = 500) {
        switch alert.scopeType {
        case .Instrument:
            let items = dbManager.listInstrumentNames(limit: limit)
            scopeNames = items.map { $0.name }
            scopeIdMap = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.name) })
        case .Account:
            let items = dbManager.listAccountNames(limit: limit)
            scopeNames = items.map { $0.name }
            scopeIdMap = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.name) })
        case .PortfolioTheme:
            let items = dbManager.listPortfolioThemeNames(limit: limit)
            scopeNames = items.map { $0.name }
            scopeIdMap = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.name) })
        case .AssetClass:
            let items = dbManager.listAssetClassNames(limit: limit)
            scopeNames = items.map { $0.name }
            scopeIdMap = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.name) })
        case .Portfolio:
            scopeNames = []
            scopeIdMap = [:]
        case .Global, .MarketEvent, .EconomicSeries, .CustomGroup, .NotApplicable:
            scopeNames = []
            scopeIdMap = [:]
        }
        if let n = scopeIdMap[alert.scopeId] { scopeText = n } else { scopeText = "" }
    }
    // Typed trigger sync helpers are handled in their subviews
}
