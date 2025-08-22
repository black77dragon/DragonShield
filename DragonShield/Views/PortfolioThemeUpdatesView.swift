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
    @State private var selectedId: Int?
    @State private var showDeleteConfirm = false
    @State private var editingFromFooter = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                        Text("\(DateFormatting.userFriendly(update.createdAt))  •  \(update.author)  •  \(update.type.rawValue)\(update.updatedAt > update.createdAt ? "  •  edited" : "")")
                            .font(.subheadline)
                        HStack {
                            Text("Title: \(update.title)").fontWeight(.semibold)
                            if update.pinned { Image(systemName: "star.fill") }
                        }
                        Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown))
                            .lineLimit(3)
                        Text("Breadcrumb: Positions \(DateFormatting.userFriendly(update.positionsAsOf)) • Total CHF \(formatted(update.totalValueChf))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(update.id)
                    .onTapGesture(count: 2) { editingUpdate = update; editingFromFooter = false }
                    .contextMenu {
                        Button("Edit") { editingUpdate = update; editingFromFooter = false }
                        Button(update.pinned ? "Unpin" : "Pin") { togglePin(update) }
                        Button("Delete", role: .destructive) { delete(update) }
                    }
                }
            }
            Divider()
            HStack {
                Button("Edit") { if let u = selectedUpdate { editingUpdate = u; editingFromFooter = true } }
                    .disabled(selectedUpdate == nil)
                Button("Delete") { showDeleteConfirm = true }
                    .disabled(selectedUpdate == nil)
                Button(selectedUpdate?.pinned == true ? "Unpin" : "Pin") {
                    if let u = selectedUpdate { togglePin(u, source: "footer") }
                }
                    .disabled(selectedUpdate == nil)
            }
            .padding(8)
            .confirmationDialog("Delete this update? This action can't be undone.", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) { deleteSelected() }
            }
            Button(action: { if let u = selectedUpdate { editingUpdate = u; editingFromFooter = true } }) { EmptyView() }
                .keyboardShortcut(.return, modifiers: [])
                .hidden()
            Button(action: { if selectedUpdate != nil { showDeleteConfirm = true } }) { EmptyView() }
                .keyboardShortcut(.delete, modifiers: [])
                .hidden()
        }
        .onAppear { load() }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
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
            }, logSource: editingFromFooter ? "footer" : nil)
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

    private var selectedUpdate: PortfolioThemeUpdate? {
        updates.first { $0.id == selectedId }
    }

    private func formatted(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        return v.formatted(.currency(code: dbManager.baseCurrency).precision(.fractionLength(2)))
    }

    private func deleteSelected() {
        if let u = selectedUpdate { delete(u, source: "footer") }
    }

    private func togglePin(_ update: PortfolioThemeUpdate, source: String? = nil) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let result = dbManager.updateThemeUpdate(id: update.id, title: nil, bodyMarkdown: nil, type: nil, pinned: !update.pinned, actor: NSFullUserName(), expectedUpdatedAt: update.updatedAt, source: source) {
                DispatchQueue.main.async {
                    load()
                    selectedId = result.id
                }
            } else {
                DispatchQueue.main.async { errorMessage = "Update failed. Please reload." }
            }
        }
    }

    private func delete(_ update: PortfolioThemeUpdate, source: String? = nil) {
        DispatchQueue.global(qos: .userInitiated).async {
            if dbManager.deleteThemeUpdate(id: update.id, themeId: themeId, actor: NSFullUserName(), source: source) {
                DispatchQueue.main.async {
                    load()
                    if selectedId == update.id { selectedId = nil }
                }
            } else {
                DispatchQueue.main.async { errorMessage = "Delete failed. Please reload." }
            }
        }
    }
}
