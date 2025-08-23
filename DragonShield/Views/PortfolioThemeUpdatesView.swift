// DragonShield/Views/PortfolioThemeUpdatesView.swift
// MARK: - Version 1.1
// MARK: - History
// - 1.0 -> 1.1: Support Markdown rendering, pinning, and ordering toggle.

import SwiftUI
import AppKit

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
    @State private var linkPreviews: [Int: [Link]] = [:]
    @State private var expandedLinks: Set<Int> = []

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
                            if (attachmentCounts[update.id] ?? 0) > 0 { Image(systemName: "paperclip") }
                        }
                        Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown))
                            .lineLimit(3)
                        if let links = linkPreviews[update.id], !links.isEmpty {
                            let displayed = expandedLinks.contains(update.id) ? links : Array(links.prefix(3))
                            HStack {
                                Text("Links:")
                                ForEach(displayed, id: \.id) { link in
                                    Button(displayTitle(link)) { openLink(link, updateId: update.id) }
                                        .buttonStyle(.link)
                                }
                                if links.count > 3 {
                                    Button(expandedLinks.contains(update.id) ? "Show less" : "+\(links.count - 3) more") {
                                        if expandedLinks.contains(update.id) {
                                            expandedLinks.remove(update.id)
                                        } else {
                                            expandedLinks.insert(update.id)
                                        }
                                    }
                                }
                            }
                            if expandedLinks.contains(update.id) {
                                ForEach(links, id: \.id) { link in
                                    HStack {
                                        Text(link.rawURL)
                                            .font(.caption)
                                        Spacer()
                                        Button("Open") { openLink(link, updateId: update.id) }
                                        Button("Copy") { copyLink(link) }
                                    }
                                }
                            }
                        }
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
        if !updates.isEmpty {
            attachmentCounts = dbManager.getAttachmentCounts(for: updates.map { $0.id })
            let lrepo = ThemeUpdateLinkRepository(dbManager: dbManager)
            var dict: [Int: [Link]] = [:]
            for u in updates {
                dict[u.id] = lrepo.listLinks(updateId: u.id)
            }
            linkPreviews = dict
        } else {
            attachmentCounts = [:]
            linkPreviews = [:]
        }
    }

    private var selectedUpdate: PortfolioThemeUpdate? {
        updates.first { $0.id == selectedId }
    }

    private func formatted(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        return v.formatted(.currency(code: dbManager.baseCurrency).precision(.fractionLength(2)))
    }

    private func openLink(_ link: Link, updateId: Int) {
        if let url = URL(string: link.rawURL) {
            NSWorkspace.shared.open(url)
            LoggingService.shared.log("{ themeUpdateId: \(updateId), linkId: \(link.id), host: \(url.host ?? ""), op:'link_open' }", type: .info, logger: .database)
        }
    }

    private func copyLink(_ link: Link) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(link.rawURL, forType: .string)
    }

    private func displayTitle(_ link: Link) -> String {
        if let t = link.title, !t.isEmpty { return t }
        if let url = URL(string: link.rawURL) {
            var host = url.host ?? link.rawURL
            if !url.path.isEmpty && url.path != "/" {
                host += url.path
            }
            return host
        }
        return link.rawURL
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
