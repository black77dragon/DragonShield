// DragonShield/Views/ThemeUpdateEditorView.swift
// MARK: - Version 1.2
// MARK: - History
// - 1.1 -> 1.2: Friendly timestamps, Markdown help popover, and optional logging source.
// - 1.0 -> 1.1: Add Markdown editing with preview and pin toggle.

import SwiftUI

struct ThemeUpdateEditorView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    let themeName: String
    var existing: PortfolioThemeUpdate?
    var onSave: (PortfolioThemeUpdate) -> Void
    var onCancel: () -> Void
    var source: String? = nil

    enum Mode { case write, preview }

    @State private var title: String
    @State private var bodyMarkdown: String
    @State private var type: PortfolioThemeUpdate.UpdateType
    @State private var pinned: Bool
    @State private var mode: Mode = .write
    @State private var positionsAsOf: String?
    @State private var totalValueChf: Double?
    @State private var showHelp = false

    init(themeId: Int, themeName: String, existing: PortfolioThemeUpdate? = nil, onSave: @escaping (PortfolioThemeUpdate) -> Void, onCancel: @escaping () -> Void, source: String? = nil) {
        self.themeId = themeId
        self.themeName = themeName
        self.existing = existing
        self.onSave = onSave
        self.onCancel = onCancel
        self.source = source
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
                    .buttonStyle(.borderless)
                    .popover(isPresented: $showHelp) { MarkdownHelpView() }
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
            Text("\(bodyMarkdown.count) / 5000")
                .font(.caption)
                .foregroundColor(bodyMarkdown.count > 5000 ? .red : .secondary)
            if let existing = existing {
                Text("Created: \(DateFormatting.friendly(existing.createdAt))   Edited: \(DateFormatting.friendly(existing.updatedAt))")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                Text("On save we will capture: Positions \(DateFormatting.friendly(positionsAsOf)) • Total CHF \(formatted(totalValueChf))")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
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
        if let existing = existing {
            if let updated = dbManager.updateThemeUpdate(id: existing.id, title: title, bodyMarkdown: bodyMarkdown, type: type, pinned: pinned, actor: NSFullUserName(), expectedUpdatedAt: existing.updatedAt, source: source) {
                onSave(updated)
            }
        } else {
            if let created = dbManager.createThemeUpdate(themeId: themeId, title: title, bodyMarkdown: bodyMarkdown, type: type, pinned: pinned, author: NSFullUserName(), positionsAsOf: positionsAsOf, totalValueChf: totalValueChf) {
                onSave(created)
            }
        }
    }
}

struct MarkdownHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text("# Heading\n## Subheading").font(.system(.body, design: .monospaced))
                    Text(MarkdownRenderer.attributedString(from: "# Heading\n## Subheading"))
                }
                HStack(alignment: .top) {
                    Text("This is **bold**, *italic*, `code`").font(.system(.body, design: .monospaced))
                    Text(MarkdownRenderer.attributedString(from: "This is **bold**, *italic*, `code`"))
                }
                HStack(alignment: .top) {
                    Text("- Bullet item\n1. Numbered").font(.system(.body, design: .monospaced))
                    Text(MarkdownRenderer.attributedString(from: "- Bullet item\n1. Numbered"))
                }
                HStack(alignment: .top) {
                    Text("Link: [text](https://example.com)").font(.system(.body, design: .monospaced))
                    Text(MarkdownRenderer.attributedString(from: "[text](https://example.com)"))
                }
                Text("Images and raw HTML are not rendered.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 300)
    }
}
