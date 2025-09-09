import SwiftUI
import AppKit

struct PortfolioThemeUpdatesView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    let initialSearchText: String?
    let searchHint: String?

    @State private var updates: [PortfolioThemeUpdate] = []
    @State private var extras: [Int: UpdateExtras] = [:]
    @State private var editingUpdate: PortfolioThemeUpdate?
    @State private var showEditor = false
    @State private var searchText: String = ""
    @State private var selectedTypeId: Int? = nil
    @State private var newsTypes: [NewsTypeRow] = []
    @State private var pinnedFirst: Bool = true
    @State private var sortOrder: SortOrder = .newest
    @State private var dateFilter: UpdateDateFilter = .last30d
    @State private var searchDebounce: DispatchWorkItem?
    @State private var expandedId: Int? = nil
    @State private var themeName: String = ""
    @State private var isArchived: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var deleteCandidateId: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            filterRow
            if let hint = searchHint {
                Text(hint)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if updates.isEmpty {
                VStack(spacing: 8) {
                    Text("No updates match your filters.")
                    Button("Clear filters") { resetFilters() }
                        .buttonStyle(.link)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(updates) { update in
                            updateCard(update)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(12)
        .onAppear {
            if let s = initialSearchText, searchText.isEmpty { searchText = s }
            newsTypes = NewsTypeRepository(dbManager: dbManager).listActive()
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
            })
            .environmentObject(dbManager)
        }
        .confirmationDialog("Delete this portfolio update? This will move it to the recycle bin.", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { deleteSelected() }
            Button("Cancel", role: .cancel) {
                deleteCandidateId = nil
                showDeleteConfirm = false
            }
        }
    }

    // MARK: - Subviews

    private var filterRow: some View {
        HStack {
            Button("+ New Update") { showEditor = true }
                .disabled(isArchived)
            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: searchText) { _, _ in
                    searchDebounce?.cancel()
                    let task = DispatchWorkItem { load() }
                    searchDebounce = task
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: task)
                }
            Picker("Type", selection: $selectedTypeId) {
                Text("All").tag(nil as Int?)
                ForEach(newsTypes, id: \.id) { nt in
                    Text(nt.displayName).tag(Optional(nt.id))
                }
            }
            .onChange(of: selectedTypeId) { _, _ in load() }
            Picker("Sort", selection: $sortOrder) {
                ForEach(SortOrder.allCases) { s in
                    Text(s.label).tag(s)
                }
            }
            .onChange(of: sortOrder) { _, _ in load() }
            Toggle("Pinned first", isOn: $pinnedFirst)
                .toggleStyle(.checkbox)
                .onChange(of: pinnedFirst) { _, _ in load() }
            Picker("Date", selection: $dateFilter) {
                ForEach(UpdateDateFilter.allCases) { f in
                    Text(f.label).tag(f)
                }
            }
            .onChange(of: dateFilter) { _, _ in load() }
        }
    }

    private func updateCard(_ update: PortfolioThemeUpdate) -> some View {
        let extra = extras[update.id]
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Button(action: { togglePin(update) }) {
                    Image(systemName: update.pinned ? "star.fill" : "star")
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top) {
                        Text(update.title)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .help(update.title)
                        Spacer()
                        HStack(spacing: 8) {
                            Button("Edit") { editingUpdate = update }
                                .buttonStyle(.link)
                                .disabled(isArchived)
                            Button("Delete", role: .destructive) {
                                deleteCandidateId = update.id
                                showDeleteConfirm = true
                            }
                                .buttonStyle(.link)
                                .disabled(isArchived)
                            Button(expandedId == update.id ? "Collapse" : "Expand") { toggleExpand(update) }
                                .buttonStyle(.link)
                        }
                    }
                    Text("\(DateFormatting.userFriendly(update.createdAt)) · \(update.author) · [\(update.typeDisplayName ?? update.typeCode)]")
                        .font(.caption)
                    if expandedId == update.id {
                        Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown))
                        if let links = extra?.links, !links.isEmpty {
                            Text("Links").font(.subheadline)
                            chipsGrid(links.map { chip(for: $0) })
                        }
                        if let files = extra?.attachments, !files.isEmpty {
                            Text("Files").font(.subheadline)
                            chipsGrid(files.map { chip(for: $0) })
                        }
                    } else {
                        Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown))
                            .lineLimit(3)
                        if let ex = extra, (!ex.links.isEmpty || !ex.attachments.isEmpty) {
                            chipsGrid(ex.links.map { chip(for: $0) } + ex.attachments.map { chip(for: $0) })
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
    }

    private func chipsGrid(_ chips: [ChipItem]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(chips) { chip in
                HStack {
                    Text(chip.label)
                        .lineLimit(1)
                        .help(chip.label)
                    Spacer()
                    Button("Open") { chip.open() }
                        .buttonStyle(.link)
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.1)))
            }
        }
    }

    // MARK: - Data

    private func load() {
        let query = searchText.isEmpty ? nil : searchText
        var list = dbManager.listThemeUpdates(themeId: themeId, view: .active, typeId: selectedTypeId, searchQuery: query, pinnedFirst: pinnedFirst)
        if dateFilter != .all {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let tz = TimeZone(identifier: dbManager.defaultTimeZone) ?? .current
            list = list.filter { upd in
                if let date = formatter.date(from: upd.createdAt) {
                    return dateFilter.contains(date, timeZone: tz)
                }
                return false
            }
        }
        if sortOrder == .oldest {
            list = list.sorted { $0.createdAt < $1.createdAt }
        }
        updates = list
        var map: [Int: UpdateExtras] = [:]
        let linkRepo = ThemeUpdateLinkRepository(dbManager: dbManager)
        let attRepo = ThemeUpdateRepository(dbManager: dbManager)
        for upd in list {
            let links = linkRepo.listLinks(updateId: upd.id)
            let atts = attRepo.listAttachments(updateId: upd.id)
            map[upd.id] = UpdateExtras(links: links, attachments: atts)
        }
        extras = map
        if let theme = dbManager.getPortfolioTheme(id: themeId) {
            themeName = theme.name
            isArchived = (theme.archivedAt != nil) || theme.softDelete
        }
    }

    private func resetFilters() {
        searchText = ""
        selectedTypeId = nil
        pinnedFirst = true
        sortOrder = .newest
        dateFilter = .last30d
        load()
    }

    // MARK: - Actions

    private func togglePin(_ update: PortfolioThemeUpdate) {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = dbManager.updateThemeUpdate(id: update.id, title: nil, bodyMarkdown: nil, newsTypeCode: nil, pinned: !update.pinned, actor: NSFullUserName(), expectedUpdatedAt: update.updatedAt)
            DispatchQueue.main.async { load() }
        }
    }

    private func deleteSelected() {
        guard let id = deleteCandidateId else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            _ = dbManager.softDeleteThemeUpdate(id: id, actor: NSFullUserName())
            DispatchQueue.main.async {
                showDeleteConfirm = false
                deleteCandidateId = nil
                load()
            }
        }
    }

    private func toggleExpand(_ update: PortfolioThemeUpdate) {
        if expandedId == update.id {
            expandedId = nil
        } else {
            expandedId = update.id
        }
    }

    private func openLink(_ link: Link) {
        if let url = URL(string: link.rawURL) {
            NSWorkspace.shared.open(url)
        }
    }

    private func openAttachment(_ att: Attachment) {
        AttachmentService(dbManager: dbManager).quickLook(attachmentId: att.id)
    }

    private func displayTitle(_ link: Link) -> String {
        if let t = link.title, !t.isEmpty { return t }
        if let url = URL(string: link.rawURL) { return url.host ?? link.rawURL }
        return link.rawURL
    }

    private func chip(for link: Link) -> ChipItem {
        ChipItem(id: "l-\(link.id)", label: displayTitle(link)) { openLink(link) }
    }

    private func chip(for att: Attachment) -> ChipItem {
        ChipItem(id: "f-\(att.id)", label: att.originalFilename) { openAttachment(att) }
    }

    // MARK: - Types

    struct UpdateExtras {
        let links: [Link]
        let attachments: [Attachment]
    }

    enum SortOrder: String, CaseIterable, Identifiable {
        case newest
        case oldest
        var id: String { rawValue }
        var label: String { self == .newest ? "Newest first" : "Oldest first" }
    }

    struct ChipItem: Identifiable {
        let id: String
        let label: String
        let open: () -> Void
    }
}
