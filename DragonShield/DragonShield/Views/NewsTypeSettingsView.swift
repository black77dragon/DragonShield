import SwiftUI

struct NewsTypeSettingsView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var rows: [NewsTypeRow] = []
    @State private var originalRows: [NewsTypeRow] = []
    @State private var dirtyRows: Set<Int> = []
    @State private var dirtyDescriptions: Set<Int> = []
    @State private var newCode: String = ""
    @State private var newName: String = ""
    @State private var error: String?
    @FocusState private var addFocus: AddField?
    @State private var showLeaveWarning: Bool = false

    private enum AddField { case code, name }

    private var canAdd: Bool {
        let code = newCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !code.isEmpty && !name.isEmpty && !rows.contains { $0.code.caseInsensitiveCompare(code) == .orderedSame }
    }
    @State private var info: String?

    private var hasUnsavedChanges: Bool { !dirtyRows.isEmpty }

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
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.67, green: 0.89, blue: 0.67))
                .foregroundColor(.black)
                .keyboardShortcut(.defaultAction)
                .disabled(!canAdd)
            }
            .onSubmit { if canAdd { addType() } }
            if let err = error { Text(err).foregroundColor(.red).font(.caption) }
            Text("Tip: codes are uppercase and must be unique. Inactive types won’t appear in pickers.")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Order").font(.caption).foregroundColor(.secondary).frame(width: 60, alignment: .leading)
                    Text("Code").font(.caption).foregroundColor(.secondary).frame(width: 160, alignment: .leading)
                    Text("Display Name").font(.caption).foregroundColor(.secondary).frame(minWidth: 220, alignment: .leading)
                    Text("Active").font(.caption).foregroundColor(.secondary).frame(width: 80, alignment: .center)
                    Spacer()
                    Text("Actions").font(.caption).foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)

                List {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { _, row in
                        rowView(row)
                    }
                    .onMove(perform: moveRows)
                }
                .listStyle(.inset)
                .frame(minHeight: 300)
            }
#if os(iOS)
            .environment(\.editMode, .constant(.active))
#endif
            .overlay(alignment: .bottomLeading) {
                Text(info ?? "Drag the handle to reorder. Save; Deactivate/Restore to manage availability.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .navigationTitle("News Types")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    attemptDismiss()
                } label: {
                    Label("Back", systemImage: "chevron.backward")
                }
                .help("Return to Settings")
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
        .onAppear { load(focusAddField: true) }
        .alert("Hold It, Padawan!", isPresented: $showLeaveWarning) {
            Button("Stay and Finish Training", role: .cancel) { }
            Button("Leave Without Saving", role: .destructive) {
                discardChanges()
                dismiss()
            }
        } message: {
            Text("Unsaved changes I sense. Save them, you must, before departing the Jedi archives.")
        }
    }

    private func binding(for row: NewsTypeRow) -> (code: Binding<String>, displayName: Binding<String>, active: Binding<Bool>) {
        guard let idx = rows.firstIndex(where: { $0.id == row.id }) else {
            return (Binding.constant(row.code), Binding.constant(row.displayName), Binding.constant(row.active))
        }
        return (
            Binding<String>(
                get: { rows[idx].code },
                set: {
                    rows[idx] = NewsTypeRow(id: row.id, code: $0, displayName: rows[idx].displayName, sortOrder: rows[idx].sortOrder, active: rows[idx].active)
                    updateDirtyState(for: row.id)
                }
            ),
            Binding<String>(
                get: { rows[idx].displayName },
                set: {
                    rows[idx] = NewsTypeRow(id: row.id, code: rows[idx].code, displayName: $0, sortOrder: rows[idx].sortOrder, active: rows[idx].active)
                    updateDirtyState(for: row.id)
                }
            ),
            Binding<Bool>(
                get: { rows[idx].active },
                set: {
                    rows[idx] = NewsTypeRow(id: row.id, code: rows[idx].code, displayName: rows[idx].displayName, sortOrder: rows[idx].sortOrder, active: $0)
                    updateDirtyState(for: row.id)
                }
            )
        )
    }

    @ViewBuilder
    private func rowView(_ row: NewsTypeRow) -> some View {
        let binding = binding(for: row)
        let isRowDirty = dirtyRows.contains(row.id)
        let isDescriptionDirty = dirtyDescriptions.contains(row.id)
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.trailing, 2)
            Text("\(row.sortOrder)")
                .foregroundColor(.secondary)
                .frame(width: 28, alignment: .trailing)
            TextField("Code", text: binding.code)
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)
                .onSubmit { save(row) }
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRowDirty && !isDescriptionDirty ? Color.yellow.opacity(0.7) : Color.clear, lineWidth: 2)
                )
            TextField("Display name", text: binding.displayName)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 220)
                .onSubmit { save(row) }
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isDescriptionDirty ? Color.yellow : Color.clear, lineWidth: 2)
                )
            Toggle("", isOn: binding.active)
                .labelsHidden()
                .frame(width: 50)
                .onChange(of: binding.active.wrappedValue) { _, _ in save(row) }
            Spacer(minLength: 16)
            HStack(spacing: 8) {
                Button("Save") { save(row) }
                if row.active {
                    Button("Deactivate", role: .destructive) { delete(row) }
                } else {
                    Button("Restore") { restore(row) }
                }
            }
            if isDescriptionDirty {
                Text("Unsaved, this description is")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
        .background(isDescriptionDirty ? Color.yellow.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }

    private func load(focusAddField: Bool = false) {
        rows = dbManager.listNewsTypes()
        originalRows = rows
        dirtyRows.removeAll()
        dirtyDescriptions.removeAll()
        if newCode.isEmpty { newCode = nextCodeSuggestion() }
        if focusAddField { addFocus = .code }
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
            originalRows.append(created)
            originalRows.sort { $0.sortOrder < $1.sortOrder }
            newName = ""
            newCode = nextCodeSuggestion()
            error = nil
            addFocus = .code
        } else {
            error = "Failed to add type (check unique code)"
        }
    }

    private func save(_ row: NewsTypeRow) {
        // Pull the freshest values from `rows` so we persist what the user sees, not the stale snapshot passed into the table closure.
        let latest = rows.first(where: { $0.id == row.id }) ?? row
        let trimmedCode = latest.code.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = latest.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = NewsTypeRow(id: latest.id, code: trimmedCode, displayName: trimmedName, sortOrder: latest.sortOrder, active: latest.active)
        let ok = dbManager.updateNewsType(id: normalized.id, code: normalized.code, displayName: normalized.displayName, sortOrder: normalized.sortOrder, active: normalized.active)
        if ok {
            if let idx = rows.firstIndex(where: { $0.id == normalized.id }) {
                rows[idx] = normalized
            }
            if let baselineIdx = originalRows.firstIndex(where: { $0.id == normalized.id }) {
                originalRows[baselineIdx] = normalized
            } else {
                originalRows.append(normalized)
            }
            originalRows.sort { $0.sortOrder < $1.sortOrder }
            dirtyRows.remove(normalized.id)
            dirtyDescriptions.remove(normalized.id)
            info = "Saved \(normalized.code)"
            error = nil
        } else {
            error = "Failed to save row (unique code?)"
            info = nil
        }
    }

    private func moveRows(from source: IndexSet, to destination: Int) {
        rows.move(fromOffsets: source, toOffset: destination)
        for idx in rows.indices {
            let row = rows[idx]
            rows[idx] = NewsTypeRow(id: row.id, code: row.code, displayName: row.displayName, sortOrder: idx + 1, active: row.active)
        }
        persistCurrentOrder()
    }

    private func persistCurrentOrder() {
        let orderedIds = rows.map { $0.id }
        if dbManager.reorderNewsTypes(idsInOrder: orderedIds) {
            info = "Order saved"
            error = nil
            // Keep unsaved edits while refreshing sort order baselines.
            for idx in rows.indices {
                let row = rows[idx]
                rows[idx] = NewsTypeRow(id: row.id, code: row.code, displayName: row.displayName, sortOrder: idx + 1, active: row.active)
            }
            let baselineRows = originalRows
            originalRows = rows.enumerated().map { idx, current in
                if let baseline = baselineRows.first(where: { $0.id == current.id }) {
                    return NewsTypeRow(id: current.id, code: baseline.code, displayName: baseline.displayName, sortOrder: idx + 1, active: baseline.active)
                } else {
                    return NewsTypeRow(id: current.id, code: current.code, displayName: current.displayName, sortOrder: idx + 1, active: current.active)
                }
            }
            for id in Array(dirtyRows) { updateDirtyState(for: id) }
        } else {
            error = "Failed to save order"
            info = nil
        }
    }

    private func delete(_ row: NewsTypeRow) {
        // Soft-delete: mark inactive; row stays visible and can be re-activated via toggle
        if dbManager.deleteNewsType(id: row.id) {
            if let idx = rows.firstIndex(where: { $0.id == row.id }) {
                rows[idx] = NewsTypeRow(id: row.id, code: row.code, displayName: row.displayName, sortOrder: row.sortOrder, active: false)
            }
            if let baseIdx = originalRows.firstIndex(where: { $0.id == row.id }) {
                originalRows[baseIdx] = NewsTypeRow(id: row.id, code: originalRows[baseIdx].code, displayName: originalRows[baseIdx].displayName, sortOrder: originalRows[baseIdx].sortOrder, active: false)
            }
            dirtyRows.remove(row.id)
            dirtyDescriptions.remove(row.id)
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
            if let baseIdx = originalRows.firstIndex(where: { $0.id == row.id }) {
                originalRows[baseIdx] = NewsTypeRow(id: row.id, code: originalRows[baseIdx].code, displayName: originalRows[baseIdx].displayName, sortOrder: originalRows[baseIdx].sortOrder, active: true)
            }
            info = "Restored \(row.code)"; error = nil
        } else {
            error = "Failed to restore \(row.code)"; info = nil
        }
    }

    private func attemptDismiss() {
        if hasUnsavedChanges {
            showLeaveWarning = true
        } else {
            dismiss()
        }
    }

    private func discardChanges() {
        rows = originalRows
        dirtyRows.removeAll()
        dirtyDescriptions.removeAll()
        info = "Reverted, these edits are."
    }

    private func updateDirtyState(for id: Int) {
        guard let current = rows.first(where: { $0.id == id }) else {
            dirtyRows.remove(id)
            dirtyDescriptions.remove(id)
            return
        }
        guard let original = originalRows.first(where: { $0.id == id }) else {
            dirtyRows.insert(id)
            dirtyDescriptions.insert(id)
            return
        }
        if current.code != original.code || current.displayName != original.displayName {
            dirtyRows.insert(id)
        } else {
            dirtyRows.remove(id)
        }
        if current.displayName != original.displayName {
            dirtyDescriptions.insert(id)
        } else {
            dirtyDescriptions.remove(id)
        }
    }
}
