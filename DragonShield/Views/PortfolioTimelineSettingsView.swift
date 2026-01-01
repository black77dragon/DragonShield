import SwiftUI

struct PortfolioTimelineSettingsView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var rows: [PortfolioTimelineRow] = []
    @State private var newDescription: String = ""
    @State private var newTimeIndication: String = ""
    @State private var error: String?
    @State private var info: String?
    @FocusState private var addFocus: AddField?

    private enum AddField { case description, timeIndication }

    private var canAdd: Bool {
        let desc = newDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let time = newTimeIndication.trimmingCharacters(in: .whitespacesAndNewlines)
        return !desc.isEmpty && !time.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Portfolio Timelines").font(.title3).bold(); Spacer() }
            HStack(spacing: 8) {
                TextField("Description", text: $newDescription)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 220)
                    .focused($addFocus, equals: .description)
                TextField("Time Indication (e.g., 0-12m)", text: $newTimeIndication)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 200)
                    .focused($addFocus, equals: .timeIndication)
                    .onSubmit { if canAdd { addTimeline() } }
                Button("Add Timeline") { addTimeline() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.67, green: 0.89, blue: 0.67))
                    .foregroundColor(.black)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canAdd)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let err = error { Text(err).foregroundColor(.red).font(.caption) }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Order").font(.caption).foregroundColor(.secondary).frame(width: 60, alignment: .leading)
                    Text("Description").font(.caption).foregroundColor(.secondary).frame(minWidth: 220, alignment: .leading)
                    Text("Time Indication").font(.caption).foregroundColor(.secondary).frame(minWidth: 160, alignment: .leading)
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
                .frame(minHeight: 320)
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
        .navigationTitle("Portfolio Timelines")
        .onAppear { load() }
        #if os(iOS)
            .environment(\.editMode, .constant(.active))
        #endif
    }

    private func binding(for row: PortfolioTimelineRow) -> (desc: Binding<String>, time: Binding<String>, active: Binding<Bool>) {
        guard let idx = rows.firstIndex(where: { $0.id == row.id }) else {
            return (Binding.constant(row.description), Binding.constant(row.timeIndication), Binding.constant(row.active))
        }
        return (
            Binding<String>(
                get: { rows[idx].description },
                set: { rows[idx] = PortfolioTimelineRow(id: row.id, description: $0, timeIndication: rows[idx].timeIndication, sortOrder: rows[idx].sortOrder, active: rows[idx].active) }
            ),
            Binding<String>(
                get: { rows[idx].timeIndication },
                set: { rows[idx] = PortfolioTimelineRow(id: row.id, description: rows[idx].description, timeIndication: $0, sortOrder: rows[idx].sortOrder, active: rows[idx].active) }
            ),
            Binding<Bool>(
                get: { rows[idx].active },
                set: { rows[idx] = PortfolioTimelineRow(id: row.id, description: rows[idx].description, timeIndication: rows[idx].timeIndication, sortOrder: rows[idx].sortOrder, active: $0) }
            )
        )
    }

    private func rowView(_ row: PortfolioTimelineRow) -> some View {
        let binding = binding(for: row)
        return HStack(alignment: .center, spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            Text("\(row.sortOrder)")
                .foregroundColor(.secondary)
                .frame(width: 28, alignment: .trailing)
            TextField("Description", text: binding.desc)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 220)
                .onSubmit { save(row) }
            TextField("0-12m", text: binding.time)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 160)
                .onSubmit { save(row) }
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
        }
    }

    private func load() {
        rows = dbManager.listPortfolioTimelines(includeInactive: true)
        if newDescription.isEmpty { addFocus = .description }
    }

    private func addTimeline() {
        let desc = newDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let time = newTimeIndication.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !desc.isEmpty, !time.isEmpty else { return }
        let order = (rows.map { $0.sortOrder }.max() ?? 0) + 1
        if let created = dbManager.createPortfolioTimeline(description: desc, timeIndication: time, sortOrder: order, active: true) {
            rows.append(created)
            rows.sort { $0.sortOrder < $1.sortOrder }
            newDescription = ""
            newTimeIndication = ""
            error = nil
            info = "Added \(desc)"
            addFocus = .description
        } else {
            error = "Failed to add timeline"
        }
    }

    private func save(_ row: PortfolioTimelineRow) {
        let ok = dbManager.updatePortfolioTimeline(id: row.id, description: row.description, timeIndication: row.timeIndication, sortOrder: row.sortOrder, active: row.active)
        if ok { info = "Saved \(row.description)"; error = nil } else { error = "Failed to save row"; info = nil }
        load()
    }

    private func delete(_ row: PortfolioTimelineRow) {
        if dbManager.deletePortfolioTimeline(id: row.id) {
            if let idx = rows.firstIndex(where: { $0.id == row.id }) {
                rows[idx] = PortfolioTimelineRow(id: row.id, description: row.description, timeIndication: row.timeIndication, sortOrder: row.sortOrder, active: false)
            }
            info = "Deactivated \(row.description)"
            error = nil
        } else {
            error = "No change (already inactive?)"
            info = nil
        }
    }

    private func restore(_ row: PortfolioTimelineRow) {
        let ok = dbManager.updatePortfolioTimeline(id: row.id, description: nil, timeIndication: nil, sortOrder: nil, active: true)
        if ok {
            if let idx = rows.firstIndex(where: { $0.id == row.id }) {
                rows[idx] = PortfolioTimelineRow(id: row.id, description: row.description, timeIndication: row.timeIndication, sortOrder: row.sortOrder, active: true)
            }
            info = "Restored \(row.description)"
            error = nil
        } else {
            error = "Failed to restore \(row.description)"
            info = nil
        }
    }

    private func moveRows(from offsets: IndexSet, to destination: Int) {
        rows.move(fromOffsets: offsets, toOffset: destination)
        let ids = rows.map(\.id)
        let ok = dbManager.reorderPortfolioTimelines(idsInOrder: ids)
        if ok {
            rows = dbManager.listPortfolioTimelines(includeInactive: true)
            info = "Order updated"
            error = nil
        } else {
            info = nil
            error = "Failed to reorder"
        }
    }
}
