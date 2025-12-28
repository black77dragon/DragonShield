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
                .dsHeaderSmall()
                .foregroundColor(DSColor.textPrimary)
                .padding(DSLayout.spaceM)
            Picker("Theme", selection: $selectedThemeId) {
                Text("All themes").tag(nil as Int?)
                ForEach(themeInfos) { info in
                    Text(info.name).tag(info.themeId as Int?)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, DSLayout.spaceM)
            Picker("", selection: $selectedTab) {
                Text("General Notes").tag(Tab.general)
                Text("Portfolio Updates").tag(Tab.updates)
                Text("Theme Mentions").tag(Tab.mentions)
            }
            .pickerStyle(.segmented)
            .padding(DSLayout.spaceM)
            switch selectedTab {
            case .general:
                generalList
            case .updates:
                updatesList
            case .mentions:
                mentionsList
            }
            Divider().overlay(DSColor.border)
            HStack {
                Spacer()
                Button("Close") { onClose() }
                    .buttonStyle(DSButtonStyle(type: .primary))
                    .keyboardShortcut("w", modifiers: .command)
            }
            .padding(DSLayout.spaceM)
        }
        .frame(minWidth: 640, minHeight: 400)
        .background(DSColor.background)
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
                .buttonStyle(DSButtonStyle(type: .primary, size: .small))
                Spacer()
                Toggle("Pinned first", isOn: $generalPinnedFirst)
                    .toggleStyle(.checkbox)
                    .onChange(of: generalPinnedFirst) { _, _ in
                        if selectedTab == .general { loadGeneralNotes() }
                    }
            }
            .padding(.horizontal, DSLayout.spaceM)
            List {
                ForEach(generalNotes, id: \.id) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(DateFormatting.userFriendly(note.createdAt)) • \(note.author) • \(note.typeDisplayName ?? note.typeCode)")
                                .dsCaption()
                                .foregroundColor(DSColor.textSecondary)
                            Spacer()
                            Text(note.pinned ? "★" : "☆")
                                .foregroundColor(note.pinned ? DSColor.accentWarning : DSColor.textSecondary)
                        }
                        Text(note.title)
                            .dsBody()
                            .fontWeight(.semibold)
                            .foregroundColor(DSColor.textPrimary)
                        Text(MarkdownRenderer.attributedString(from: note.bodyMarkdown))
                            .lineLimit(3)
                            .foregroundColor(DSColor.textPrimary)
                        HStack {
                            Spacer()
                            Button("Edit") {
                                editingGeneralNote = note
                            }
                            .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
                            Button("Delete") {
                                deleteNote(note)
                            }
                            .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
                        }
                    }
                }
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
                .buttonStyle(DSButtonStyle(type: .primary, size: .small))
                .disabled(selectedThemeId == nil)
                Spacer()
                Toggle("Pinned first", isOn: $pinnedFirst)
                    .toggleStyle(.checkbox)
            }
            .padding(.horizontal, DSLayout.spaceM)
            List {
                ForEach(updates, id: \.id) { update in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(DateFormatting.userFriendly(update.createdAt)) • \(update.author) • \(update.typeDisplayName ?? update.typeCode)")
                                .dsCaption()
                                .foregroundColor(DSColor.textSecondary)
                            Spacer()
                            Text(update.pinned ? "★" : "☆")
                                .foregroundColor(update.pinned ? DSColor.accentWarning : DSColor.textSecondary)
                        }
                        if selectedThemeId == nil, let themeId = update.themeId {
                            Text("Theme: \(themeName(for: themeId))")
                                .dsCaption()
                                .foregroundColor(DSColor.textSecondary)
                        }
                        HStack {
                            Text(update.title)
                                .dsBody()
                                .fontWeight(.semibold)
                                .foregroundColor(DSColor.textPrimary)
                            if (attachmentCounts[update.id] ?? 0) > 0 { Image(systemName: "paperclip").foregroundColor(DSColor.textSecondary) }
                        }
                        Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown))
                            .lineLimit(3)
                            .foregroundColor(DSColor.textPrimary)
                        HStack {
                            Spacer()
                            Button("Open") {
                                editingThemeUpdate = update
                                showThemeEditor = true
                            }
                            .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
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
                                .dsCaption()
                                .foregroundColor(DSColor.textSecondary)
                            if isThemeArchived(mention.themeId) {
                                Text("Archived").dsCaption().foregroundColor(DSColor.textSecondary)
                            }
                        }
                        Text(mention.title)
                            .dsBody()
                            .fontWeight(.semibold)
                            .foregroundColor(DSColor.textPrimary)
                        Text(MarkdownRenderer.attributedString(from: mention.bodyMarkdown))
                            .lineLimit(3)
                            .foregroundColor(DSColor.textPrimary)
                        HStack {
                            Spacer()
                            Button("Open in Theme") { openTheme(mention.themeId) }
                                .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
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
