import SwiftUI

struct NewsTypeSettingsView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var rows: [NewsTypeRow] = []
    @State private var newCode: String = ""
    @State private var newName: String = ""
    @State private var error: String?
    @FocusState private var addFocus: AddField?

    private enum AddField { case code, name }

    private var canAdd: Bool {
        let code = newCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !code.isEmpty && !name.isEmpty && !rows.contains { $0.code.caseInsensitiveCompare(code) == .orderedSame }
    }
    @State private var info: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("News Types").font(.title3).bold()
                Spacer()
            }
            HStack(spacing: 8) {
                TextField("Code (unique)", text: $newCode)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                    .help("Unique code; will appear in filters if active")
                    .focused($addFocus, equals: .code)
                    .onChange(of: newCode) { _, val in
                        // Normalize: trim and uppercase
                        let trimmed = val.trimmingCharacters(in: .whitespaces)
                        if trimmed != val { newCode = trimmed }
                        newCode = newCode.uppercased()
                    }
                TextField("Display name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 220)
                    .focused($addFocus, equals: .name)
                    .onSubmit { if canAdd { addType() } }
                Button {
                    addType()
                } label: {
                    Text("Add Type")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canAdd)
            }
            .onSubmit { if canAdd { addType() } }
            if let err = error { Text(err).foregroundColor(.red).font(.caption) }
            Text("Tip: codes are uppercase and must be unique. Inactive types won’t appear in pickers.")
                .font(.caption)
                .foregroundColor(.secondary)

            Table(rows, selection: .constant(nil)) {
                TableColumn("Order") { row in
                    Stepper("\(row.sortOrder)", value: Binding(
                        get: { row.sortOrder },
                        set: { new in
                            if let idx = rows.firstIndex(where: { $0.id == row.id }) {
                                rows[idx] = NewsTypeRow(id: row.id, code: row.code, displayName: row.displayName, sortOrder: new, active: row.active)
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
                    TextField("Name", text: binding(for: row).displayName)
                        .onSubmit { save(row) }
                        .frame(width: 220)
                }
                TableColumn("Active") { row in
                    Toggle("", isOn: binding(for: row).active)
                        .labelsHidden()
                        .onChange(of: binding(for: row).active.wrappedValue) { _, _ in save(row) }
                }.width(60)
                TableColumn("Actions") { row in
                    HStack(spacing: 8) {
                        Button("Save") { save(row) }
                        if row.active {
                            Button("Deactivate", role: .destructive) { delete(row) }
                        } else {
                            Button("Restore") { restore(row) }
                        }
                    }
                }.width(180)
            }
            .frame(minHeight: 280)
            .overlay(alignment: .bottomLeading) {
                Text(info ?? "Use Save; Deactivate/Restore to toggle availability. Stepper adjusts order.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            HStack {
                Button("Save Order") { saveOrder() }
                Spacer()
            }
        }
        .padding(16)
        .navigationTitle("News Types")
        .onAppear { load() }
    }

    private func binding(for row: NewsTypeRow) -> (code: Binding<String>, displayName: Binding<String>, active: Binding<Bool>) {
        guard let idx = rows.firstIndex(where: { $0.id == row.id }) else {
            return (Binding.constant(row.code), Binding.constant(row.displayName), Binding.constant(row.active))
        }
        return (
            Binding<String>(
                get: { rows[idx].code },
                set: { rows[idx] = NewsTypeRow(id: row.id, code: $0, displayName: rows[idx].displayName, sortOrder: rows[idx].sortOrder, active: rows[idx].active) }
            ),
            Binding<String>(
                get: { rows[idx].displayName },
                set: { rows[idx] = NewsTypeRow(id: row.id, code: rows[idx].code, displayName: $0, sortOrder: rows[idx].sortOrder, active: rows[idx].active) }
            ),
            Binding<Bool>(
                get: { rows[idx].active },
                set: { rows[idx] = NewsTypeRow(id: row.id, code: rows[idx].code, displayName: rows[idx].displayName, sortOrder: rows[idx].sortOrder, active: $0) }
            )
        )
    }

    private func load() {
        rows = dbManager.listNewsTypes()
        if newCode.isEmpty { newCode = nextCodeSuggestion() }
        addFocus = .code
    }

    private func nextCodeSuggestion() -> String {
        let base = "Custom"
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
        guard !code.isEmpty && !name.isEmpty else { return }
        if rows.contains(where: { $0.code.caseInsensitiveCompare(code) == .orderedSame }) {
            error = "Code already exists"
            return
        }
        let order = (rows.map { $0.sortOrder }.max() ?? 0) + 1
        if let created = dbManager.createNewsType(code: code, displayName: name, sortOrder: order, active: true) {
            rows.append(created)
            rows.sort { $0.sortOrder < $1.sortOrder }
            newName = ""
            newCode = nextCodeSuggestion()
            error = nil
            addFocus = .code
        } else {
            error = "Failed to add type (check unique code)"
        }
    }

    private func save(_ row: NewsTypeRow) {
        let ok = dbManager.updateNewsType(id: row.id, code: row.code, displayName: row.displayName, sortOrder: row.sortOrder, active: row.active)
        if ok { info = "Saved \(row.code)"; error = nil } else { error = "Failed to save row (unique code?)"; info = nil }
        load()
    }

    private func saveOrder() {
        // Persist order by current position (1..n)
        let orderedIds = rows.sorted { $0.sortOrder < $1.sortOrder }.map { $0.id }
        if dbManager.reorderNewsTypes(idsInOrder: orderedIds) { info = "Order saved"; error = nil } else { error = "Failed to save order"; info = nil }
        load()
    }

    private func delete(_ row: NewsTypeRow) {
        // Soft-delete: mark inactive; row stays visible and can be re-activated via toggle
        if dbManager.deleteNewsType(id: row.id) {
            if let idx = rows.firstIndex(where: { $0.id == row.id }) {
                rows[idx] = NewsTypeRow(id: row.id, code: row.code, displayName: row.displayName, sortOrder: row.sortOrder, active: false)
            }
            info = "Deactivated \(row.code)"; error = nil
        } else {
            error = "No change (already inactive?)"; info = nil
        }
    }

    private func restore(_ row: NewsTypeRow) {
        let ok = dbManager.updateNewsType(id: row.id, code: nil, displayName: nil, sortOrder: nil, active: true)
        if ok {
            if let idx = rows.firstIndex(where: { $0.id == row.id }) {
                rows[idx] = NewsTypeRow(id: row.id, code: row.code, displayName: row.displayName, sortOrder: row.sortOrder, active: true)
            }
            info = "Restored \(row.code)"; error = nil
        } else {
            error = "Failed to restore \(row.code)"; info = nil
        }
    }
}
