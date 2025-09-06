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
                        Button("Delete", role: .destructive) { delete(row) }
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
            .frame(width: 820, height: 600)
        }
        .navigationTitle("Alerts")
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
        editing = editing
    }

    private func openEdit(_ row: AlertRow) {
        editing = row
    }

    private func delete(_ row: AlertRow) {
        if dbManager.deleteAlert(id: row.id) { info = "Deleted \(row.name)"; error = nil } else { error = "Failed to delete"; info = nil }
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
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text(alert.id < 0 ? "Create Alert" : "Edit Alert").font(.title3).bold(); Spacer() }
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Name").frame(width: 140, alignment: .leading)
                    TextField("", text: $alert.name).textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Enabled").frame(width: 140, alignment: .leading)
                    Toggle("", isOn: $alert.enabled).labelsHidden()
                }
                GridRow {
                    Text("Severity").frame(width: 140, alignment: .leading)
                    Picker("", selection: Binding(get: { alert.severity }, set: { alert.severity = $0 })) {
                        ForEach(AlertSeverity.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented).frame(width: 300)
                }
                GridRow {
                    Text("Scope Type").frame(width: 140, alignment: .leading)
                    Picker("", selection: Binding(get: { alert.scopeType }, set: { alert.scopeType = $0 })) {
                        ForEach(AlertScopeType.allCases) { Text($0.rawValue).tag($0) }
                    }.frame(width: 300)
                    Text("Scope ID").frame(width: 80, alignment: .trailing)
                    TextField("0", value: $alert.scopeId, format: .number).frame(width: 120)
                }
                GridRow {
                    Text("Trigger Type").frame(width: 140, alignment: .leading)
                    Picker("", selection: Binding(get: { alert.triggerTypeCode }, set: { alert.triggerTypeCode = $0 })) {
                        ForEach(triggerTypes, id: \.code) { Text($0.displayName).tag($0.code) }
                    }.frame(width: 300)
                }
                GridRow {
                    Text("Params JSON").frame(width: 140, alignment: .leading)
                    TextEditor(text: $alert.paramsJson)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(minHeight: 120)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2)))
                }
                GridRow {
                    Text("").frame(width: 140)
                    HStack(spacing: 8) {
                        Button("Validate JSON") { validateJSON() }
                        Button("Template") { insertTemplate() }
                        if let err = jsonError { Text(err).foregroundColor(.red).font(.caption) }
                    }
                }
                GridRow {
                    Text("Near Window").frame(width: 140, alignment: .leading)
                    HStack(spacing: 8) {
                        TextField("value", value: Binding(get: { alert.nearValue }, set: { alert.nearValue = $0 }), format: .number).frame(width: 100)
                        Picker("", selection: Binding(get: { alert.nearUnit ?? "" }, set: { alert.nearUnit = $0.isEmpty ? nil : $0 })) {
                            Text("—").tag("")
                            Text("pct").tag("pct")
                            Text("abs").tag("abs")
                        }.frame(width: 120)
                    }
                }
                GridRow {
                    Text("Hysteresis").frame(width: 140, alignment: .leading)
                    HStack(spacing: 8) {
                        TextField("value", value: Binding(get: { alert.hysteresisValue }, set: { alert.hysteresisValue = $0 }), format: .number).frame(width: 100)
                        Picker("", selection: Binding(get: { alert.hysteresisUnit ?? "" }, set: { alert.hysteresisUnit = $0.isEmpty ? nil : $0 })) {
                            Text("—").tag("")
                            Text("pct").tag("pct")
                            Text("abs").tag("abs")
                        }.frame(width: 120)
                    }
                }
                GridRow {
                    Text("Cooldown (s)").frame(width: 140, alignment: .leading)
                    TextField("", value: Binding(get: { alert.cooldownSeconds }, set: { alert.cooldownSeconds = $0 }), format: .number)
                        .frame(width: 120)
                }
                GridRow {
                    Text("Schedule").frame(width: 140, alignment: .leading)
                    HStack(spacing: 8) {
                        TextField("start ISO8601", text: Binding(get: { alert.scheduleStart ?? "" }, set: { alert.scheduleStart = $0.isEmpty ? nil : $0 })).frame(width: 220)
                        TextField("end ISO8601", text: Binding(get: { alert.scheduleEnd ?? "" }, set: { alert.scheduleEnd = $0.isEmpty ? nil : $0 })).frame(width: 220)
                    }
                }
                GridRow {
                    Text("Mute Until").frame(width: 140, alignment: .leading)
                    TextField("ISO8601", text: Binding(get: { alert.muteUntil ?? "" }, set: { alert.muteUntil = $0.isEmpty ? nil : $0 }))
                        .frame(width: 220)
                }
                GridRow {
                    Text("Notes").frame(width: 140, alignment: .leading)
                    TextEditor(text: Binding(get: { alert.notes ?? "" }, set: { alert.notes = $0.isEmpty ? nil : $0 }))
                        .frame(minHeight: 80)
                }
                GridRow {
                    Text("Tags").frame(width: 140, alignment: .leading)
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(allTags) { tag in
                                Toggle(isOn: Binding(
                                    get: { selectedTags.contains(tag.id) },
                                    set: { val in if val { selectedTags.insert(tag.id) } else { selectedTags.remove(tag.id) } }
                                )) {
                                    Text(tag.displayName).foregroundColor(.primary)
                                }
                            }
                        }
                    }.frame(minHeight: 100)
                }
            }
            HStack {
                Button("Save") { onSave(alert, selectedTags) }
                    .keyboardShortcut(.defaultAction)
                Button("Cancel", role: .cancel) { onCancel() }
                Spacer()
                Button("Evaluate Now") { /* stub */ }
                    .disabled(true)
                    .help("Evaluation engine coming in next phase")
            }
        }
        .padding(16)
        .onAppear {
            if alert.id > 0 {
                let current = dbManager.listTagsForAlert(alertId: alert.id).map { $0.id }
                selectedTags = Set(current)
            } else {
                selectedTags = []
            }
        }
    }

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
