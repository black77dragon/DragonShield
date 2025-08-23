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
    let attachmentsEnabled: Bool

    enum Mode { case write, preview }

    @State private var title: String
    @State private var bodyMarkdown: String
    @State private var type: PortfolioThemeUpdate.UpdateType
    @State private var pinned: Bool
    @State private var mode: Mode = .write
    @State private var positionsAsOf: String?
    @State private var totalValueChf: Double?
    @State private var attachments: [Attachment] = []

    @State private var showHelp = false

    init(themeId: Int, themeName: String, existing: PortfolioThemeUpdate? = nil, attachmentsEnabled: Bool = FeatureFlags.portfolioAttachmentsEnabled(), onSave: @escaping (PortfolioThemeUpdate) -> Void, onCancel: @escaping () -> Void, logSource: String? = nil) {
        self.themeId = themeId
        self.themeName = themeName
        self.existing = existing
        self.attachmentsEnabled = attachmentsEnabled
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
                attachmentSection
            }
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
    }

    private func save() {
        let repo = ThemeUpdateRepository(dbManager: dbManager)
        if let existing = existing {
            if let updated = dbManager.updateThemeUpdate(id: existing.id, title: title, bodyMarkdown: bodyMarkdown, type: type, pinned: pinned, actor: NSFullUserName(), expectedUpdatedAt: existing.updatedAt, source: logSource) {
                linkAttachments(to: updated.id, repo: repo)
                onSave(updated)
            }
        } else {
            if let created = dbManager.createThemeUpdate(themeId: themeId, title: title, bodyMarkdown: bodyMarkdown, type: type, pinned: pinned, author: NSFullUserName(), positionsAsOf: positionsAsOf, totalValueChf: totalValueChf, source: logSource) {
                linkAttachments(to: created.id, repo: repo)
                onSave(created)
            }
        }
    }

    private func linkAttachments(to updateId: Int, repo: ThemeUpdateRepository) {
        for att in attachments {
            _ = repo.linkAttachment(updateId: updateId, attachmentId: att.id)
        }
    }

    private var attachmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Attachments")
            VStack {
                if attachments.isEmpty {
                    Text("Drag files here or Attach Files…")
                        .frame(maxWidth: .infinity, minHeight: 80)
                        .background(Color.secondary.opacity(0.1))
                        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
                            handleDrop(providers: providers)
                        }
                } else {
                    ForEach(Array(attachments.enumerated()), id: \.1.id) { index, att in
                        HStack {
                            Text(att.originalFilename)
                            Spacer()
                            Button("Remove") { attachments.remove(at: index) }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
                        handleDrop(providers: providers)
                    }
                }
            }
            Button("Attach Files…") { openPanel() }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for p in providers {
            p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    addFile(url)
                }
            }
        }
        return true
    }

    private func openPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            panel.urls.forEach { addFile($0) }
        }
    }

    private func addFile(_ url: URL) {
        let service = AttachmentService(dbManager: dbManager)
        if let attachment = try? service.ingest(fileURL: url, actor: NSFullUserName()) {
            DispatchQueue.main.async {
                attachments.append(attachment)
            }
        }
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
