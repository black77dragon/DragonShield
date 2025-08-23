// DragonShield/Views/ThemeUpdateEditorView.swift
// MARK: - Version 1.1
// MARK: - History
// - 1.0 -> 1.1: Add Markdown editing with preview and pin toggle.

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ThemeUpdateEditorView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    let themeName: String
    var existing: PortfolioThemeUpdate?
    var onSave: (PortfolioThemeUpdate) -> Void
    var onCancel: () -> Void
    var logSource: String?

    enum Mode { case write, preview }

    @State private var title: String
    @State private var bodyMarkdown: String
    @State private var type: PortfolioThemeUpdate.UpdateType
    @State private var pinned: Bool
    @State private var mode: Mode = .write
    @State private var positionsAsOf: String?
    @State private var totalValueChf: Double?
    @State private var attachments: [Attachment] = []
    @State private var removedAttachmentIds: Set<Int> = []
    @State private var links: [Link] = []
    @State private var removedLinkIds: Set<Int> = []
    @State private var linkIdsToDelete: Set<Int> = []
    @State private var newLinkURL: String = ""
    @State private var linkError: String?
    @State private var editingLinkId: Int?
    @State private var editingLinkTitle: String = ""

    @State private var showHelp = false

    init(themeId: Int, themeName: String, existing: PortfolioThemeUpdate? = nil, onSave: @escaping (PortfolioThemeUpdate) -> Void, onCancel: @escaping () -> Void, logSource: String? = nil) {
        self.themeId = themeId
        self.themeName = themeName
        self.existing = existing
        self.onSave = onSave
        self.onCancel = onCancel
        self.logSource = logSource
        _title = State(initialValue: existing?.title ?? "")
        _bodyMarkdown = State(initialValue: existing?.bodyMarkdown ?? "")
        _type = State(initialValue: existing?.type ?? .General)
        _pinned = State(initialValue: existing?.pinned ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existing == nil ? "New Update — \(themeName)" : "Edit Update — \(themeName)")
                .font(.headline)
            TextField("Title", text: $title)
            Picker("Type", selection: $type) {
                ForEach(PortfolioThemeUpdate.UpdateType.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            Toggle("Pin this update", isOn: $pinned)
            HStack {
                Picker("Mode", selection: $mode) {
                    Text("Write").tag(Mode.write)
                    Text("Preview").tag(Mode.preview)
                }
                .pickerStyle(.segmented)
                Button("Help") { showHelp = true }
                    .popover(isPresented: $showHelp) { MarkdownHelpView().frame(width: 300, height: 200) }
            }
            if mode == .write {
                TextEditor(text: $bodyMarkdown)
                    .frame(minHeight: 120)
            } else {
                ScrollView {
                    Text(MarkdownRenderer.attributedString(from: bodyMarkdown))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 120)
            }
            HStack {
                Text("\(bodyMarkdown.count) / 5000")
                    .font(.caption)
                    .foregroundColor(bodyMarkdown.count > 5000 ? .red : .secondary)
                Spacer()
                if let existing = existing {
                    Text("Created: \(DateFormatting.userFriendly(existing.createdAt))   Edited: \(DateFormatting.userFriendly(existing.updatedAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            if attachmentsEnabled {
                attachmentsView
            }
            linksView
            Text("On save we will capture: Positions \(DateFormatting.userFriendly(positionsAsOf)) • Total CHF \(formatted(totalValueChf))")
                .font(.footnote)
                .foregroundColor(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!valid)
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 360)
        .onAppear { loadSnapshot() }
    }

    private var valid: Bool {
        PortfolioThemeUpdate.isValidTitle(title) && PortfolioThemeUpdate.isValidBody(bodyMarkdown)
    }

    private func formatted(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        return v.formatted(.currency(code: dbManager.baseCurrency).precision(.fractionLength(2)))
    }

    private func loadSnapshot() {
        let fx = FXConversionService(dbManager: dbManager)
        let service = PortfolioValuationService(dbManager: dbManager, fxService: fx)
        let snap = service.snapshot(themeId: themeId)
        if let asOf = snap.positionsAsOf {
            positionsAsOf = ISO8601DateFormatter().string(from: asOf)
        } else {
            positionsAsOf = nil
        }
        totalValueChf = snap.totalValueBase
        if attachmentsEnabled, let existing = existing {
            let repo = ThemeUpdateRepository(dbManager: dbManager)
            attachments = repo.listAttachments(updateId: existing.id)
        }
        if let existing = existing {
            let lrepo = ThemeUpdateLinkRepository(dbManager: dbManager)
            links = lrepo.listLinks(updateId: existing.id)
        }
    }

    private func save() {
        if let existing = existing {
            if let updated = dbManager.updateThemeUpdate(id: existing.id, title: title, bodyMarkdown: bodyMarkdown, type: type, pinned: pinned, actor: NSFullUserName(), expectedUpdatedAt: existing.updatedAt, source: logSource) {
                if attachmentsEnabled {
                    let repo = ThemeUpdateRepository(dbManager: dbManager)
                    let currentIds = Set(attachments.map { $0.id })
                    let initialIds = Set(repo.listAttachments(updateId: existing.id).map { $0.id })
                    let added = currentIds.subtracting(initialIds)
                    let removed = initialIds.subtracting(currentIds).union(removedAttachmentIds)
                    for id in added { _ = repo.linkAttachment(updateId: updated.id, attachmentId: id) }
                    for id in removed { _ = repo.unlinkAttachment(updateId: updated.id, attachmentId: id) }
                }
                let lrepo = ThemeUpdateLinkRepository(dbManager: dbManager)
                let currentLinkIds = Set(links.map { $0.id })
                let initialLinkIds = Set(lrepo.listLinks(updateId: existing.id).map { $0.id })
                let addedLinks = currentLinkIds.subtracting(initialLinkIds)
                let removedLinks = initialLinkIds.subtracting(currentLinkIds).union(removedLinkIds)
                for id in addedLinks {
                    _ = lrepo.link(updateId: updated.id, linkId: id)
                    LoggingService.shared.log("{ themeUpdateId: \(updated.id), linkId: \(id), op:'link_add' }", type: .info, logger: .database)
                }
                for id in removedLinks {
                    _ = lrepo.unlink(updateId: updated.id, linkId: id)
                    LoggingService.shared.log("{ themeUpdateId: \(updated.id), linkId: \(id), op:'link_unlink' }", type: .info, logger: .database)
                    if linkIdsToDelete.contains(id) {
                        _ = LinkService(dbManager: dbManager).deleteIfUnreferenced(linkId: id)
                        LoggingService.shared.log("{ linkId: \(id), op:'link_delete' }", type: .info, logger: .database)
                    }
                }
                onSave(updated)
            }
        } else {
            if let created = dbManager.createThemeUpdate(themeId: themeId, title: title, bodyMarkdown: bodyMarkdown, type: type, pinned: pinned, author: NSFullUserName(), positionsAsOf: positionsAsOf, totalValueChf: totalValueChf, source: logSource) {
                if attachmentsEnabled {
                    let repo = ThemeUpdateRepository(dbManager: dbManager)
                    for att in attachments {
                        _ = repo.linkAttachment(updateId: created.id, attachmentId: att.id)
                    }
                }
                let lrepo = ThemeUpdateLinkRepository(dbManager: dbManager)
                for link in links {
                    _ = lrepo.link(updateId: created.id, linkId: link.id)
                    LoggingService.shared.log("{ themeUpdateId: \(created.id), linkId: \(link.id), op:'link_add' }", type: .info, logger: .database)
                }
                onSave(created)
            }
        }
    }

    var attachmentsEnabled: Bool {
        FeatureFlags.portfolioAttachmentsEnabled()
    }

    @MainActor
    private func addFiles(urls: [URL]) {
        let service = AttachmentService(dbManager: dbManager)
        for url in urls {
            if let att = service.ingest(fileURL: url, actor: NSFullUserName()) {
                attachments.append(att)
            }
        }
    }

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.begin { resp in
            if resp == .OK {
                addFiles(urls: panel.urls)
            }
        }
    }

    private func removeAttachment(_ att: Attachment) {
        let alert = NSAlert()
        alert.messageText = "Delete file?"
        alert.informativeText = "The attachment will be removed from the update. Also delete the file from storage?"
        alert.addButton(withTitle: "Delete File")
        alert.addButton(withTitle: "Keep File")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let existing = existing {
                _ = ThemeUpdateRepository(dbManager: dbManager).unlinkAttachment(updateId: existing.id, attachmentId: att.id)
            }
            AttachmentService(dbManager: dbManager).deleteAttachment(attachmentId: att.id)
        } else {
            removedAttachmentIds.insert(att.id)
        }
        attachments.removeAll { $0.id == att.id }
    }

    @ViewBuilder
    private var attachmentsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Attachments")
                .font(.headline)
            Rectangle()
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                .frame(height: 80)
                .overlay(Text("Drag files here or"))
                .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
                    Task {
                        var urls: [URL] = []
                        for provider in providers {
                            if let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier),
                               let data = item as? Data,
                               let url = URL(dataRepresentation: data, relativeTo: nil) {
                                urls.append(url)
                            }
                        }
                        addFiles(urls: urls)
                    }
                    return true
                }
            Button("Attach Files…") { pickFiles() }
            ForEach(attachments, id: \.id) { att in
                HStack {
                    Text(att.originalFilename)
                    Spacer()
                    Button("Quick Look") { AttachmentService(dbManager: dbManager).quickLook(attachmentId: att.id) }
                    Button("Remove") { removeAttachment(att) }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func addLink() {
        let service = LinkService(dbManager: dbManager)
        switch service.validateAndNormalize(newLinkURL) {
        case .success(let norm):
            if links.contains(where: { $0.normalizedURL == norm.normalized }) {
                linkError = "This link is already attached."
                return
            }
            if let link = service.ensureLink(normalized: norm.normalized, raw: norm.raw, actor: NSFullUserName()) {
                links.append(link)
                LoggingService.shared.log("{ themeUpdateId: \(existing?.id ?? 0), linkId: \(link.id), normalized_url: \(norm.normalized), actor: \(NSFullUserName()), op:'link_add' }", type: .info, logger: .database)
                newLinkURL = ""
                linkError = nil
            }
        case .failure(let err):
            switch err {
            case .unsupportedScheme: linkError = "Only http/https URLs are supported"
            case .invalidURL: linkError = "Invalid URL"
            case .tooLong: linkError = "URL exceeds 2048 characters"
            case .missingHost: linkError = "URL must include host"
            case .hasWhitespace: linkError = "URL must not contain spaces"
            case .hasCredentials: linkError = "Credentials not allowed in URL"
            }
        }
    }

    private func openLink(_ link: Link) {
        if let url = URL(string: link.rawURL) {
            NSWorkspace.shared.open(url)
            LoggingService.shared.log("{ themeUpdateId: \(existing?.id ?? 0), linkId: \(link.id), host: \(url.host ?? ""), op:'link_open' }", type: .info, logger: .database)
        }
    }

    private func copyLink(_ link: Link) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(link.rawURL, forType: .string)
    }

    private func removeLink(_ link: Link) {
        let alert = NSAlert()
        alert.messageText = "Delete link?"
        alert.informativeText = "The link will be removed from the update. Also delete the link from storage if unused?"
        alert.addButton(withTitle: "Delete Link")
        alert.addButton(withTitle: "Keep")
        let resp = alert.runModal()
        if existing != nil {
            removedLinkIds.insert(link.id)
            if resp == .alertFirstButtonReturn { linkIdsToDelete.insert(link.id) }
        } else {
            if resp == .alertFirstButtonReturn {
                _ = LinkService(dbManager: dbManager).deleteIfUnreferenced(linkId: link.id)
            }
        }
        links.removeAll { $0.id == link.id }
    }

    private func saveLinkTitle(_ link: Link) {
        let service = LinkService(dbManager: dbManager)
        if service.updateTitle(linkId: link.id, title: editingLinkTitle.isEmpty ? nil : editingLinkTitle) {
            if let idx = links.firstIndex(where: { $0.id == link.id }) {
                links[idx] = Link(id: link.id, normalizedURL: link.normalizedURL, rawURL: link.rawURL, title: editingLinkTitle.isEmpty ? nil : editingLinkTitle, createdAt: link.createdAt, createdBy: link.createdBy)
            }
        }
        editingLinkId = nil
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

    @ViewBuilder
    private var linksView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Links")
                .font(.headline)
            HStack {
                TextField("https://…", text: $newLinkURL)
                    .textFieldStyle(.roundedBorder)
                Button("Add") { addLink() }
            }
            if let err = linkError {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            ForEach(links, id: \.id) { link in
                VStack(alignment: .leading) {
                    HStack {
                        Text("🔗")
                        Text(displayTitle(link))
                        Spacer()
                        Button("Open") { openLink(link) }
                        Button("Copy") { copyLink(link) }
                        Button("Edit title") {
                            editingLinkId = link.id
                            editingLinkTitle = link.title ?? ""
                        }
                        Button("Remove") { removeLink(link) }
                    }
                    if editingLinkId == link.id {
                        HStack {
                            TextField("Title", text: $editingLinkTitle)
                                .frame(width: 200)
                            Button("Save") { saveLinkTitle(link) }
                            Button("Cancel") { editingLinkId = nil }
                        }
                        Text("Changes apply wherever this link is used.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct MarkdownHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                helpRow("# Heading", rendered: "# Heading")
                helpRow("This is **bold**, *italic*, `code`.", rendered: "This is **bold**, *italic*, `code`.")
                helpRow("- Bullet item", rendered: "- Bullet item")
                helpRow("1. Numbered", rendered: "1. Numbered")
                helpRow("Link: [text](https://example.com)", rendered: "Link: [text](https://example.com)")
                Text("Images and raw HTML are not rendered.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    private func helpRow(_ syntax: String, rendered: String) -> some View {
        HStack(alignment: .top) {
            Text(syntax)
                .font(.system(.body, design: .monospaced))
            Spacer()
            Text(MarkdownRenderer.attributedString(from: rendered))
        }
    }
}
