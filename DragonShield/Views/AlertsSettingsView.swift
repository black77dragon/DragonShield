import SwiftUI

struct AlertsSettingsView: View {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Alerts").font(.title3).bold()
                Spacer()
                Toggle("Show disabled", isOn: $includeDisabled)
                    .onChange(of: includeDisabled) { _, _ in load() }
                Button("New Alert") { openNew() }
            }
            if let err = error { Text(err).foregroundColor(.red).font(.caption) }
            Table(rows, selection: .constant(nil)) {
                TableColumn("Enabled") { row in
                    Toggle("", isOn: Binding(
                        get: { row.enabled },
                        set: { val in _ = dbManager.updateAlert(row.id, fields: ["enabled": val]); load() }
                    )).labelsHidden()
                }.width(60)
                TableColumn("Name") { row in Text(row.name) }
                TableColumn("Severity") { row in Text(row.severity.rawValue) }.width(90)
                TableColumn("Scope") { row in Text("\(row.scopeType.rawValue)#\(row.scopeId)") }.width(140)
                TableColumn("Type") { row in Text(row.triggerTypeCode) }.width(120)
                TableColumn("Updated") { row in Text(row.updatedAt) }.width(180)
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

    var body: some View {
        VStack(spacing: 0) {
            Text(alert.id < 0 ? "Create Alert" : "Edit Alert")
                .font(.title2).bold()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.top, .horizontal], 16)
            Divider()
            ScrollView {
                Form {
                    Section("Basics") {
                        LabeledContent("Name") {
                            TextField("", text: $alert.name)
                                .textFieldStyle(.plain)
                                .frame(minWidth: 420)
                                .dsField()
                        }
                        LabeledContent("Enabled") {
                            Toggle("", isOn: $alert.enabled).labelsHidden()
                        }
                        LabeledContent("Severity") {
                            Picker("", selection: Binding(get: { alert.severity }, set: { alert.severity = $0 })) {
                                ForEach(AlertSeverity.allCases) { Text($0.rawValue.capitalized).tag($0) }
                            }.pickerStyle(.segmented).frame(width: 360)
                        }
                        LabeledContent("Scope") {
                            HStack(spacing: 8) {
                                Picker("", selection: Binding(get: { alert.scopeType }, set: { alert.scopeType = $0 })) {
                                    ForEach(AlertScopeType.allCases) { Text($0.rawValue).tag($0) }
                                }.frame(width: 260)
                                TextField("ID", value: $alert.scopeId, format: .number)
                                    .textFieldStyle(.plain)
                                    .frame(width: 180)
                                    .dsField()
                            }
                        }
                    }
                    Section("Trigger") {
                        LabeledContent("Type") {
                            Picker("", selection: Binding(get: { alert.triggerTypeCode }, set: { alert.triggerTypeCode = $0 })) {
                                ForEach(triggerTypes, id: \.code) { Text($0.displayName).tag($0.code) }
                            }.frame(width: 360)
                        }
                        LabeledContent("Params JSON") {
                            VStack(alignment: .leading, spacing: 8) {
                                TextEditor(text: $alert.paramsJson)
                                    .font(.system(size: 12, design: .monospaced))
                                    .frame(minHeight: 200)
                                    .dsTextEditor()
                                HStack(spacing: 8) {
                                    Button("Validate") { validateJSON() }
                                    Button("Template") { insertTemplate() }
                                    if let err = jsonError { Text(err).foregroundColor(.red).font(.caption) }
                                }
                            }
                            .frame(minWidth: 560)
                        }
                    }
                    Section("Thresholds") {
                        LabeledContent("Near Window") {
                            HStack(spacing: 8) {
                                TextField("value", value: Binding(get: { alert.nearValue }, set: { alert.nearValue = $0 }), format: .number)
                                    .textFieldStyle(.plain)
                                    .frame(width: 180)
                                    .dsField()
                                Picker("", selection: Binding(get: { alert.nearUnit ?? "" }, set: { alert.nearUnit = $0.isEmpty ? nil : $0 })) {
                                    Text("—").tag("")
                                    Text("pct").tag("pct")
                                    Text("abs").tag("abs")
                                }.frame(width: 140)
                            }
                        }
                        LabeledContent("Hysteresis") {
                            HStack(spacing: 8) {
                                TextField("value", value: Binding(get: { alert.hysteresisValue }, set: { alert.hysteresisValue = $0 }), format: .number)
                                    .textFieldStyle(.plain)
                                    .frame(width: 180)
                                    .dsField()
                                Picker("", selection: Binding(get: { alert.hysteresisUnit ?? "" }, set: { alert.hysteresisUnit = $0.isEmpty ? nil : $0 })) {
                                    Text("—").tag("")
                                    Text("pct").tag("pct")
                                    Text("abs").tag("abs")
                                }.frame(width: 140)
                            }
                        }
                        LabeledContent("Cooldown (s)") {
                            TextField("", value: Binding(get: { alert.cooldownSeconds }, set: { alert.cooldownSeconds = $0 }), format: .number)
                                .textFieldStyle(.plain)
                                .frame(width: 200)
                                .dsField()
                        }
                    }
                    Section("Scheduling") {
                        LabeledContent("Window") {
                            HStack(spacing: 8) {
                                TextField("start ISO8601", text: Binding(get: { alert.scheduleStart ?? "" }, set: { alert.scheduleStart = $0.isEmpty ? nil : $0 }))
                                    .textFieldStyle(.plain)
                                    .frame(width: 320)
                                    .dsField()
                                TextField("end ISO8601", text: Binding(get: { alert.scheduleEnd ?? "" }, set: { alert.scheduleEnd = $0.isEmpty ? nil : $0 }))
                                    .textFieldStyle(.plain)
                                    .frame(width: 320)
                                    .dsField()
                            }
                        }
                        LabeledContent("Mute Until") {
                            TextField("ISO8601", text: Binding(get: { alert.muteUntil ?? "" }, set: { alert.muteUntil = $0.isEmpty ? nil : $0 }))
                                .textFieldStyle(.plain)
                                .frame(width: 320)
                                .dsField()
                        }
                    }
                    Section("Notes & Tags") {
                        LabeledContent("Notes") {
                            TextEditor(text: Binding(get: { alert.notes ?? "" }, set: { alert.notes = $0.isEmpty ? nil : $0 }))
                                .frame(minHeight: 140)
                                .dsTextEditor()
                        }
                        LabeledContent("Tags") {
                            ScrollView(.vertical) {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(allTags) { tag in
                                        Toggle(isOn: Binding(
                                            get: { selectedTags.contains(tag.id) },
                                            set: { val in if val { selectedTags.insert(tag.id) } else { selectedTags.remove(tag.id) } }
                                        )) {
                                            Text(tag.displayName)
                                        }
                                    }
                                }
                            }.frame(minHeight: 120)
                        }
                    }
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
                    Spacer()
                    Button("Evaluate Now") { /* stub */ }
                        .disabled(true)
                        .help("Evaluation engine coming in next phase")
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
        }
}

// (moved helpers to file scope below)

    private func validateJSON() {
        if let data = alert.paramsJson.data(using: .utf8), (try? JSONSerialization.jsonObject(with: data)) != nil {
            jsonError = nil
        } else { jsonError = "Invalid JSON" }
    }

    private func insertTemplate() {
        switch alert.triggerTypeCode {
        case "date": alert.paramsJson = "{\n  \"date\": \"2025-12-31\",\n  \"warn_days\": [14,7,1]\n}"
        case "price": alert.paramsJson = "{\n  \"mode\": \"cross\",\n  \"threshold\": 75.0,\n  \"currency_mode\": \"instrument\"\n}"
        case "holding_abs": alert.paramsJson = "{\n  \"threshold_chf\": 30000.0,\n  \"currency_mode\": \"base\"\n}"
        case "holding_pct": alert.paramsJson = "{\n  \"threshold_pct\": 10.0\n}"
        default: alert.paramsJson = "{}"
        }
    }
}
