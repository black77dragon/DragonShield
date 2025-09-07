import SwiftUI

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
                    TableColumn("Scope") { row in
                        Text(scopeDisplay(for: row))
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
        guard row.triggerTypeCode == "date" else { return "" }
        guard let data = row.paramsJson.data(using: .utf8),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let dateStr = obj["date"] as? String, !dateStr.isEmpty else { return "" }
        let inDf = DateFormatter(); inDf.locale = Locale(identifier: "en_US_POSIX"); inDf.timeZone = TimeZone(secondsFromGMT: 0); inDf.dateFormat = "yyyy-MM-dd"
        guard let d = inDf.date(from: dateStr) else { return "" }
        let outDf = DateFormatter(); outDf.locale = Locale(identifier: "de_CH"); outDf.dateFormat = "dd.MM.yy"
        return outDf.string(from: d)
    }

    private func scopeDisplay(for row: AlertRow) -> String {
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
            // Fallback using list, as dedicated lookup may not exist yet
            let name = dbManager.fetchPortfolios().first(where: { $0.id == row.scopeId })?.name
            return name ?? "Portfolio #\(row.scopeId)"
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
        return [
            "name": a.name,
            "enabled": a.enabled,
            "severity": a.severity.rawValue,
            "scope_type": a.scopeType.rawValue,
            "scope_id": a.scopeId,
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
    // Scope picker state
    @State private var showScopePicker: Bool = false
    @State private var scopeNames: [String] = []
    @State private var scopeIdMap: [Int: String] = [:]
    @State private var scopeText: String = ""
    private var selectedScopeName: String { scopeIdMap[alert.scopeId] ?? "(none)" }
    // Instrument picker (SearchDropdown) state
    @State private var instrumentRows: [DatabaseManager.InstrumentRow] = []
    @State private var instrumentQuery: String = ""
    // Today trigger reset state
    @State private var hasTodayTrigger: Bool = false
    @State private var showResetConfirm: Bool = false

    // MARK: - Validation
    private func isDateOrEmpty(_ s: String?) -> Bool {
        let t = (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return true }
        // yyyy-MM-dd strict
        let regex = try! NSRegularExpression(pattern: "^\\d{4}-\\d{2}-\\d{2}$")
        guard regex.firstMatch(in: t, range: NSRange(location: 0, length: t.utf16.count)) != nil else { return false }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: t) != nil
    }
    private var datesValid: Bool {
        isDateOrEmpty(alert.scheduleStart) && isDateOrEmpty(alert.scheduleEnd) && isDateOrEmpty(alert.muteUntil)
    }
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
    private var formValid: Bool { datesValid && triggerValid }

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
                                      scopeType: Binding(get: { alert.scopeType }, set: { alert.scopeType = $0 }),
                                      selectedScopeName: selectedScopeName,
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
                    AnyView(SchedulingSectionView(scheduleStart: Binding(get: { alert.scheduleStart }, set: { alert.scheduleStart = $0 }),
                                          scheduleEnd: Binding(get: { alert.scheduleEnd }, set: { alert.scheduleEnd = $0 }),
                                          muteUntil: Binding(get: { alert.muteUntil }, set: { alert.muteUntil = $0 }),
                                          isDateOrEmpty: { s in isDateOrEmpty(s) }))
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
            refreshTodayTriggerFlag()
        }
        // Reload available options when scope type changes; clear selection text
        .onChange(of: alert.scopeType) { _, _ in
            alert.scopeId = 0
            scopeText = ""
            loadScopeOptions()
        }
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
    @State private var dateParam: String = ""
    private func isDateStrict(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        let regex = try! NSRegularExpression(pattern: "^\\d{4}-\\d{2}-\\d{2}$")
        guard regex.firstMatch(in: t, range: NSRange(location: 0, length: t.utf16.count)) != nil else { return false }
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.dateFormat = "yyyy-MM-dd"
        return df.date(from: t) != nil
    }
    var body: some View {
        LabeledContent("Trigger Date") {
            HStack(spacing: 8) {
                TextField("", text: $dateParam)
                    .textFieldStyle(.plain)
                    .frame(width: 200)
                    .dsField()
                    .foregroundColor(isDateStrict(dateParam) ? .primary : .red)
                Button("Today") {
                    let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.dateFormat = "yyyy-MM-dd"; dateParam = df.string(from: Date())
                }
                Text("(YYYY-MM-DD)").foregroundColor(.secondary)
            }
        }
        .onAppear {
            if let data = paramsJson.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let d = obj["date"] as? String {
                dateParam = d
                onValidityChange(isDateStrict(d))
            } else { onValidityChange(false) }
        }
        .onChange(of: dateParam) { _, _ in
            var dict: [String: Any] = [:]
            if let data = paramsJson.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] { dict = obj }
            dict["date"] = dateParam
            if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]), let s = String(data: data, encoding: .utf8) { paramsJson = s }
            onValidityChange(isDateStrict(dateParam))
        }
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
    @Binding var scopeType: AlertScopeType
    let selectedScopeName: String
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
            LabeledContent("Scope") {
                HStack(spacing: 8) {
                    Picker("", selection: $scopeType) {
                        ForEach(AlertScopeType.allCases) { Text($0.rawValue).tag($0) }
                    }.frame(width: 200)
                    Text(selectedScopeName)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(minWidth: 200, maxWidth: .infinity, alignment: .leading)
                    Button("Choose…") { onChooseScope() }
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
            LabeledContent("Type") {
                Picker("", selection: $triggerTypeCode) {
                    ForEach(triggerTypes, id: \.code) { Text($0.displayName).tag($0.code) }
                }.frame(width: 360)
            }
            if triggerTypeCode == "date" { DateTriggerForm(paramsJson: $paramsJson, onValidityChange: onValidityChange) }
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
    @Binding var scheduleStart: String?
    @Binding var scheduleEnd: String?
    @Binding var muteUntil: String?
    var isDateOrEmpty: (String?) -> Bool
    var body: some View {
        Section("Scheduling") {
            LabeledContent("Start") {
                HStack(spacing: 8) {
                    let s = Binding(get: { scheduleStart ?? "" }, set: { scheduleStart = $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 })
                    TextField("", text: s)
                        .textFieldStyle(.plain)
                        .frame(width: 200)
                        .dsField()
                        .foregroundColor(isDateOrEmpty(scheduleStart) ? .primary : .red)
                    Text("(YYYY-MM-DD)").foregroundColor(.secondary)
                }
            }
            LabeledContent("End") {
                HStack(spacing: 8) {
                    let e = Binding(get: { scheduleEnd ?? "" }, set: { scheduleEnd = $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 })
                    TextField("", text: e)
                        .textFieldStyle(.plain)
                        .frame(width: 200)
                        .dsField()
                        .foregroundColor(isDateOrEmpty(scheduleEnd) ? .primary : .red)
                    Text("(YYYY-MM-DD)").foregroundColor(.secondary)
                }
            }
            LabeledContent("Mute Until") {
                HStack(spacing: 8) {
                    let m = Binding(get: { muteUntil ?? "" }, set: { muteUntil = $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 })
                    TextField("", text: m)
                        .textFieldStyle(.plain)
                        .frame(width: 200)
                        .dsField()
                        .foregroundColor(isDateOrEmpty(muteUntil) ? .primary : .red)
                    Text("(YYYY-MM-DD)").foregroundColor(.secondary)
                }
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
        }
        if let n = scopeIdMap[alert.scopeId] { scopeText = n } else { scopeText = "" }
    }
    // Typed trigger sync helpers are handled in their subviews

}
