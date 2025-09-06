import SwiftUI

struct AlertTriggerTypeSettingsView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var rows: [AlertTriggerTypeRow] = []
    @State private var newCode: String = ""
    @State private var newName: String = ""
    @State private var newDesc: String = ""
    @State private var error: String?
    @FocusState private var addFocus: AddField?

    private enum AddField { case code, name, desc }

    private var canAdd: Bool {
        let code = newCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !code.isEmpty && !name.isEmpty && !rows.contains { $0.code.caseInsensitiveCompare(code) == .orderedSame }
    }
    @State private var info: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Alert Trigger Types").font(.title3).bold(); Spacer() }
            HStack(spacing: 8) {
                TextField("Code (unique)", text: $newCode)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                    .help("Unique code; used as FK in alerts")
                    .focused($addFocus, equals: .code)
                    .onChange(of: newCode) { _, val in
                        let trimmed = val.trimmingCharacters(in: .whitespaces)
                        if trimmed != val { newCode = trimmed }
                        newCode = newCode.lowercased()
                    }
                TextField("Display name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 200)
                    .focused($addFocus, equals: .name)
                TextField("Description (optional)", text: $newDesc)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 260)
                    .focused($addFocus, equals: .desc)
                    .onSubmit { if canAdd { addType() } }
                Button("Add Type") { addType() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canAdd)
            }
            if let err = error { Text(err).foregroundColor(.red).font(.caption) }
            Text("Codes are lowercase and must be unique.")
                .font(.caption)
                .foregroundColor(.secondary)

            Table(rows, selection: .constant(nil)) {
                TableColumn("Order") { row in
                    Stepper("\(row.sortOrder)", value: Binding(
                        get: { row.sortOrder },
                        set: { new in
                            if let idx = rows.firstIndex(where: { $0.id == row.id }) {
                                rows[idx] = AlertTriggerTypeRow(id: row.id, code: row.code, displayName: row.displayName, description: row.description, sortOrder: new, active: row.active)
                                save(rows[idx])
                            } else {
                                save(row)
                            }
                        }
                    )).frame(width: 80)
                }.width(90)
                TableColumn("Code") { row in
                    TextField("Code", text: binding(for: row).code)
                        .onSubmit { save(row) }
                        .frame(width: 160)
                }
                TableColumn("Display Name") { row in
                    TextField("Name", text: binding(for: row).name)
                        .onSubmit { save(row) }
                        .frame(width: 220)
                }
                TableColumn("Description") { row in
                    TextField("Description", text: binding(for: row).desc)
                        .onSubmit { save(row) }
                        .frame(minWidth: 260)
                }
                TableColumn("Active") { row in
                    Toggle("", isOn: binding(for: row).active)
                        .labelsHidden()
                        .onChange(of: binding(for: row).active.wrappedValue) { _, _ in save(row) }
                }.width(60)
                TableColumn("Actions") { row in
                    HStack(spacing: 8) {
                        Button("Save") { save(row) }
                        if row.active { Button("Deactivate", role: .destructive) { delete(row) } }
                        else { Button("Restore") { restore(row) } }
                    }
                }.width(180)
            }
            .frame(minHeight: 280)
            .overlay(alignment: .bottomLeading) {
                Text(info ?? "Save changes or Deactivate/Restore. Use Stepper to adjust order.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack { Button("Save Order") { saveOrder() }; Spacer() }
        }
        .padding(16)
        .navigationTitle("Alert Trigger Types")
        .onAppear { load() }
    }

    private func binding(for row: AlertTriggerTypeRow) -> (code: Binding<String>, name: Binding<String>, desc: Binding<String>, active: Binding<Bool>) {
        guard let idx = rows.firstIndex(where: { $0.id == row.id }) else {
            return (Binding.constant(row.code), Binding.constant(row.displayName), Binding.constant(row.description ?? ""), Binding.constant(row.active))
        }
        return (
            Binding<String>(
                get: { rows[idx].code },
                set: { rows[idx] = AlertTriggerTypeRow(id: row.id, code: $0, displayName: rows[idx].displayName, description: rows[idx].description, sortOrder: rows[idx].sortOrder, active: rows[idx].active) }
            ),
            Binding<String>(
                get: { rows[idx].displayName },
                set: { rows[idx] = AlertTriggerTypeRow(id: row.id, code: rows[idx].code, displayName: $0, description: rows[idx].description, sortOrder: rows[idx].sortOrder, active: rows[idx].active) }
            ),
            Binding<String>(
                get: { rows[idx].description ?? "" },
                set: { rows[idx] = AlertTriggerTypeRow(id: row.id, code: rows[idx].code, displayName: rows[idx].displayName, description: $0, sortOrder: rows[idx].sortOrder, active: rows[idx].active) }
            ),
            Binding<Bool>(
                get: { rows[idx].active },
                set: { rows[idx] = AlertTriggerTypeRow(id: row.id, code: rows[idx].code, displayName: rows[idx].displayName, description: rows[idx].description, sortOrder: rows[idx].sortOrder, active: $0) }
            )
        )
    }

    private func load() {
        rows = dbManager.listAlertTriggerTypes()
        if newCode.isEmpty { newCode = nextCodeSuggestion() }
        addFocus = .code
    }

    private func nextCodeSuggestion() -> String {
        let base = "custom"
        var n = 1
        let codes = Set(rows.map { $0.code })
        var proposal = base
        while codes.contains(proposal) {
            n += 1
            proposal = base + "\(n)"
        }
        return proposal
    }

    private func addType() {
        let code = newCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = newDesc.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty && !name.isEmpty else { return }
        if rows.contains(where: { $0.code.caseInsensitiveCompare(code) == .orderedSame }) {
            error = "Code already exists"; return
        }
        let order = (rows.map { $0.sortOrder }.max() ?? 0) + 1
        if let created = dbManager.createAlertTriggerType(code: code.lowercased(), displayName: name, description: desc.isEmpty ? nil : desc, sortOrder: order, active: true) {
            rows.append(created)
            rows.sort { $0.sortOrder < $1.sortOrder }
            newName = ""; newDesc = ""; newCode = nextCodeSuggestion(); error = nil; addFocus = .code
        } else { error = "Failed to add type (unique code?)" }
    }

    private func save(_ row: AlertTriggerTypeRow) {
        let ok = dbManager.updateAlertTriggerType(id: row.id, code: row.code, displayName: row.displayName, description: row.description, sortOrder: row.sortOrder, active: row.active)
        if ok { info = "Saved \(row.code)"; error = nil } else { error = "Failed to save row (unique code?)"; info = nil }
        load()
    }

    private func saveOrder() {
        let orderedIds = rows.sorted { $0.sortOrder < $1.sortOrder }.map { $0.id }
        if dbManager.reorderAlertTriggerTypes(idsInOrder: orderedIds) { info = "Order saved"; error = nil } else { error = "Failed to save order"; info = nil }
        load()
    }

    private func delete(_ row: AlertTriggerTypeRow) {
        if dbManager.deleteAlertTriggerType(id: row.id) {
            if let idx = rows.firstIndex(where: { $0.id == row.id }) {
                rows[idx] = AlertTriggerTypeRow(id: row.id, code: row.code, displayName: row.displayName, description: row.description, sortOrder: row.sortOrder, active: false)
            }
            info = "Deactivated \(row.code)"; error = nil
        } else { error = "No change (already inactive?)"; info = nil }
    }

    private func restore(_ row: AlertTriggerTypeRow) {
        let ok = dbManager.updateAlertTriggerType(id: row.id, code: nil, displayName: nil, description: nil, sortOrder: nil, active: true)
        if ok {
            if let idx = rows.firstIndex(where: { $0.id == row.id }) {
                rows[idx] = AlertTriggerTypeRow(id: row.id, code: row.code, displayName: row.displayName, description: row.description, sortOrder: row.sortOrder, active: true)
            }
            info = "Restored \(row.code)"; error = nil
        } else { error = "Failed to restore \(row.code)"; info = nil }
    }
}
