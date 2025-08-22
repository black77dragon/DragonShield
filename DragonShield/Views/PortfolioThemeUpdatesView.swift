// DragonShield/Views/PortfolioThemeUpdatesView.swift
// MARK: - Version 1.0
// MARK: - History
// - Initial creation: Lists and manages theme updates with fast-path creation.

import SwiftUI

struct PortfolioThemeUpdatesView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int

    @State private var updates: [PortfolioThemeUpdate] = []
    @State private var showEditor = false
    @State private var editingUpdate: PortfolioThemeUpdate?
    @State private var themeName: String = ""
    @State private var isArchived: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            if isArchived {
                Text("Theme archived — composition locked; updates permitted")
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color.yellow.opacity(0.1))
            }
            HStack {
                Button("+ New Update") { showEditor = true }
                Spacer()
            }
            List {
                ForEach(updates) { update in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(update.createdAt) • \(update.author) • \(update.type.rawValue)")
                            .font(.subheadline)
                        Text("Title: \(update.title)").fontWeight(.semibold)
                        Text(update.bodyText)
                        Text("Breadcrumb: Positions \(update.positionsAsOf ?? "—") • Total CHF \(formatted(update.totalValueChf))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .contextMenu {
                        Button("Edit") { editingUpdate = update }
                        Button("Delete", role: .destructive) {
                            _ = dbManager.deleteThemeUpdate(id: update.id)
                            load()
                        }
                    }
                }
            }
        }
        .onAppear { load() }
        .sheet(isPresented: $showEditor) {
            ThemeUpdateEditorView(themeId: themeId, themeName: themeName, onSave: { _ in
                showEditor = false
                load()
            }, onCancel: {
                showEditor = false
            })
            .environmentObject(dbManager)
        }
        .sheet(item: $editingUpdate) { upd in
            ThemeUpdateEditorView(themeId: themeId, themeName: themeName, existing: upd, onSave: { _ in
                editingUpdate = nil
                load()
            }, onCancel: {
                editingUpdate = nil
            })
            .environmentObject(dbManager)
        }
    }

    private func load() {
        updates = dbManager.listThemeUpdates(themeId: themeId)
        let themes = dbManager.fetchPortfolioThemes(includeArchived: true, includeSoftDeleted: false, search: nil)
        if let theme = themes.first(where: { $0.id == themeId }) {
            themeName = theme.name
            isArchived = theme.archivedAt != nil
        }
    }

    private func formatted(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        return v.formatted(.currency(code: dbManager.baseCurrency).precision(.fractionLength(2)))
    }
}
