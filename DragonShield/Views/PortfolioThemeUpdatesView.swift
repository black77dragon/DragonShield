// DragonShield/Views/PortfolioThemeUpdatesView.swift
// MARK: - Version 1.2
// MARK: - History
// - 1.1 -> 1.2: Friendly timestamps, selection with footer action bar, and keyboard shortcuts.
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
    @State private var selectedId: Int?
    @State private var showDeleteConfirm = false

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
            List(selection: $selectedId) {
                ForEach(updates) { update in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(DateFormatting.friendly(update.createdAt)) • \(update.author) • \(update.type.rawValue)\(update.updatedAt > update.createdAt ? \" • edited\" : \"\")")
                            .font(.subheadline)
                        HStack {
                            Text("Title: \(update.title)").fontWeight(.semibold)
                            if update.pinned { Image(systemName: "star.fill") }
                        }
                        Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown))
                            .lineLimit(3)
                        Text("Breadcrumb: Positions \(DateFormatting.friendly(update.positionsAsOf)) • Total CHF \(formatted(update.totalValueChf))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(update.id)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedId = update.id }
                    .onTapGesture(count: 2) { editingUpdate = update }
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
            .onDeleteCommand { deleteSelected() }
            .onKeyPress(.return) { _ in
                if let sel = selectedUpdate() { editingUpdate = sel }
                return .ignored
            }
            Divider()
            HStack {
                Button("Edit") { if let sel = selectedUpdate() { editingUpdate = sel } }
                    .disabled(selectedId == nil)
                Button("Delete") { showDeleteConfirm = true }
                    .disabled(selectedId == nil)
                Button(selectedUpdate()?.pinned == true ? "Unpin" : "Pin") {
                    if let sel = selectedUpdate() {
                        _ = dbManager.updateThemeUpdate(id: sel.id, title: nil, bodyMarkdown: nil, type: nil, pinned: !sel.pinned, actor: NSFullUserName(), expectedUpdatedAt: sel.updatedAt, source: "footer")
                        load()
                    }
                }
                .disabled(selectedId == nil)
                Spacer()
            }
            .padding(.top, 4)
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
            }, source: selectedId != nil ? "footer" : nil)
            .environmentObject(dbManager)
        }
        .alert("Delete this update? This action can't be undone.", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { deleteSelected() }
        }
    }

    private func load() {
        updates = dbManager.listThemeUpdates(themeId: themeId, pinnedFirst: pinnedFirst)
        if let theme = dbManager.getPortfolioTheme(id: themeId) {
            themeName = theme.name
            isArchived = theme.archivedAt != nil
        }
        if !updates.contains(where: { $0.id == selectedId }) {
            selectedId = nil
        }
    }

    private func selectedUpdate() -> PortfolioThemeUpdate? {
        updates.first(where: { $0.id == selectedId })
    }

    private func deleteSelected() {
        guard let sel = selectedUpdate() else { return }
        _ = dbManager.deleteThemeUpdate(id: sel.id, themeId: themeId, actor: NSFullUserName(), source: "footer")
        load()
    }

    private func formatted(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        return v.formatted(.currency(code: dbManager.baseCurrency).precision(.fractionLength(2)))
    }
}
