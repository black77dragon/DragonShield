// DragonShield/Views/PortfolioThemeUpdatesView.swift
// MARK: - Version 2.0
// MARK: - History
// - 1.1 -> 2.0: Replace legacy list with card-based overview supporting expand/collapse.

import SwiftUI
import AppKit

struct PortfolioThemeUpdatesView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    let initialSearchText: String?
    let searchHint: String?

    @State private var updates: [PortfolioThemeUpdate] = []
    @State private var previewCache: [Int: String] = [:]
    @State private var attachments: [Int: [Attachment]] = [:]
    @State private var links: [Int: [Link]] = [:]
    @State private var expanded: Set<Int> = []
    @State private var showEditor = false
    @State private var editingUpdate: PortfolioThemeUpdate?
    @State private var themeName: String = ""
    @State private var isArchived = false
    @State private var pinnedFirst = true
    @State private var searchText: String = ""
    @State private var selectedType: PortfolioThemeUpdate.UpdateType?
    @State private var sortNewestFirst = true
    @State private var dateFilter: DateFilter = .last30
    @State private var searchDebounce: DispatchWorkItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isArchived {
                Text("Theme archived - composition locked; updates permitted")
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color.yellow.opacity(0.1))
            }
            filterBar
            if let hint = searchHint {
                Text(hint)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(updates) { update in
                        card(for: update)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .onAppear {
            if let s = initialSearchText, searchText.isEmpty { searchText = s }
            load()
        }
        .sheet(isPresented: $showEditor) {
            ThemeUpdateEditorView(themeId: themeId, themeName: themeName, onSave: { _ in
                showEditor = false
                load()
            }, onCancel: { showEditor = false })
            .environmentObject(dbManager)
        }
        .sheet(item: $editingUpdate) { upd in
            ThemeUpdateEditorView(themeId: themeId, themeName: themeName, existing: upd, onSave: { _ in
                editingUpdate = nil
                load()
            }, onCancel: { editingUpdate = nil })
            .environmentObject(dbManager)
        }
    }

    private var filterBar: some View {
        HStack {
            Button("+ New Update") { showEditor = true }
            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: searchText) { _, _ in
                    searchDebounce?.cancel()
                    let task = DispatchWorkItem { load() }
                    searchDebounce = task
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: task)
                }
            Picker("Type", selection: $selectedType) {
                Text("All").tag(nil as PortfolioThemeUpdate.UpdateType?)
                ForEach(PortfolioThemeUpdate.UpdateType.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(Optional(t))
                }
            }
            .onChange(of: selectedType) { _, _ in load() }
            Picker("Sort", selection: $sortNewestFirst) {
                Text("Newest first").tag(true)
                Text("Oldest first").tag(false)
            }
            .onChange(of: sortNewestFirst) { _, _ in load() }
            Toggle("Pinned first", isOn: $pinnedFirst)
                .toggleStyle(.checkbox)
                .onChange(of: pinnedFirst) { _, _ in load() }
            Picker("Date", selection: $dateFilter) {
                ForEach(DateFilter.allCases) { f in
                    Text(f.label).tag(f)
                }
            }
            .onChange(of: dateFilter) { _, _ in load() }
        }
    }

    private func card(for update: PortfolioThemeUpdate) -> some View {
        let isExpanded = expanded.contains(update.id)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Button(action: { togglePin(update) }) {
                    Image(systemName: update.pinned ? "star.fill" : "star")
                }
                .buttonStyle(.plain)
                .help(update.pinned ? "Unpin" : "Pin")
                VStack(alignment: .leading, spacing: 4) {
                    Text(update.title)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .help(update.title)
                    Text("\(DateFormatting.userFriendly(update.createdAt)) - \(update.author) - \(update.type.rawValue.uppercased())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack {
                    Button("Edit") { editingUpdate = update }
                    Button("Delete", role: .destructive) { delete(update) }
                    Button(isExpanded ? "Collapse ▲" : "Expand ▼") { toggleExpand(update.id) }
                }
                .font(.footnote)
            }
            if isExpanded {
                Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown))
                chipSection(update: update)
            } else {
                Text(previewCache[update.id] ?? "")
                    .lineLimit(3)
                chipSection(update: update)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2))
        )
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func chipSection(update: PortfolioThemeUpdate) -> some View {
        let linkItems = links[update.id] ?? []
        let fileItems = attachments[update.id] ?? []
        if !linkItems.isEmpty || !fileItems.isEmpty {
            WrapLayout(spacing: 8) {
                ForEach(linkItems, id: \.id) { link in
                    ChipView(text: displayTitle(link)) { openLink(link, updateId: update.id) }
                        .help(link.rawURL)
                }
                ForEach(fileItems, id: \.id) { att in
                    ChipView(text: att.originalFilename) { AttachmentService(dbManager: dbManager).quickLook(attachmentId: att.id) }
                        .help(att.originalFilename)
                }
            }
        }
    }

    private func toggleExpand(_ id: Int) {
        if expanded.contains(id) {
            expanded.remove(id)
        } else {
            expanded.insert(id)
        }
    }

    private func togglePin(_ update: PortfolioThemeUpdate) {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = dbManager.updateThemeUpdate(id: update.id, title: nil, bodyMarkdown: nil, type: nil, pinned: !update.pinned, actor: NSFullUserName(), expectedUpdatedAt: update.updatedAt)
            DispatchQueue.main.async { load() }
        }
    }

    private func delete(_ update: PortfolioThemeUpdate) {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = dbManager.softDeleteThemeUpdate(id: update.id, actor: NSFullUserName())
            DispatchQueue.main.async { load() }
        }
    }

    private func load() {
        let query = searchText.isEmpty ? nil : searchText
        var list = dbManager.listThemeUpdates(themeId: themeId, view: .active, type: selectedType, searchQuery: query, pinnedFirst: pinnedFirst)
        let now = Date()
        if let start = dateFilter.lowerBound(from: now) {
            let fmt = ISO8601DateFormatter()
            list = list.filter { fmt.date(from: $0.createdAt).map { $0 >= start && $0 < now } ?? false }
        }
        if !sortNewestFirst {
            list.reverse()
        }
        updates = list
        if let theme = dbManager.getPortfolioTheme(id: themeId) {
            themeName = theme.name
            isArchived = theme.archivedAt != nil
        }
        previewCache = Dictionary(uniqueKeysWithValues: list.map { ($0.id, MarkdownRenderer.plainText(from: $0.bodyMarkdown)) })
        let linkRepo = ThemeUpdateLinkRepository(dbManager: dbManager)
        let attRepo = ThemeUpdateRepository(dbManager: dbManager)
        var linkDict: [Int: [Link]] = [:]
        var attDict: [Int: [Attachment]] = [:]
        for u in list {
            linkDict[u.id] = linkRepo.listLinks(updateId: u.id)
            attDict[u.id] = attRepo.listAttachments(updateId: u.id)
        }
        links = linkDict
        attachments = attDict
        expanded = expanded.intersection(Set(list.map { $0.id }))
    }

    private func openLink(_ link: Link, updateId: Int) {
        if let url = URL(string: link.rawURL) {
            NSWorkspace.shared.open(url)
            LoggingService.shared.log("{ themeUpdateId: \(updateId), linkId: \(link.id), host: \(url.host ?? \"\"), op:'link_open' }", type: .info, logger: .database)
        }
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

    enum DateFilter: String, CaseIterable, Identifiable {
        case today, last7, last30, last90, last365, all
        var id: String { rawValue }
        var label: String {
            switch self {
            case .today: return "Today"
            case .last7: return "Last 7d"
            case .last30: return "Last 30d"
            case .last90: return "Last 90d"
            case .last365: return "Last 365d"
            case .all: return "All"
            }
        }
        func lowerBound(from now: Date) -> Date? {
            let cal = Calendar.current
            switch self {
            case .today: return cal.startOfDay(for: now)
            case .last7: return cal.date(byAdding: .day, value: -7, to: now)
            case .last30: return cal.date(byAdding: .day, value: -30, to: now)
            case .last90: return cal.date(byAdding: .day, value: -90, to: now)
            case .last365: return cal.date(byAdding: .day, value: -365, to: now)
            case .all: return nil
            }
        }
    }

    struct ChipView: View {
        let text: String
        let action: () -> Void
        var body: some View {
            HStack(spacing: 4) {
                Text(text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Button("Open", action: action)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
