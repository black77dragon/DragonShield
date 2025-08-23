// DragonShield/Views/ThemeUpdateEditorView.swift
// MARK: - Version 1.1
// MARK: - History
// - 1.0 -> 1.1: Add Markdown editing with preview and pin toggle.

import SwiftUI
import UniformTypeIdentifiers

struct ThemeUpdateEditorView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    let themeName: String
    var existing: PortfolioThemeUpdate?
    var onSave: (PortfolioThemeUpdate) -> Void
    var onCancel: () -> Void
    var logSource: String?
    var attachmentsFlag: Bool

    enum Mode { case write, preview }

    @State private var title: String
    @State private var bodyMarkdown: String
    @State private var type: PortfolioThemeUpdate.UpdateType
    @State private var pinned: Bool
    @State private var mode: Mode = .write
    @State private var positionsAsOf: String?
    @State private var totalValueChf: Double?

    @State private var showHelp = false

    @State private var attachments: [Attachment] = []
    @State private var showFileImporter = false
    @State private var dropTarget = false

    init(themeId: Int, themeName: String, existing: PortfolioThemeUpdate? = nil, attachmentsFlag: Bool = FeatureFlags.portfolioAttachmentsEnabled(), onSave: @escaping (PortfolioThemeUpdate) -> Void, onCancel: @escaping () -> Void, logSource: String? = nil) {
        self.themeId = themeId
        self.themeName = themeName
        self.existing = existing
        self.onSave = onSave
        self.onCancel = onCancel
        self.logSource = logSource
        self.attachmentsFlag = attachmentsFlag
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
            if attachmentsFlag {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Attachments")
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(attachments, id: \.id) { att in
                            Text(att.originalFilename)
                        }
                    }
                    Rectangle()
                        .strokeBorder(dropTarget ? Color.accentColor : Color.secondary, style: StrokeStyle(lineWidth: 2, dash: [5]))
                        .frame(height: 80)
                        .overlay(Text("Drag files here or  Attach Files…").foregroundColor(.secondary))
                        .onDrop(of: AttachmentService.allowedTypes.map { $0.identifier }, isTargeted: $dropTarget) { providers in
                            handleDrop(providers: providers)
                        }
                        .onTapGesture { showFileImporter = true }
                }
                .fileImporter(isPresented: $showFileImporter, allowedContentTypes: AttachmentService.allowedTypes, allowsMultipleSelection: true) { result in
                    if case .success(let urls) = result {
                        for url in urls { ingestFile(url) }
                    }
                }
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

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for item in providers {
            if item.hasItemConformingToTypeIdentifier("public.file-url") {
                item.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
                    if let data = data as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        ingestFile(url)
                    }
                }
            }
        }
        return true
    }

    private func ingestFile(_ url: URL) {
        let service = AttachmentService(dbManager: dbManager)
        switch service.ingest(fileURL: url, actor: NSFullUserName()) {
        case .success(let attachment):
            DispatchQueue.main.async {
                attachments.append(attachment)
            }
        case .failure(let error):
            LoggingService.shared.log("Attachment ingest failed: \(error)", type: .error, logger: .app)
        }
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
                for att in attachments { _ = repo.linkAttachment(updateId: updated.id, attachmentId: att.id) }
                onSave(updated)
            }
        } else {
            if let created = dbManager.createThemeUpdate(themeId: themeId, title: title, bodyMarkdown: bodyMarkdown, type: type, pinned: pinned, author: NSFullUserName(), positionsAsOf: positionsAsOf, totalValueChf: totalValueChf, source: logSource) {
                for att in attachments { _ = repo.linkAttachment(updateId: created.id, attachmentId: att.id) }
                onSave(created)
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
