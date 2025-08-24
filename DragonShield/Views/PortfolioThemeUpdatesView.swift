import SwiftUI
import AppKit

struct PortfolioThemeUpdatesView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    let initialSearchText: String?
    let searchHint: String?

    @State private var updates: [PortfolioThemeUpdate] = []
    @State private var themeName: String = ""
    @State private var isArchived: Bool = false
    @State private var pinnedFirst: Bool = true
    @State private var searchText: String = ""
    @State private var selectedType: PortfolioThemeUpdate.UpdateType? = nil
    @State private var searchDebounce: DispatchWorkItem?
    @State private var attachments: [Int: [Attachment]] = [:]
    @State private var links: [Int: [Link]] = [:]
    @State private var expanded: Set<Int> = []
    @State private var editingUpdate: PortfolioThemeUpdate?
    @State private var showEditor = false
    @State private var confirmDeleteId: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isArchived {
                Text("Theme archived — composition locked; updates permitted")
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color.yellow.opacity(0.1))
            }
            controls
            if let hint = searchHint {
                Text(hint)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(updates) { update in
                        UpdateCard(
                            update: update,
                            attachments: attachments[update.id] ?? [],
                            links: links[update.id] ?? [],
                            isExpanded: expanded.contains(update.id),
                            onToggleExpand: { toggleExpand(update.id) },
                            onEdit: { editingUpdate = update },
                            onDelete: { confirmDeleteId = update.id },
                            onPinToggle: { togglePin(update) },
                            onOpenLink: { openLink($0, updateId: update.id) },
                            onOpenAttachment: { openAttachment($0, updateId: update.id) }
                        )
                    }
                }
                .padding(8)
            }
        }
        .onAppear {
            if let s = initialSearchText, searchText.isEmpty { searchText = s }
            load()
        }
        .sheet(item: $editingUpdate) { upd in
            ThemeUpdateEditorView(
                themeId: themeId,
                themeName: themeName,
                existing: upd,
                onSave: { _ in
                    editingUpdate = nil
                    load()
                },
                onCancel: { editingUpdate = nil }
            )
            .environmentObject(dbManager)
        }
        .sheet(isPresented: $showEditor) {
            ThemeUpdateEditorView(
                themeId: themeId,
                themeName: themeName,
                onSave: { _ in
                    showEditor = false
                    load()
                },
                onCancel: { showEditor = false }
            )
            .environmentObject(dbManager)
        }
        .confirmationDialog("Delete this update? This action can't be undone.", item: $confirmDeleteId) { id in
            Button("Delete", role: .destructive) { delete(id) }
        }
    }

    private var controls: some View {
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
            Spacer()
            Toggle("Pinned first", isOn: $pinnedFirst)
                .toggleStyle(.checkbox)
                .onChange(of: pinnedFirst) { _, _ in load() }
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
            _ = dbManager.updateThemeUpdate(
                id: update.id,
                title: nil,
                bodyMarkdown: nil,
                type: nil,
                pinned: !update.pinned,
                actor: NSFullUserName(),
                expectedUpdatedAt: update.updatedAt
            )
            DispatchQueue.main.async { load() }
        }
    }

    private func delete(_ id: Int) {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = dbManager.softDeleteThemeUpdate(id: id, actor: NSFullUserName())
            DispatchQueue.main.async { load() }
        }
    }

    private func load() {
        let query = searchText.isEmpty ? nil : searchText
        updates = dbManager.listThemeUpdates(themeId: themeId, view: .active, type: selectedType, searchQuery: query, pinnedFirst: pinnedFirst)
        if let theme = dbManager.getPortfolioTheme(id: themeId) {
            themeName = theme.name
            isArchived = theme.archivedAt != nil
        }
        if FeatureFlags.portfolioAttachmentsEnabled(), !updates.isEmpty {
            let repo = ThemeUpdateRepository(dbManager: dbManager)
            var dict: [Int: [Attachment]] = [:]
            for u in updates { dict[u.id] = repo.listAttachments(updateId: u.id) }
            attachments = dict
        } else {
            attachments = [:]
        }
        if !updates.isEmpty {
            let lrepo = ThemeUpdateLinkRepository(dbManager: dbManager)
            var dict: [Int: [Link]] = [:]
            for u in updates { dict[u.id] = lrepo.listLinks(updateId: u.id) }
            links = dict
        } else {
            links = [:]
        }
    }

    private func openLink(_ link: Link, updateId: Int) {
        if let url = URL(string: link.rawURL) {
            NSWorkspace.shared.open(url)
            LoggingService.shared.log("{ themeUpdateId: \(updateId), linkId: \(link.id), host: \(url.host ?? \"\"), op:'link_open' }", type: .info, logger: .database)
        }
    }

    private func openAttachment(_ att: Attachment, updateId: Int) {
        AttachmentService(dbManager: dbManager).quickLook(attachmentId: att.id)
        LoggingService.shared.log("{ themeUpdateId: \(updateId), attachmentId: \(att.id), op:'attachment_open' }", type: .info, logger: .database)
    }

    private func formatted(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        return v.formatted(.currency(code: dbManager.baseCurrency).precision(.fractionLength(2)))
    }

    struct UpdateCard: View {
        let update: PortfolioThemeUpdate
        let attachments: [Attachment]
        let links: [Link]
        let isExpanded: Bool
        let onToggleExpand: () -> Void
        let onEdit: () -> Void
        let onDelete: () -> Void
        let onPinToggle: () -> Void
        let onOpenLink: (Link) -> Void
        let onOpenAttachment: (Attachment) -> Void

        private let grid = [GridItem(.adaptive(minimum: 160), spacing: 8)]

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Button(action: onPinToggle) {
                        Image(systemName: update.pinned ? "star.fill" : "star")
                    }
                    .buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(update.title)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .help(update.title)
                            Spacer()
                            Button("View") { onToggleExpand() }
                            Button("Edit") { onEdit() }
                            Button("Delete") { onDelete() }
                            Button(isExpanded ? "Collapse" : "Expand") { onToggleExpand() }
                        }
                        Text("\(DateFormatting.userFriendly(update.createdAt)) · \(update.author) · \(update.type.rawValue)\(update.updatedAt > update.createdAt ? " · edited" : "")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                if isExpanded {
                    Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown))
                } else {
                    Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown))
                        .lineLimit(3)
                }
                if !links.isEmpty {
                    LazyVGrid(columns: grid, alignment: .leading) {
                        ForEach(links, id: \.id) { link in
                            Button(action: { onOpenLink(link) }) {
                                Label(linkLabel(link), systemImage: "link")
                                    .lineLimit(1)
                                    .help(link.rawURL)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                if !attachments.isEmpty {
                    LazyVGrid(columns: grid, alignment: .leading) {
                        ForEach(attachments, id: \.id) { att in
                            Button(action: { onOpenAttachment(att) }) {
                                Label(att.originalFilename, systemImage: "doc")
                                    .lineLimit(1)
                                    .help(att.originalFilename)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
        }

        private func linkLabel(_ link: Link) -> String {
            if let t = link.title, !t.isEmpty { return t }
            if let url = URL(string: link.rawURL) { return url.host ?? link.rawURL }
            return link.rawURL
        }
    }
}

