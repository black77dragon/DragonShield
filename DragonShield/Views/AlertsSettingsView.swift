import SwiftUI

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

struct AlertsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var rows: [AlertRow] = []
    @State private var triggerTypes: [AlertTriggerTypeRow] = []
    @State private var allTags: [TagRow] = []
    @State private var includeDisabled = true
    @State private var error: String?
    @State private var info: String?

    @State private var editing: AlertRow? = nil
    @State private var confirmDelete: AlertRow? = nil
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""

    @State private var page: Int = 0 // 0=Alerts, 1=Events, 2=Timeline
    @State private var showTriggerTypes: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("", selection: $page) {
                    Text("Alerts").tag(0)
                    Text("Events").tag(1)
                    Text("Timeline").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
                Spacer()
                if page == 0 {
                    Toggle("Show disabled", isOn: $includeDisabled)
                        .onChange(of: includeDisabled) { _, _ in load() }
                    Button("Edit Alert Types") { showTriggerTypes = true }
                    Button("New Alert") { openNew() }
                }
                Button("Close") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.gray)
                    .foregroundColor(.white)
                    .keyboardShortcut("w", modifiers: .command)
                    .help("Close")
            }
            if let err = error { Text(err).foregroundColor(.red).font(.caption) }
            if page == 0 {
                Table(rows, selection: .constant(nil)) {
                    TableColumn("Enabled") { row in
                        Toggle("", isOn: Binding(
                            get: { row.enabled },
                            set: { val in _ = dbManager.updateAlert(row.id, fields: ["enabled": val]); load() }
                        )).labelsHidden()
                    }.width(60)
                    TableColumn("Name") { row in Text(row.name) }
                    TableColumn("Severity") { row in Text(row.severity.rawValue) }.width(90)
                    TableColumn("Subject") { row in
                        Text(subjectDisplay(for: row))
                    }.width(220)
                    TableColumn("Type") { row in Text(row.triggerTypeCode) }.width(120)
                    TableColumn("Trigger Date") { row in
                        Text(triggerDateDisplay(for: row))
                    }.width(120)
                    TableColumn("Actions") { row in
                        HStack(spacing: 8) {
                            Button("Edit") { openEdit(row) }
                            Button("Delete", role: .destructive) { confirmDelete = row }
                        }
                    }.width(160)
                }
                .frame(minHeight: 320)
                .overlay(alignment: .bottomLeading) {
                    Text(info ?? "Toggle enabled in table. Use Edit to adjust details. Params JSON must be valid.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if page == 1 {
                AlertEventsView().environmentObject(dbManager)
                    .frame(minHeight: 360)
            } else {
                AlertsTimelineView(onOpen: { id in
                    openEditById(id)
                })
                    .environmentObject(dbManager)
                    .frame(minHeight: 360)
            }
        }
        .padding(16)
        .onAppear { load() }
        .sheet(item: $editing) { item in
            AlertEditorView(alert: item,
                             triggerTypes: triggerTypes,
                             allTags: allTags,
                             onSave: { updated, tagIds in
                if let _ = dbManager.getAlert(id: updated.id) {
                    let ok = dbManager.updateAlert(updated.id, fields: fieldsDict(from: updated))
                    let ok2 = dbManager.setAlertTags(alertId: updated.id, tagIds: Array(tagIds))
                    if ok && ok2 { info = "Saved \(updated.name)"; error = nil } else { error = "Failed to save alert"; info = nil }
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
        .navigationTitle("Alerts")
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

    // MARK: - Formatting helpers
    private func triggerDateDisplay(for row: AlertRow) -> String {
        guard triggerTypeRequiresDate(row.triggerTypeCode) else { return "" }
        guard let data = row.paramsJson.data(using: .utf8),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let dateStr = obj["date"] as? String, !dateStr.isEmpty,
              let d = isoOutputFormatter.date(from: dateStr) else { return "" }
        return displayDateFormatter.string(from: d)
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
        rows = dbManager.listAlerts(includeDisabled: includeDisabled)
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
        // Fetch fresh copy to ensure full fields populated
        if let fresh = dbManager.getAlert(id: row.id) { editing = fresh } else { editing = row }
    }

    private func openEditById(_ id: Int) {
        if let fresh = dbManager.getAlert(id: id) {
            editing = fresh
        }
    }

    private func performDelete(_ row: AlertRow) {
        if dbManager.deleteAlert(id: row.id) {
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
            "notes": a.notes
        ]
    }
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
        self
            .padding(6)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            )
    }
    func dsTextEditor() -> some View {
        self
            .scrollContentBackground(.hidden)
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
    // Scope picker state
    @State private var showScopePicker: Bool = false
    @State private var scopeNames: [String] = []
    @State private var scopeIdMap: [Int: String] = [:]
    @State private var scopeText: String = ""
    private var selectedScopeName: String { scopeIdMap[alert.scopeId] ?? "(none)" }
    @State private var subjectReferenceText: String = ""
    // Instrument picker (SearchDropdown) state
    @State private var instrumentRows: [DatabaseManager.InstrumentRow] = []
    @State private var instrumentQuery: String = ""
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
                                       onValidityChange: { ok in triggerValid = ok }))
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
        }
        // Reload available options when scope type changes; clear selection text
        .onChange(of: alert.scopeType) { _, newType in
            alert.scopeId = 0
            scopeText = ""
            loadScopeOptions()
            handleSubjectTypeChange(newType)
        }
        .onChange(of: alert.scopeId) { _, _ in syncSubjectReferenceFromScope() }
        .onChange(of: subjectReferenceText) { _, _ in syncSubjectReferenceFromText() }
        // Trigger type change and typed params are handled inside subviews
        // If JSON changes externally (e.g., Template), typed subviews will re-render with the new JSON
        .onChange(of: alert.paramsJson) { _, _ in }
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
                    SearchDropdown(
                        items: instrumentRows.map { instrumentDisplay($0) },
                        text: $instrumentQuery,
                        placeholder: "Search instrument, ticker, or ISIN",
                        maxVisibleRows: 12,
                        onSelectIndex: { originalIndex in
                            guard originalIndex >= 0 && originalIndex < instrumentRows.count else { return }
                            let sel = instrumentRows[originalIndex]
                            alert.scopeId = sel.id
                            showScopePicker = false
                        }
                    )
                    .frame(minWidth: 520)
                    .onAppear {
                        instrumentRows = dbManager.fetchAssets()
                        instrumentQuery = ""
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
                HStack { Spacer(); Button("Close") { showScopePicker = false } }
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
    @State private var tempDate: Date = Date()
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
               let parsed = isoOutputFormatter.date(from: d) {
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
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            dict = obj
        }
        if let selectedDate {
            dict["date"] = isoOutputFormatter.string(from: selectedDate)
        } else {
            dict.removeValue(forKey: "date")
        }
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
           let s = String(data: data, encoding: .utf8) {
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
    @State private var thresholdCHF: String = ""
    @State private var currencyMode: String = "base"
    var body: some View {
        LabeledContent("Threshold (CHF)") {
            HStack(spacing: 8) {
                TextField("e.g., 30000", text: $thresholdCHF)
                    .textFieldStyle(.plain)
                    .frame(width: 180)
                    .dsField()
                    .foregroundColor(Double(thresholdCHF) != nil ? .primary : .red)
                Picker("", selection: $currencyMode) {
                    Text("Base").tag("base")
                    Text("Instrument").tag("instrument")
                }.frame(width: 160)
            }
        }
        .onAppear {
            if let data = paramsJson.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let th = obj["threshold_chf"] as? Double { thresholdCHF = String(th) }
                if let cm = obj["currency_mode"] as? String { currencyMode = cm }
            }
            onValidityChange(Double(thresholdCHF) != nil)
        }
        .onChange(of: thresholdCHF) { _, _ in syncJSON(); onValidityChange(Double(thresholdCHF) != nil) }
        .onChange(of: currencyMode) { _, _ in syncJSON() }
    }
    private func syncJSON() {
        var dict: [String: Any] = [:]
        if let data = paramsJson.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] { dict = obj }
        if let th = Double(thresholdCHF) { dict["threshold_chf"] = th }
        dict["currency_mode"] = currencyMode
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]), let s = String(data: data, encoding: .utf8) { paramsJson = s }
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
            LabeledContent("Enabled") { Toggle("", isOn: $enabled).labelsHidden() }
            LabeledContent("Severity") {
                Picker("", selection: $severity) {
                    ForEach(AlertSeverity.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }.pickerStyle(.segmented).frame(width: 360)
            }
            Text("Severity controls how prominently an alert is surfaced in lists and notifications.")
                .font(.caption)
                .foregroundColor(.secondary)
            LabeledContent("Subject Type") {
                Picker("", selection: $subjectType) {
                    ForEach(AlertSubjectType.allCases) { Text($0.rawValue).tag($0) }
                }
                .frame(width: 220)
            }
            if requiresNumericScope {
                LabeledContent("Subject") {
                    HStack(spacing: 8) {
                        Text(selectedScopeName)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)
                        Button("Choose…") { onChooseScope() }
                    }
                }
            } else {
                LabeledContent("Subject Reference") {
                    TextField("Enter reference", text: $subjectReference)
                        .textFieldStyle(.plain)
                        .frame(minWidth: 320)
                        .dsField()
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
    var body: some View {
        Section("Trigger") {
            LabeledContent("Trigger Family") {
                Picker("", selection: $triggerTypeCode) {
                    ForEach(triggerTypes, id: \.code) { Text($0.displayName).tag($0.code) }
                }.frame(width: 360)
            }
            Text("Trigger family defines how the alert condition is evaluated and which parameters apply.")
                .font(.caption)
                .foregroundColor(.secondary)
            if let current = triggerTypes.first(where: { $0.code == triggerTypeCode }) {
                Text(current.description ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)
                if current.requiresDate {
                    DateTriggerForm(paramsJson: $paramsJson, onValidityChange: onValidityChange)
                }
            }
            if triggerTypeCode == "price" {
                PriceTriggerForm(paramsJson: $paramsJson, onValidityChange: onValidityChange)
            }
            if triggerTypeCode == "holding_abs" {
                HoldingAbsTriggerForm(paramsJson: $paramsJson, onValidityChange: onValidityChange)
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
    @State private var tempDate: Date = Date()
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
            LabeledContent("Notes") {
                TextEditor(text: Binding(get: { notes ?? "" }, set: { notes = $0.isEmpty ? nil : $0 }))
                    .multilineTextAlignment(.leading)
                    .frame(minHeight: 140)
                    .dsTextEditor()
            }
            LabeledContent("Tags") {
                TagsListView(tags: allTags, selected: $selectedTags)
            }
        }
    }
}
private struct ThresholdsSectionView: View {
    @Binding var nearValueText: String
    @Binding var nearUnitText: String
    var body: some View {
        Section("Thresholds") {
            LabeledContent("Near Window") {
                HStack(spacing: 8) {
                    TextField("value", text: $nearValueText)
                        .textFieldStyle(.plain)
                        .frame(width: 180)
                        .dsField()
                        .foregroundColor(nearValueText.trimmingCharacters(in: .whitespaces).isEmpty || Double(nearValueText) != nil ? .primary : .red)
                    Picker("", selection: $nearUnitText) {
                        Text("—").tag("")
                        Text("pct").tag("pct")
                        Text("abs").tag("abs")
                    }.frame(width: 140)
                }
                .help("Marks this alert as ‘Near’ when the measured value is within the given window of the threshold. Use pct for percent (e.g., 2 = 2%) or abs for absolute units (e.g., CHF). This does not trigger the alert; it only classifies proximity.")
            }
        }
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
                   let dateStr = obj["date"] as? String {
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
