import SwiftUI

struct TagSettingsView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var rows: [TagRow] = []
    @State private var newCode: String = ""
    @State private var newName: String = ""
    @State private var newColor: String = ""
    @State private var error: String?
    @FocusState private var addFocus: AddField?

    private enum AddField { case code, name, color }

    private var canAdd: Bool {
        let code = newCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !code.isEmpty && !name.isEmpty && !rows.contains { $0.code.caseInsensitiveCompare(code) == .orderedSame }
    }
    @State private var info: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Tags").font(.title3).bold(); Spacer() }
            HStack(spacing: 8) {
                TextField("Code (unique)", text: $newCode)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                    .help("Unique tag code (e.g., 'risk', 'option')")
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
                TextField("Color hex (optional)", text: $newColor)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                    .focused($addFocus, equals: .color)
                    .onSubmit { if canAdd { addTag() } }
                Button("Add Tag") { addTag() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canAdd)
            }
            if let err = error { Text(err).foregroundColor(.red).font(.caption) }
            Text("Codes are lowercase and must be unique. Optional color accepts 6-digit hex like FF8800.")
                .font(.caption)
                .foregroundColor(.secondary)

            Table(rows, selection: .constant(nil)) {
                TableColumn("Order") { row in
                    Stepper("\(row.sortOrder)", value: Binding(
                        get: { row.sortOrder },
                        set: { new in
                            if let idx = rows.firstIndex(where: { $0.id == row.id }) {
                                rows[idx] = TagRow(id: row.id, code: row.code, displayName: row.displayName, color: row.color, sortOrder: new, active: row.active)
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
                TableColumn("Color") { row in
                    TextField("Hex", text: binding(for: row).color)
                        .onSubmit { save(row) }
                        .frame(width: 120)
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
        .navigationTitle("Tags")
        .onAppear { load() }
    }

    private func binding(for row: TagRow) -> (code: Binding<String>, name: Binding<String>, color: Binding<String>, active: Binding<Bool>) {
        guard let idx = rows.firstIndex(where: { $0.id == row.id }) else {
            return (Binding.constant(row.code), Binding.constant(row.displayName), Binding.constant(row.color ?? ""), Binding.constant(row.active))
        }
        return (
            Binding<String>(
                get: { rows[idx].code },
                set: { rows[idx] = TagRow(id: row.id, code: $0, displayName: rows[idx].displayName, color: rows[idx].color, sortOrder: rows[idx].sortOrder, active: rows[idx].active) }
            ),
            Binding<String>(
                get: { rows[idx].displayName },
                set: { rows[idx] = TagRow(id: row.id, code: rows[idx].code, displayName: $0, color: rows[idx].color, sortOrder: rows[idx].sortOrder, active: rows[idx].active) }
            ),
            Binding<String>(
                get: { rows[idx].color ?? "" },
                set: { rows[idx] = TagRow(id: row.id, code: rows[idx].code, displayName: rows[idx].displayName, color: $0.isEmpty ? nil : $0, sortOrder: rows[idx].sortOrder, active: rows[idx].active) }
            ),
            Binding<Bool>(
                get: { rows[idx].active },
                set: { rows[idx] = TagRow(id: row.id, code: rows[idx].code, displayName: rows[idx].displayName, color: rows[idx].color, sortOrder: rows[idx].sortOrder, active: $0) }
            )
        )
    }

    private func load() {
        rows = dbManager.listTags()
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

    private func addTag() {
        let code = newCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let color = newColor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty && !name.isEmpty else { return }
        if rows.contains(where: { $0.code.caseInsensitiveCompare(code) == .orderedSame }) {
            error = "Code already exists"; return
        }
        let order = (rows.map { $0.sortOrder }.max() ?? 0) + 1
        if let created = dbManager.createTag(code: code.lowercased(), displayName: name, color: color.isEmpty ? nil : color, sortOrder: order, active: true) {
            rows.append(created)
            rows.sort { $0.sortOrder < $1.sortOrder }
            newName = ""; newColor = ""; newCode = nextCodeSuggestion(); error = nil; addFocus = .code
        } else { error = "Failed to add tag (unique code?)" }
    }

    private func save(_ row: TagRow) {
        let ok = dbManager.updateTag(id: row.id, code: row.code, displayName: row.displayName, color: row.color, sortOrder: row.sortOrder, active: row.active)
        if ok { info = "Saved \(row.code)"; error = nil } else { error = "Failed to save row (unique code?)"; info = nil }
        load()
    }

    private func saveOrder() {
        let orderedIds = rows.sorted { $0.sortOrder < $1.sortOrder }.map { $0.id }
        if dbManager.reorderTags(idsInOrder: orderedIds) { info = "Order saved"; error = nil } else { error = "Failed to save order"; info = nil }
        load()
    }

    private func delete(_ row: TagRow) {
        if dbManager.deleteTag(id: row.id) {
            if let idx = rows.firstIndex(where: { $0.id == row.id }) {
                rows[idx] = TagRow(id: row.id, code: row.code, displayName: row.displayName, color: row.color, sortOrder: row.sortOrder, active: false)
            }
            info = "Deactivated \(row.code)"; error = nil
        } else { error = "No change (already inactive?)"; info = nil }
    }

    private func restore(_ row: TagRow) {
        let ok = dbManager.updateTag(id: row.id, code: nil, displayName: nil, color: nil, sortOrder: nil, active: true)
        if ok {
            if let idx = rows.firstIndex(where: { $0.id == row.id }) {
                rows[idx] = TagRow(id: row.id, code: row.code, displayName: row.displayName, color: row.color, sortOrder: row.sortOrder, active: true)
            }
            info = "Restored \(row.code)"; error = nil
        } else { error = "Failed to restore \(row.code)"; info = nil }
    }
}
