import SwiftUI

struct AlertTriggerTypeSettingsView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var rows: [AlertTriggerTypeRow] = []
    @State private var newCode: String = ""
    @State private var newName: String = ""
    @State private var newDesc: String = ""
    @State private var error: String?
    @State private var newRequiresDate: Bool = false
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
                Toggle("Requires Date", isOn: $newRequiresDate)
                    .toggleStyle(.switch)
                    .frame(width: 150)
                    .help("Enable when alerts of this type should expose a trigger date field.")
                Button("Add Type") { addType() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canAdd)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let err = error { Text(err).foregroundColor(.red).font(.caption) }
            Text("Codes are lowercase and must be unique.")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Order").font(.caption).foregroundColor(.secondary).frame(width: 60, alignment: .leading)
                    Text("Code").font(.caption).foregroundColor(.secondary).frame(width: 140, alignment: .leading)
                    Text("Display Name").font(.caption).foregroundColor(.secondary).frame(minWidth: 180, alignment: .leading)
                    Text("Description").font(.caption).foregroundColor(.secondary).frame(minWidth: 260, maxWidth: .infinity, alignment: .leading)
                    Text("Requires Date").font(.caption).foregroundColor(.secondary).frame(width: 110, alignment: .center)
                    Text("Active").font(.caption).foregroundColor(.secondary).frame(width: 70, alignment: .center)
                    Text("Actions").font(.caption).foregroundColor(.secondary).frame(width: 160, alignment: .trailing)
                }
                .padding(.horizontal, 2)

                List {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { _, row in
                        rowView(row)
                    }
                    .onMove(perform: moveRows)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 360)
                .environment(\.defaultMinListRowHeight, 36)
                .frame(maxWidth: .infinity)
            }
            .overlay(alignment: .bottomLeading) {
                Text(info ?? "Drag the handle to reorder. Save to persist edits; Deactivate/Restore toggles availability.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationTitle("Alert Trigger Types")
        .onAppear { load() }
#if os(iOS)
        .environment(\.editMode, .constant(.active))
#endif
    }

    private func binding(for row: AlertTriggerTypeRow) -> (code: Binding<String>, name: Binding<String>, desc: Binding<String>, active: Binding<Bool>, requiresDate: Binding<Bool>) {
        guard let idx = rows.firstIndex(where: { $0.id == row.id }) else {
            return (Binding.constant(row.code), Binding.constant(row.displayName), Binding.constant(row.description ?? ""), Binding.constant(row.active), Binding.constant(row.requiresDate))
        }
        return (
            Binding<String>(
                get: { rows[idx].code },
                set: { rows[idx] = AlertTriggerTypeRow(id: row.id, code: $0, displayName: rows[idx].displayName, description: rows[idx].description, sortOrder: rows[idx].sortOrder, active: rows[idx].active, requiresDate: rows[idx].requiresDate) }
            ),
            Binding<String>(
                get: { rows[idx].displayName },
                set: { rows[idx] = AlertTriggerTypeRow(id: row.id, code: rows[idx].code, displayName: $0, description: rows[idx].description, sortOrder: rows[idx].sortOrder, active: rows[idx].active, requiresDate: rows[idx].requiresDate) }
            ),
            Binding<String>(
                get: { rows[idx].description ?? "" },
                set: { rows[idx] = AlertTriggerTypeRow(id: row.id, code: rows[idx].code, displayName: rows[idx].displayName, description: $0, sortOrder: rows[idx].sortOrder, active: rows[idx].active, requiresDate: rows[idx].requiresDate) }
            ),
            Binding<Bool>(
                get: { rows[idx].active },
                set: { rows[idx] = AlertTriggerTypeRow(id: row.id, code: rows[idx].code, displayName: rows[idx].displayName, description: rows[idx].description, sortOrder: rows[idx].sortOrder, active: $0, requiresDate: rows[idx].requiresDate) }
            ),
            Binding<Bool>(
                get: { rows[idx].requiresDate },
                set: { rows[idx] = AlertTriggerTypeRow(id: row.id, code: rows[idx].code, displayName: rows[idx].displayName, description: rows[idx].description, sortOrder: rows[idx].sortOrder, active: rows[idx].active, requiresDate: $0) }
            )
        )
    }

    private func load() {
        rows = dbManager.listAlertTriggerTypes()
        if newCode.isEmpty { newCode = nextCodeSuggestion() }
        newRequiresDate = false
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
        if let created = dbManager.createAlertTriggerType(code: code.lowercased(), displayName: name, description: desc.isEmpty ? nil : desc, sortOrder: order, active: true, requiresDate: newRequiresDate) {
            rows.append(created)
            rows.sort { $0.sortOrder < $1.sortOrder }
            newName = ""; newDesc = ""; newRequiresDate = false; newCode = nextCodeSuggestion(); error = nil; addFocus = .code
        } else { error = "Failed to add type (unique code?)" }
    }

    private func save(_ row: AlertTriggerTypeRow) {
        let ok = dbManager.updateAlertTriggerType(id: row.id, code: row.code, displayName: row.displayName, description: row.description, sortOrder: row.sortOrder, active: row.active, requiresDate: row.requiresDate)
        if ok { info = "Saved \(row.code)"; error = nil } else { error = "Failed to save row (unique code?)"; info = nil }
        load()
    }

    private func delete(_ row: AlertTriggerTypeRow) {
        if dbManager.deleteAlertTriggerType(id: row.id) {
            if let idx = rows.firstIndex(where: { $0.id == row.id }) {
                rows[idx] = AlertTriggerTypeRow(id: row.id, code: row.code, displayName: row.displayName, description: row.description, sortOrder: row.sortOrder, active: false, requiresDate: row.requiresDate)
            }
            info = "Deactivated \(row.code)"; error = nil
        } else { error = "No change (already inactive?)"; info = nil }
    }

    private func restore(_ row: AlertTriggerTypeRow) {
        let ok = dbManager.updateAlertTriggerType(id: row.id, code: nil, displayName: nil, description: nil, sortOrder: nil, active: true, requiresDate: row.requiresDate)
        if ok {
            if let idx = rows.firstIndex(where: { $0.id == row.id }) {
                rows[idx] = AlertTriggerTypeRow(id: row.id, code: row.code, displayName: row.displayName, description: row.description, sortOrder: row.sortOrder, active: true, requiresDate: row.requiresDate)
            }
            info = "Restored \(row.code)"; error = nil
        } else { error = "Failed to restore \(row.code)"; info = nil }
    }

    private func rowView(_ row: AlertTriggerTypeRow) -> some View {
        let binding = binding(for: row)
        return HStack(alignment: .center, spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            Text("\(row.sortOrder)")
                .foregroundColor(.secondary)
                .frame(width: 28, alignment: .trailing)
            TextField("Code", text: binding.code)
                .textFieldStyle(.roundedBorder)
                .frame(width: 140)
                .onSubmit { save(currentRow(row.id)) }
            TextField("Display name", text: binding.name)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 180)
                .onSubmit { save(currentRow(row.id)) }
            TextField("Description", text: binding.desc)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 260, maxWidth: .infinity)
                .onSubmit { save(currentRow(row.id)) }
            Toggle("", isOn: binding.requiresDate)
                .labelsHidden()
                .help("When enabled, alerts of this type expose a trigger date field.")
                .onChange(of: binding.requiresDate.wrappedValue) { _, _ in save(currentRow(row.id)) }
                .frame(width: 40)
            Toggle("", isOn: binding.active)
                .labelsHidden()
                .onChange(of: binding.active.wrappedValue) { _, _ in save(currentRow(row.id)) }
                .frame(width: 40)
            HStack(spacing: 8) {
                Button("Save") { save(currentRow(row.id)) }
                if row.active {
                    Button("Deactivate", role: .destructive) { delete(row) }
                } else {
                    Button("Restore") { restore(row) }
                }
            }
            .frame(width: 150, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func currentRow(_ id: Int) -> AlertTriggerTypeRow {
        if let inMemory = rows.first(where: { $0.id == id }) { return inMemory }
        if let refreshed = dbManager.listAlertTriggerTypes(includeInactive: true).first(where: { $0.id == id }) {
            return refreshed
        }
        return AlertTriggerTypeRow(id: id, code: "", displayName: "", description: nil, sortOrder: 0, active: true, requiresDate: false)
    }

    private func moveRows(from source: IndexSet, to destination: Int) {
        rows.move(fromOffsets: source, toOffset: destination)
        for idx in rows.indices {
            let r = rows[idx]
            rows[idx] = AlertTriggerTypeRow(id: r.id, code: r.code, displayName: r.displayName, description: r.description, sortOrder: idx + 1, active: r.active, requiresDate: r.requiresDate)
        }
        persistCurrentOrder()
    }

    private func persistCurrentOrder() {
        let orderedIds = rows.map { $0.id }
        if dbManager.reorderAlertTriggerTypes(idsInOrder: orderedIds) {
            info = "Order saved"
            error = nil
            load()
        } else {
            error = "Failed to save order"
            info = nil
        }
    }
}
