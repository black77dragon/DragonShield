import SwiftUI
import AppKit

struct InstrumentNoteEditorView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let instrumentId: Int
    let instrumentName: String
    var existing: InstrumentNote?
    var onSave: (InstrumentNote) -> Void
    var onCancel: () -> Void

    enum Mode { case write, preview }

    @State private var title: String
    @State private var bodyMarkdown: String
    @State private var selectedTypeId: Int?
    @State private var newsTypes: [NewsTypeRow] = []
    @State private var pinned: Bool
    @State private var mode: Mode = .write
    @State private var showHelp = false
    @State private var feedback: SaveFeedback?

    init(instrumentId: Int, instrumentName: String, existing: InstrumentNote? = nil, onSave: @escaping (InstrumentNote) -> Void, onCancel: @escaping () -> Void) {
        self.instrumentId = instrumentId
        self.instrumentName = instrumentName
        self.existing = existing
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: existing?.title ?? "")
        _bodyMarkdown = State(initialValue: existing?.bodyMarkdown ?? "")
        _selectedTypeId = State(initialValue: existing?.typeId)
        _pinned = State(initialValue: existing?.pinned ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existing == nil ? "New Note — \(instrumentName)" : "Edit Note — \(instrumentName)")
                .font(.headline)
            TextField("Title (1–120)", text: $title)
            Picker("Type", selection: $selectedTypeId) {
                ForEach(newsTypes, id: \.id) { nt in
                    Text(nt.displayName).tag(Optional(nt.id))
                }
            }
            Toggle("Pin this note", isOn: $pinned)
            HStack {
                Picker("Mode", selection: $mode) {
                    Text("Write").tag(Mode.write)
                    Text("Preview").tag(Mode.preview)
                }
                .pickerStyle(.segmented)
                Button("Help") { showHelp = true }
                    .popover(isPresented: $showHelp) {
                        MarkdownHelpView().frame(width: 300, height: 200)
                    }
            }
            if mode == .write {
                TextEditor(text: $bodyMarkdown)
                    .frame(minHeight: 160)
            } else {
                ScrollView {
                    Text(MarkdownRenderer.attributedString(from: bodyMarkdown))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 160)
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
            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                if existing != nil {
                    Button("Delete", role: .destructive) { deleteExisting() }
                }
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!valid)
            }
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 320)
        .onAppear {
            newsTypes = NewsTypeRepository(dbManager: dbManager).listActive()
            if selectedTypeId == nil {
                selectedTypeId = newsTypes.first?.id
            }
        }
        .alert(item: $feedback) { info in
            Alert(title: Text(info.title), message: Text(info.message), dismissButton: .default(Text("OK")))
        }
    }

    private var valid: Bool {
        InstrumentNote.isValidTitle(title) && InstrumentNote.isValidBody(bodyMarkdown)
    }

    private func save() {
        let code = newsTypes.first(where: { $0.id == selectedTypeId })?.code ?? PortfolioUpdateType.General.rawValue
        if let existing = existing {
            let updated = dbManager.updateInstrumentUpdate(
                id: existing.id,
                title: title,
                bodyMarkdown: bodyMarkdown,
                newsTypeCode: code,
                pinned: pinned,
                actor: NSFullUserName(),
                expectedUpdatedAt: existing.updatedAt
            )
            if let row = updated ?? dbManager.getInstrumentUpdate(id: existing.id) {
                onSave(row)
            } else {
                feedback = SaveFeedback(title: "Save Failed", message: dbManager.lastSQLErrorMessage())
            }
        } else {
            if let created = dbManager.createInstrumentNote(instrumentId: instrumentId, title: title, bodyMarkdown: bodyMarkdown, newsTypeCode: code, pinned: pinned, author: NSFullUserName()) {
                onSave(created)
            } else {
                feedback = SaveFeedback(title: "Save Failed", message: dbManager.lastSQLErrorMessage())
            }
        }
    }

    private func deleteExisting() {
        guard let existing = existing else { return }
        let alert = NSAlert()
        alert.messageText = "Delete this note?"
        alert.informativeText = "This cannot be undone."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            if dbManager.deleteInstrumentUpdate(id: existing.id, actor: NSFullUserName()) {
                onCancel()
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

private struct SaveFeedback: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
