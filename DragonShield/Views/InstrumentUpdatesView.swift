// DragonShield/Views/InstrumentUpdatesView.swift
// MARK: - Version 1.0
// MARK: - History
// - 1.0: Initial instrument updates list for Step 7A.

import SwiftUI

struct InstrumentUpdatesView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    let instrumentId: Int
    let instrumentName: String
    let themeName: String
    var valuation: ValuationSnapshot? = nil
    var onClose: () -> Void

    @State private var updates: [PortfolioThemeAssetUpdate] = []
    @State private var showEditor = false
    @State private var editingUpdate: PortfolioThemeAssetUpdate?
    @State private var isArchived = false
    @State private var instrumentExists = true
    @State private var showDeleteConfirm = false
    @State private var selectedId: Int?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Instrument Updates — \(instrumentName)  •  Theme: \(themeName)")
                .font(.headline)
                .padding(16)
            if isArchived {
                Text("Theme archived — composition locked; updates permitted")
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color.yellow.opacity(0.1))
            }
            if !instrumentExists {
                Text("Instrument is no longer part of this theme. Existing updates are read-only.")
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color.yellow.opacity(0.1))
            }
            HStack {
                Button("+ New Update") { showEditor = true }
                    .disabled(!instrumentExists)
                Spacer()
            }
            .padding(.horizontal, 16)
            List(selection: $selectedId) {
                ForEach(updates) { update in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(DateFormatting.userFriendly(update.createdAt))  •  \(update.author)  •  \(update.type.rawValue)\(update.updatedAt > update.createdAt ? "  •  edited" : "")")
                            .font(.subheadline)
                        Text("Title: \(update.title)").fontWeight(.semibold)
                        Text(update.bodyText)
                        Text("Breadcrumb: Positions \(DateFormatting.userFriendly(update.positionsAsOf)) • Value CHF \(formatted(update.valueChf)) • Actual \(formattedPct(update.actualPercent))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(update.id)
                    .contextMenu {
                        Button("Edit") { editingUpdate = update }
                        Button("Delete", role: .destructive) { selectedId = update.id; showDeleteConfirm = true }
                    }
                }
            }
            Divider()
            HStack {
                Button("Edit") { if let u = selectedUpdate { editingUpdate = u } }
                    .disabled(selectedUpdate == nil)
                Button("Delete") { showDeleteConfirm = true }
                    .disabled(selectedUpdate == nil)
                Spacer()
                Button("Close") { onClose(); dismiss() }
            }
            .padding(16)
            .confirmationDialog("Delete this instrument update? This cannot be undone.", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) { deleteSelected() }
            }
        }
        .frame(minWidth: 640, minHeight: 400)
        .onAppear { load() }
        .sheet(isPresented: $showEditor) {
            InstrumentUpdateEditorView(themeId: themeId, instrumentId: instrumentId, instrumentName: instrumentName, themeName: themeName, valuation: valuation, onSave: { _ in
                showEditor = false
                load()
            }, onCancel: { showEditor = false })
            .environmentObject(dbManager)
        }
        .sheet(item: $editingUpdate) { upd in
            InstrumentUpdateEditorView(themeId: themeId, instrumentId: instrumentId, instrumentName: instrumentName, themeName: themeName, existing: upd, valuation: valuation, onSave: { _ in
                editingUpdate = nil
                load()
            }, onCancel: { editingUpdate = nil })
            .environmentObject(dbManager)
        }
        .onDisappear { onClose() }
    }

    private func load() {
        updates = dbManager.listInstrumentUpdates(themeId: themeId, instrumentId: instrumentId)
        isArchived = dbManager.getPortfolioTheme(id: themeId)?.archivedAt != nil
        instrumentExists = dbManager.listThemeAssets(themeId: themeId).contains { $0.instrumentId == instrumentId }
    }

    private var selectedUpdate: PortfolioThemeAssetUpdate? {
        updates.first { $0.id == selectedId }
    }

    private func deleteSelected() {
        guard let id = selectedUpdate?.id else { return }
        if dbManager.deleteInstrumentUpdate(id: id, actor: NSFullUserName()) {
            load()
        }
        showDeleteConfirm = false
    }

    private func formatted(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        return v.formatted(.currency(code: dbManager.baseCurrency).precision(.fractionLength(2)))
    }

    private func formattedPct(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        return v.formatted(.number.precision(.fractionLength(2))) + "%"
    }
}
