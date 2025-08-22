// DragonShield/Views/PortfolioThemeUpdatesView.swift
// MARK: - Version 1.1
// MARK: - History
// - 1.0 -> 1.1: Support Markdown rendering, pinning, and ordering toggle.

import SwiftUI

struct PortfolioThemeUpdatesView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int

    @State private var updates: [PortfolioThemeUpdate] = []
    @State private var showEditor = false
    @State private var editingUpdate: PortfolioThemeUpdate?
    @State private var themeName: String = ""
    @State private var isArchived: Bool = false
    @State private var pinnedFirst: Bool = true

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
                Toggle("Pinned first", isOn: $pinnedFirst)
                    .toggleStyle(.checkbox)
                    .onChange(of: pinnedFirst) { _ in load() }
            }
            List {
                ForEach(updates) { update in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(update.createdAt) • \(update.author) • \(update.type.rawValue)\(update.updatedAt > update.createdAt ? " • edited" : "")")
                            .font(.subheadline)
                        HStack {
                            Text("Title: \(update.title)").fontWeight(.semibold)
                            if update.pinned { Image(systemName: "star.fill") }
                        }
                        Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown))
                            .lineLimit(3)
                        Text("Breadcrumb: Positions \(update.positionsAsOf ?? "—") • Total CHF \(formatted(update.totalValueChf))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .contextMenu {
                        Button("Edit") { editingUpdate = update }
                        if update.pinned {
                            Button("Unpin") {
                                _ = dbManager.updateThemeUpdate(id: update.id, title: nil, bodyMarkdown: nil, type: nil, pinned: false, actor: NSFullUserName(), expectedUpdatedAt: update.updatedAt)
                                load()
                            }
                        } else {
                            Button("Pin") {
                                _ = dbManager.updateThemeUpdate(id: update.id, title: nil, bodyMarkdown: nil, type: nil, pinned: true, actor: NSFullUserName(), expectedUpdatedAt: update.updatedAt)
                                load()
                            }
                        }
                        Button("Delete", role: .destructive) {
                            _ = dbManager.deleteThemeUpdate(id: update.id, themeId: themeId, actor: NSFullUserName())
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
        updates = dbManager.listThemeUpdates(themeId: themeId, pinnedFirst: pinnedFirst)
        if let theme = dbManager.getPortfolioTheme(id: themeId) {
            themeName = theme.name
            isArchived = theme.archivedAt != nil
        }
    }

    private func formatted(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        return v.formatted(.currency(code: dbManager.baseCurrency).precision(.fractionLength(2)))
    }
}
