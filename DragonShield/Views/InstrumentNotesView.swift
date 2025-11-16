import AppKit
import SwiftUI

struct InstrumentNotesView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let instrumentId: Int
    let instrumentCode: String
    let instrumentName: String
    var initialTab: Tab = .updates
    var initialThemeId: Int?
    var onClose: () -> Void

    enum Tab {
        case general
        case updates
        case mentions
    }

    struct ThemeInfo: Identifiable {
        let themeId: Int
        let name: String
        let isArchived: Bool
        let updatesCount: Int
        let mentionsCount: Int
        var id: Int { themeId }
    }

    @State private var selectedTab: Tab
    @State private var themeInfos: [ThemeInfo] = []
    @State private var selectedThemeId: Int?
    @State private var generalNotes: [InstrumentNote] = []
    @State private var updates: [InstrumentNote] = []
    @State private var mentions: [PortfolioThemeUpdate] = []
    @State private var searchText = ""
    @State private var pinnedFirst = true
    @State private var generalPinnedFirst = true
    @State private var openThemeInfo: ThemeInfo?
    @State private var attachmentCounts: [Int: Int] = [:]
    @State private var showGeneralEditor = false
    @State private var editingGeneralNote: InstrumentNote?
    @State private var showThemeEditor = false
    @State private var editingThemeUpdate: InstrumentNote?
    @State private var statusFeedback: NoteStatus?

    init(instrumentId: Int, instrumentCode: String, instrumentName: String, initialTab: Tab = .updates, initialThemeId: Int? = nil, onClose: @escaping () -> Void) {
        self.instrumentId = instrumentId
        self.instrumentCode = instrumentCode
        self.instrumentName = instrumentName
        self.initialTab = initialTab
        self.initialThemeId = initialThemeId
        self.onClose = onClose
        _selectedTab = State(initialValue: initialTab)
        _selectedThemeId = State(initialValue: initialThemeId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Instrument Notes — \(instrumentName) (Code: \(instrumentCode))")
                .font(.headline)
                .padding(16)
            Picker("Theme", selection: $selectedThemeId) {
                Text("All themes").tag(nil as Int?)
                ForEach(themeInfos) { info in
                    Text(info.name).tag(info.themeId as Int?)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 16)
            Picker("", selection: $selectedTab) {
                Text("General Notes").tag(Tab.general)
                Text("Portfolio Updates").tag(Tab.updates)
                Text("Theme Mentions").tag(Tab.mentions)
            }
            .pickerStyle(.segmented)
            .padding(16)
            switch selectedTab {
            case .general:
                generalList
            case .updates:
                updatesList
            case .mentions:
                mentionsList
            }
            Divider()
            HStack {
                Spacer()
                Button(role: .cancel) { onClose() } label: {
                    Label("Close", systemImage: "xmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.gray)
                .foregroundColor(.white)
                .keyboardShortcut("w", modifiers: .command)
            }
            .padding(16)
        }
        .frame(minWidth: 640, minHeight: 400)
        .onAppear {
            loadThemes()
            loadData()
            logOpen()
            UserDefaults.standard.set(tabKey(selectedTab), forKey: "instrumentNotesLastTab")
        }
        .onChange(of: selectedTab) { _, _ in
            loadData()
            logTab()
            UserDefaults.standard.set(tabKey(selectedTab), forKey: "instrumentNotesLastTab")
        }
        .onChange(of: selectedThemeId) { _, _ in loadData() }
        .onChange(of: pinnedFirst) { _, _ in if selectedTab == .updates { loadUpdates() } }
        .onChange(of: searchText) { _, _ in if selectedTab == .mentions { loadMentions() } }
        .sheet(item: $openThemeInfo) { info in
            workspaceSheet(info)
        }
        .alert(item: $statusFeedback) { info in
            Alert(title: Text(info.title), message: Text(info.message), dismissButton: .default(Text("OK")))
        }
    }

    @ViewBuilder
    private func workspaceSheet(_ info: ThemeInfo) -> some View {
        let query: String = instrumentCode.isEmpty ? instrumentName : instrumentCode.uppercased()
        let hint: String = instrumentCode.isEmpty ? "Showing theme notes mentioning \(instrumentName)" : "Showing theme notes mentioning \(instrumentCode.uppercased()) (\(instrumentName))"
        PortfolioThemeWorkspaceView(
            themeId: info.themeId,
            origin: "instrument_mentions",
            initialTab: .updates,
            initialUpdatesSearch: query,
            initialUpdatesSearchHint: hint
        )
        .environmentObject(dbManager)
    }

    private var generalList: some View {
        VStack(alignment: .leading) {
            HStack {
                Button("Add Note") {
                    editingGeneralNote = nil
                    showGeneralEditor = true
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.67, green: 0.89, blue: 0.67))
                .foregroundColor(.black)
                Spacer()
                Toggle("Pinned first", isOn: $generalPinnedFirst)
                    .toggleStyle(.checkbox)
                    .onChange(of: generalPinnedFirst) { _, _ in
                        if selectedTab == .general { loadGeneralNotes() }
                    }
            }
            .padding(.horizontal, 16)
            List {
                ForEach(generalNotes, id: \.id) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(DateFormatting.userFriendly(note.createdAt)) • \(note.author) • \(note.typeDisplayName ?? note.typeCode)")
                            Spacer()
                            Text(note.pinned ? "★" : "☆")
                        }
                        Text(note.title).fontWeight(.semibold)
                        Text(MarkdownRenderer.attributedString(from: note.bodyMarkdown)).lineLimit(3)
                        HStack {
                            Spacer()
                            Button("Edit") {
                                editingGeneralNote = note
                            }
                            .font(.caption)
                            Button("Delete", role: .destructive) {
                                deleteNote(note)
                            }
                            .font(.caption)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showGeneralEditor) {
            InstrumentNoteEditorView(
                instrumentId: instrumentId,
                instrumentName: instrumentName,
                existing: editingGeneralNote,
                onSave: { note in
                    let wasEditing = editingGeneralNote != nil
                    showGeneralEditor = false
                    editingGeneralNote = nil
                    loadGeneralNotes()
                    statusFeedback = NoteStatus(title: wasEditing ? "Note Updated" : "Note Saved", message: "“\(note.title)” has been stored for \(instrumentName).")
                },
                onCancel: {
                    showGeneralEditor = false
                    editingGeneralNote = nil
                }
            )
            .environmentObject(dbManager)
        }
        .sheet(item: $editingGeneralNote) { note in
            InstrumentNoteEditorView(
                instrumentId: instrumentId,
                instrumentName: instrumentName,
                existing: note,
                onSave: { _ in
                    editingGeneralNote = nil
                    loadGeneralNotes()
                    statusFeedback = NoteStatus(title: "Note Updated", message: "Changes were saved for \(instrumentName).")
                },
                onCancel: {
                    editingGeneralNote = nil
                }
            )
            .environmentObject(dbManager)
        }
        .sheet(isPresented: $showThemeEditor) {
            if let themeId = editingThemeUpdate?.themeId ?? selectedThemeId {
                let wasEditing = editingThemeUpdate != nil
                InstrumentUpdateEditorView(
                    themeId: themeId,
                    instrumentId: instrumentId,
                    instrumentName: instrumentName,
                    themeName: themeName(for: themeId),
                    existing: editingThemeUpdate,
                    valuation: nil,
                    onSave: { _ in
                        showThemeEditor = false
                        editingThemeUpdate = nil
                        loadUpdates()
                        loadThemes()
                        let themeName = themeName(for: themeId)
                        statusFeedback = NoteStatus(title: wasEditing ? "Note Updated" : "Note Saved", message: "“\(instrumentName)” now has an update in \(themeName).")
                    },
                    onCancel: {
                        showThemeEditor = false
                        editingThemeUpdate = nil
                    }
                )
                .environmentObject(dbManager)
            } else {
                EmptyView()
            }
        }
    }

    private var updatesList: some View {
        VStack(alignment: .leading) {
            HStack {
                Button("Add Update") {
                    guard selectedThemeId != nil else { return }
                    editingThemeUpdate = nil
                    showThemeEditor = true
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.67, green: 0.89, blue: 0.67))
                .foregroundColor(.black)
                .disabled(selectedThemeId == nil)
                Spacer()
                Toggle("Pinned first", isOn: $pinnedFirst)
                    .toggleStyle(.checkbox)
            }
            .padding(.horizontal, 16)
            List {
                ForEach(updates, id: \.id) { update in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(DateFormatting.userFriendly(update.createdAt)) • \(update.author) • \(update.typeDisplayName ?? update.typeCode)")
                            Spacer()
                            Text(update.pinned ? "★" : "☆")
                        }
                        if selectedThemeId == nil, let themeId = update.themeId {
                            Text("Theme: \(themeName(for: themeId))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text(update.title).fontWeight(.semibold)
                            if (attachmentCounts[update.id] ?? 0) > 0 { Image(systemName: "paperclip") }
                        }
                        Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown)).lineLimit(3)
                        HStack {
                            Spacer()
                            Button("Open") {
                                editingThemeUpdate = update
                                showThemeEditor = true
                            }
                            .font(.caption)
                        }
                    }
                }
            }
        }
    }

    private var mentionsList: some View {
        VStack(alignment: .leading) {
            TextField("Search mentions", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16)
            List {
                ForEach(mentions, id: \.id) { mention in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(DateFormatting.userFriendly(mention.createdAt)) • Theme: \(themeName(for: mention.themeId)) • Type: \(mention.typeDisplayName ?? mention.typeCode)")
                            if isThemeArchived(mention.themeId) {
                                Text("Archived").font(.caption).foregroundColor(.secondary)
                            }
                        }
                        Text(mention.title).fontWeight(.semibold)
                        Text(MarkdownRenderer.attributedString(from: mention.bodyMarkdown)).lineLimit(3)
                        HStack {
                            Spacer()
                            Button("Open in Theme") { openTheme(mention.themeId) }
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }

    private func loadThemes() {
        let rows = dbManager.listThemesForInstrumentWithUpdateCounts(instrumentId: instrumentId, instrumentCode: instrumentCode, instrumentName: instrumentName)
        themeInfos = rows.map { ThemeInfo(themeId: $0.themeId, name: $0.themeName, isArchived: $0.isArchived, updatesCount: $0.updatesCount, mentionsCount: $0.mentionsCount) }
    }

    private func loadData() {
        switch selectedTab {
        case .general:
            loadGeneralNotes()
        case .updates:
            loadUpdates()
        case .mentions:
            loadMentions()
        }
    }

    private func loadUpdates() {
        updates = dbManager.listInstrumentUpdatesForInstrument(instrumentId: instrumentId, themeId: selectedThemeId, pinnedFirst: pinnedFirst)
        if !updates.isEmpty {
            attachmentCounts = dbManager.getInstrumentAttachmentCounts(for: updates.map { $0.id })
        } else {
            attachmentCounts = [:]
        }
    }

    private func loadGeneralNotes() {
        generalNotes = dbManager.listInstrumentGeneralNotes(instrumentId: instrumentId, pinnedFirst: generalPinnedFirst)
    }

    private func loadMentions() {
        let themeIds: [Int]
        if let t = selectedThemeId {
            themeIds = [t]
        } else {
            themeIds = themeInfos.map { $0.themeId }
        }
        var all: [PortfolioThemeUpdate] = []
        for id in themeIds {
            let list = dbManager.listThemeMentions(themeId: id, instrumentCode: instrumentCode, instrumentName: instrumentName)
            all.append(contentsOf: list)
        }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            all = all.filter { $0.title.localizedCaseInsensitiveContains(q) || $0.bodyMarkdown.localizedCaseInsensitiveContains(q) }
        }
        all.sort { $0.createdAt > $1.createdAt }
        mentions = all
    }

    private func tabKey(_ tab: Tab) -> String {
        switch tab {
        case .general: return "general"
        case .updates: return "updates"
        case .mentions: return "mentions"
        }
    }

    private func themeName(for id: Int?) -> String {
        guard let id else { return "" }
        return themeInfos.first { $0.themeId == id }?.name ?? ""
    }

    private func isThemeArchived(_ id: Int?) -> Bool {
        guard let id else { return false }
        return themeInfos.first { $0.themeId == id }?.isArchived ?? false
    }

    private func openTheme(_ id: Int) {
        if let info = themeInfos.first(where: { $0.themeId == id }) {
            openThemeInfo = info
            let payload: [String: Any] = ["instrumentId": instrumentId, "themeId": id, "action": "open_theme_from_mentions"]
            if let data = try? JSONSerialization.data(withJSONObject: payload), let log = String(data: data, encoding: .utf8) {
                LoggingService.shared.log(log, logger: .ui)
            }
        }
    }

    private func logOpen() {
        let payload: [String: Any] = ["instrumentId": instrumentId, "defaultTab": tabKey(selectedTab), "themeFilter": selectedThemeId == nil ? "all" : String(selectedThemeId!)]
        if let data = try? JSONSerialization.data(withJSONObject: payload), let log = String(data: data, encoding: .utf8) {
            LoggingService.shared.log(log, logger: .ui)
        }
    }

    private func logTab() {
        let payload: [String: Any] = ["instrumentId": instrumentId, "tab": tabKey(selectedTab)]
        if let data = try? JSONSerialization.data(withJSONObject: payload), let log = String(data: data, encoding: .utf8) {
            LoggingService.shared.log(log, logger: .ui)
        }
    }

    private func deleteNote(_ note: InstrumentNote) {
        let alert = NSAlert()
        alert.messageText = "Delete this note?"
        alert.informativeText = "This action cannot be undone."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            if dbManager.deleteInstrumentUpdate(id: note.id, actor: NSFullUserName()) {
                loadGeneralNotes()
                statusFeedback = NoteStatus(title: "Note Deleted", message: "The note for \(instrumentName) has been removed.")
            }
        }
    }
}

private struct NoteStatus: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
