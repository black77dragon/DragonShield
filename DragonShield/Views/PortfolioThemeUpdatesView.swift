// DragonShield/Views/PortfolioThemeUpdatesView.swift
// MARK: - Version 1.1
// MARK: - History
// - 1.0 -> 1.1: Support Markdown rendering, pinning, and ordering toggle.

import SwiftUI

struct PortfolioThemeUpdatesView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    let initialSearchText: String?
    let searchHint: String?

    @State private var updates: [PortfolioThemeUpdate] = []
    @State private var showEditor = false
    @State private var editingUpdate: PortfolioThemeUpdate?
    @State private var themeName: String = ""
    @State private var isArchived: Bool = false
    @State private var pinnedFirst: Bool = true
    @State private var selectedId: Int?
    @State private var showDeleteConfirm = false
    @State private var editingFromFooter = false
    @State private var searchText: String = ""
    @State private var selectedType: PortfolioThemeUpdate.UpdateType? = nil
    @State private var searchDebounce: DispatchWorkItem?
    @State private var attachmentCounts: [Int: Int] = [:]

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
                TextField("Search", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: searchText) { _, _ in
                        searchDebounce?.cancel()
                        let task = DispatchWorkItem { load() }
                        searchDebounce = task
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: task)
                    }
                Picker("Type", selection: $selectedType) {
                    Text("All").tag(nil as PortfolioThemeUpdate.UpdateType?)
                    ForEach(PortfolioThemeUpdate.UpdateType.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(Optional(t))
                    }
                }
                    .onChange(of: selectedType) { _, _ in load() }
                Spacer()
                Toggle("Pinned first", isOn: $pinnedFirst)
                    .toggleStyle(.checkbox)
                    .onChange(of: pinnedFirst) { _, _ in load() }
            }
            if let hint = searchHint {
                Text(hint)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            List(selection: $selectedId) {
                ForEach(updates) { update in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(DateFormatting.userFriendly(update.createdAt))  •  \(update.author)  •  \(update.type.rawValue)\(update.updatedAt > update.createdAt ? "  •  edited" : "")")
                            .font(.subheadline)
                        HStack {
                            Text("Title: \(update.title)").fontWeight(.semibold)
                            if update.pinned { Image(systemName: "star.fill") }
                            if FeatureFlags.portfolioAttachmentsEnabled(), (attachmentCounts[update.id] ?? 0) > 0 {
                                Image(systemName: "paperclip")
                            }
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
                        if update.pinned {
                            Button("Unpin") {
                                DispatchQueue.global(qos: .userInitiated).async {
                                    _ = dbManager.updateThemeUpdate(id: update.id, title: nil, bodyMarkdown: nil, type: nil, pinned: false, actor: NSFullUserName(), expectedUpdatedAt: update.updatedAt)
                                    DispatchQueue.main.async { load() }
                                }
                            }
                        } else {
                            Button("Pin") {
                                DispatchQueue.global(qos: .userInitiated).async {
                                    _ = dbManager.updateThemeUpdate(id: update.id, title: nil, bodyMarkdown: nil, type: nil, pinned: true, actor: NSFullUserName(), expectedUpdatedAt: update.updatedAt)
                                    DispatchQueue.main.async { load() }
                                }
                            }
                        }
                        Button("Delete", role: .destructive) {
                            DispatchQueue.global(qos: .userInitiated).async {
                                _ = dbManager.softDeleteThemeUpdate(id: update.id, actor: NSFullUserName())
                                DispatchQueue.main.async { load() }
                            }
                        }
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
                    if let u = selectedUpdate {
                        DispatchQueue.global(qos: .userInitiated).async {
                            _ = dbManager.updateThemeUpdate(id: u.id, title: nil, bodyMarkdown: nil, type: nil, pinned: !u.pinned, actor: NSFullUserName(), expectedUpdatedAt: u.updatedAt, source: "footer")
                            DispatchQueue.main.async {
                                load()
                                selectedId = u.id
                            }
                        }
                    }
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
        .onAppear {
            if let s = initialSearchText, searchText.isEmpty {
                searchText = s
            }
            load()
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
        let query = searchText.isEmpty ? nil : searchText
        updates = dbManager.listThemeUpdates(themeId: themeId, view: .active, type: selectedType, searchQuery: query, pinnedFirst: pinnedFirst)
        if let theme = dbManager.getPortfolioTheme(id: themeId) {
            themeName = theme.name
            isArchived = theme.archivedAt != nil
        }
        if FeatureFlags.portfolioAttachmentsEnabled() {
            let repo = ThemeUpdateRepository(dbManager: dbManager)
            attachmentCounts = Dictionary(uniqueKeysWithValues: updates.map { ($0.id, repo.listAttachments(updateId: $0.id).count) })
        } else {
            attachmentCounts = [:]
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
        if let u = selectedUpdate {
            DispatchQueue.global(qos: .userInitiated).async {
                if dbManager.softDeleteThemeUpdate(id: u.id, actor: NSFullUserName(), source: "footer") {
                    DispatchQueue.main.async {
                        load()
                        selectedId = nil
                    }
                }
            }
        }
    }
}
