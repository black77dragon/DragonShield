// DragonShield/Views/InstrumentUpdateEditorView.swift
// MARK: - Version 1.1
// MARK: - History
// - 1.0: Initial instrument update editor for Step 7A.
// - 1.0 -> 1.1: Add Markdown editing with preview and pin toggle for Phase 7B.

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct InstrumentUpdateEditorView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    let instrumentId: Int
    let instrumentName: String
    let themeName: String
    var existing: PortfolioThemeAssetUpdate?
    var valuation: ValuationSnapshot?
    var onSave: (PortfolioThemeAssetUpdate) -> Void
    var onCancel: () -> Void

    enum Mode { case write, preview }

    @State private var title: String
    @State private var bodyMarkdown: String
    @State private var type: PortfolioThemeAssetUpdate.UpdateType
    @State private var pinned: Bool
    @State private var mode: Mode = .write
    @State private var breadcrumb: (positionsAsOf: String?, valueChf: Double?, actualPercent: Double?)?
    @State private var showHelp = false
    @State private var attachments: [Attachment] = []
    @State private var removedAttachmentIds: Set<Int> = []

    init(themeId: Int, instrumentId: Int, instrumentName: String, themeName: String, existing: PortfolioThemeAssetUpdate? = nil, valuation: ValuationSnapshot? = nil, onSave: @escaping (PortfolioThemeAssetUpdate) -> Void, onCancel: @escaping () -> Void) {
        self.themeId = themeId
        self.instrumentId = instrumentId
        self.instrumentName = instrumentName
        self.themeName = themeName
        self.existing = existing
        self.valuation = valuation
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: existing?.title ?? "")
        _bodyMarkdown = State(initialValue: existing?.bodyMarkdown ?? "")
        _type = State(initialValue: existing?.type ?? .General)
        _pinned = State(initialValue: existing?.pinned ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existing == nil ? "New Instrument Update — \(instrumentName)" : "Edit Instrument Update — \(instrumentName)")
                .font(.headline)
            Text("Theme: \(themeName)")
                .font(.subheadline)
            TextField("Title (1–120)", text: $title)
            Picker("Type", selection: $type) {
                ForEach(PortfolioThemeAssetUpdate.UpdateType.allCases, id: \.self) { t in
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
            attachmentsView
            Text("On save we will capture: Positions \(DateFormatting.userFriendly(breadcrumb?.positionsAsOf)) • Value CHF \(formatted(breadcrumb?.valueChf)) • Actual \(formattedPct(breadcrumb?.actualPercent))")
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
        .onAppear { loadBreadcrumb() }
    }

    private var valid: Bool {
        PortfolioThemeAssetUpdate.isValidTitle(title) && PortfolioThemeAssetUpdate.isValidBody(bodyMarkdown)
    }

    private func loadBreadcrumb() {
        guard breadcrumb == nil else { return }
        guard let snap = valuation else { return }
        let formatter = ISO8601DateFormatter()
        let pos = snap.positionsAsOf.map { formatter.string(from: $0) }
        let row = snap.rows.first { $0.instrumentId == instrumentId }
        breadcrumb = (pos, row?.currentValueBase, row?.actualPct)
        if let existing = existing {
            let repo = ThemeAssetUpdateRepository(dbManager: dbManager)
            attachments = repo.listAttachments(updateId: existing.id)
        }
    }

    private func formatted(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        return v.formatted(.currency(code: dbManager.baseCurrency).precision(.fractionLength(2)))
    }

    private func formattedPct(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        return v.formatted(.number.precision(.fractionLength(2))) + "%"
    }

    private func save() {
        if let existing = existing {
            if let updated = dbManager.updateInstrumentUpdate(id: existing.id, title: title, bodyMarkdown: bodyMarkdown, type: type, pinned: pinned, actor: NSFullUserName(), expectedUpdatedAt: existing.updatedAt) {
                let repo = ThemeAssetUpdateRepository(dbManager: dbManager)
                let currentIds = Set(attachments.map { $0.id })
                let initialIds = Set(repo.listAttachments(updateId: existing.id).map { $0.id })
                let added = currentIds.subtracting(initialIds)
                let removed = initialIds.subtracting(currentIds).union(removedAttachmentIds)
                for id in added { _ = repo.linkAttachment(updateId: updated.id, attachmentId: id) }
                for id in removed { _ = repo.unlinkAttachment(updateId: updated.id, attachmentId: id) }
                onSave(updated)
            }
        } else {
            if let created = dbManager.createInstrumentUpdate(themeId: themeId, instrumentId: instrumentId, title: title, bodyMarkdown: bodyMarkdown, type: type, pinned: pinned, author: NSFullUserName(), breadcrumb: breadcrumb) {
                let repo = ThemeAssetUpdateRepository(dbManager: dbManager)
                for att in attachments { _ = repo.linkAttachment(updateId: created.id, attachmentId: att.id) }
                onSave(created)
            }
        }
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
                _ = ThemeAssetUpdateRepository(dbManager: dbManager).unlinkAttachment(updateId: existing.id, attachmentId: att.id)
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
                        await addFiles(urls: urls)
                    }
                    return true
                }
            Button("Attach Files…") { pickFiles() }
            ForEach(attachments, id: \.id) { att in
                HStack(alignment: .center, spacing: 8) {
                    AttachmentThumbChip(attachment: att) {
                        AttachmentService(dbManager: dbManager).quickLook(attachmentId: att.id)
                    }
                    VStack(alignment: .leading) {
                        Text(att.originalFilename)
                        Text(ByteCountFormatter.string(fromByteCount: Int64(att.byteSize), countStyle: .file))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Quick Look") { AttachmentService(dbManager: dbManager).quickLook(attachmentId: att.id) }
                    Button("Reveal in Finder") { AttachmentService(dbManager: dbManager).revealInFinder(attachmentId: att.id) }
                    Button("Remove") { removeAttachment(att) }
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
