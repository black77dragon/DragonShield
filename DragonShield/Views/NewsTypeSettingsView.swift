import SwiftUI

struct NewsTypeSettingsView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var rows: [NewsTypeRow] = []
    @State private var newCode: String = ""
    @State private var newName: String = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("News Types")
                    .font(.title3).bold()
                Spacer()
                Button("Add Type") { addType() }
                    .disabled(newCode.isEmpty || newName.isEmpty)
            }
            HStack {
                TextField("Code (unique)", text: $newCode)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                TextField("Display name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
            }
            if let err = error { Text(err).foregroundColor(.red).font(.caption) }

            Table(rows, selection: .constant(nil)) {
                TableColumn("⇅ Order") { row in
                    Text("\(row.sortOrder)")
                        .foregroundColor(.secondary)
                }.width(50)
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
            }
            .frame(minHeight: 280)
            .overlay(alignment: .bottomLeading) {
                Text("Drag to reorder by changing the order numbers.")
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
        } else {
            error = "Failed to add type (check unique code)"
        }
    }

    private func save(_ row: NewsTypeRow) {
        _ = dbManager.updateNewsType(id: row.id, code: row.code, displayName: row.displayName, sortOrder: row.sortOrder, active: row.active)
        load()
    }

    private func saveOrder() {
        // Persist order by current position (1..n)
        let orderedIds = rows.sorted { $0.sortOrder < $1.sortOrder }.map { $0.id }
        _ = dbManager.reorderNewsTypes(idsInOrder: orderedIds)
        load()
    }
}
