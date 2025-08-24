import SwiftUI
import AppKit

struct PortfolioThemeUpdatesView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    let initialSearchText: String?
    let searchHint: String?

    @State private var updates: [PortfolioThemeUpdate] = []
    @State private var expanded: Set<Int> = []
    @State private var previews: [Int: String] = [:]
    @State private var attachments: [Int: [Attachment]] = [:]
    @State private var links: [Int: [Link]] = [:]
    @State private var showEditor = false
    @State private var editingUpdate: PortfolioThemeUpdate?
    @State private var themeName: String = ""
    @State private var isArchived: Bool = false
    @State private var pinnedFirst: Bool = true
    @State private var searchText: String = ""
    @State private var selectedType: PortfolioThemeUpdate.UpdateType? = nil
    @State private var searchDebounce: DispatchWorkItem?
    @State private var deleteTarget: PortfolioThemeUpdate?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isArchived {
                Text("Theme archived — composition locked; updates permitted")
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color.yellow.opacity(0.1))
            }
            controlBar
            if let hint = searchHint {
                Text(hint)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            if updates.isEmpty {
                Text("No updates match your filters.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(updates) { update in
                            UpdateCard(
                                update: update,
                                preview: previews[update.id] ?? "",
                                links: links[update.id] ?? [],
                                attachments: attachments[update.id] ?? [],
                                expanded: expanded.contains(update.id),
                                onToggleExpand: { toggleExpand(update.id) },
                                onEdit: { editingUpdate = update },
                                onDelete: { deleteTarget = update },
                                onPin: { togglePin(update) },
                                openLink: { openLink($0, updateId: update.id) },
                                openAttachment: { openAttachment($0) }
                            )
                        }
                    }
                    .padding(8)
                }
            }
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
        .alert(item: $deleteTarget) { upd in
            Alert(
                title: Text("Delete this update? This action can't be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    performDelete(upd)
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var controlBar: some View {
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
        if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
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

    private func performDelete(_ update: PortfolioThemeUpdate) {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = dbManager.softDeleteThemeUpdate(id: update.id, actor: NSFullUserName())
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
        var prev: [Int: String] = [:]
        var attDict: [Int: [Attachment]] = [:]
        var linkDict: [Int: [Link]] = [:]
        let repo = ThemeUpdateRepository(dbManager: dbManager)
        let lrepo = ThemeUpdateLinkRepository(dbManager: dbManager)
        for u in updates {
            prev[u.id] = MarkdownRenderer.plainText(from: u.bodyMarkdown)
            attDict[u.id] = repo.listAttachments(updateId: u.id)
            linkDict[u.id] = lrepo.listLinks(updateId: u.id)
        }
        previews = prev
        attachments = attDict
        links = linkDict
    }

    private func openLink(_ link: Link, updateId: Int) {
        if let url = URL(string: link.rawURL) {
            NSWorkspace.shared.open(url)
            LoggingService.shared.log(
                "{ themeUpdateId: \\(updateId), linkId: \\(link.id), host: \\(url.host ?? \"\"), op:'link_open' }",
                type: .info,
                logger: .database
            )
        }
    }

    private func openAttachment(_ attachment: Attachment) {
        AttachmentService(dbManager: dbManager).quickLook(attachmentId: attachment.id)
    }

    struct UpdateCard: View {
        let update: PortfolioThemeUpdate
        let preview: String
        let links: [Link]
        let attachments: [Attachment]
        let expanded: Bool
        let onToggleExpand: () -> Void
        let onEdit: () -> Void
        let onDelete: () -> Void
        let onPin: () -> Void
        let openLink: (Link) -> Void
        let openAttachment: (Attachment) -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Button(action: onPin) {
                        Image(systemName: update.pinned ? "star.fill" : "star")
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Text(update.title)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .help(update.title)
                            Spacer()
                            Button("View") { onToggleExpand() }
                            Button("Edit") { onEdit() }
                            Button("Delete", role: .destructive) { onDelete() }
                        }
                        Text("\(DateFormatting.userFriendly(update.createdAt)) · \(update.author) · \(update.type.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                if expanded {
                    Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown))
                    if !links.isEmpty {
                        Text("Links").font(.subheadline)
                        chipGridLinks
                    }
                    if !attachments.isEmpty {
                        Text("Files").font(.subheadline)
                        chipGridAttachments
                    }
                } else {
                    Text(preview)
                        .lineLimit(3)
                    if !links.isEmpty || !attachments.isEmpty {
                        chipGridCollapsed
                    }
                }
                HStack {
                    Spacer()
                    Button(expanded ? "Collapse" : "Expand") { onToggleExpand() }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3))
            )
        }

        private var chipColumns: [GridItem] {
            [GridItem(.adaptive(minimum: 160), spacing: 8)]
        }

        private var chipGridCollapsed: some View {
            LazyVGrid(columns: chipColumns, alignment: .leading, spacing: 8) {
                ForEach(links, id: \.id) { link in
                    chip(label: displayTitle(link)) { openLink(link) }
                }
                ForEach(attachments, id: \.id) { att in
                    chip(label: att.originalFilename) { openAttachment(att) }
                }
            }
        }

        private var chipGridLinks: some View {
            LazyVGrid(columns: chipColumns, alignment: .leading, spacing: 8) {
                ForEach(links, id: \.id) { link in
                    chip(label: displayTitle(link)) { openLink(link) }
                }
            }
        }

        private var chipGridAttachments: some View {
            LazyVGrid(columns: chipColumns, alignment: .leading, spacing: 8) {
                ForEach(attachments, id: \.id) { att in
                    chip(label: att.originalFilename) { openAttachment(att) }
                }
            }
        }

        private func chip(label: String, action: @escaping () -> Void) -> some View {
            HStack(spacing: 4) {
                Text(label)
                    .lineLimit(1)
                Spacer()
                Button("Open", action: action)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor.opacity(0.6))
            )
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
    }
}
