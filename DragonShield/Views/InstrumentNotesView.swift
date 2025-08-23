// DragonShield/Views/InstrumentNotesView.swift
// Modal consolidating instrument updates and theme mentions

import SwiftUI

struct InstrumentNotesView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let instrumentId: Int
    let instrumentName: String
    let instrumentCode: String
    let initialTab: NotesTab
    let initialThemeId: Int?

    enum NotesTab: Hashable {
        case updates
        case mentions
    }

    struct ThemeInfo: Identifiable {
        let id: Int
        let name: String
        let isArchived: Bool
    }

    struct MentionItem: Identifiable {
        let id: Int
        let themeId: Int
        let themeName: String
        let isArchived: Bool
        let update: PortfolioThemeUpdate
    }

    @State private var themes: [ThemeInfo] = []
    @State private var selectedTab: NotesTab
    @State private var themeFilter: Int?
    @State private var mentions: [MentionItem] = []
    @State private var searchText: String = ""
    @State private var openThemeId: Int?

    @Environment(\.dismiss) private var dismiss

    init(instrumentId: Int, instrumentName: String, instrumentCode: String, initialTab: NotesTab = .updates, initialThemeId: Int? = nil) {
        self.instrumentId = instrumentId
        self.instrumentName = instrumentName
        self.instrumentCode = instrumentCode
        self.initialTab = initialTab
        self.initialThemeId = initialThemeId
        _selectedTab = State(initialValue: initialTab)
        _themeFilter = State(initialValue: initialThemeId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Instrument Notes — \(instrumentName) (Code: \(instrumentCode))")
                    .font(.headline)
                Spacer()
            }
            .padding(16)

            HStack {
                Text("Theme filter:")
                Picker("Theme", selection: $themeFilter) {
                    Text("All themes").tag(nil as Int?)
                    ForEach(themes) { t in
                        Text(t.name).tag(Optional(t.id))
                    }
                }
                .onChange(of: themeFilter) { _ in
                    loadMentions()
                }
                Spacer()
            }
            .padding(.horizontal, 16)

            TabView(selection: $selectedTab) {
                updatesTab.tag(NotesTab.updates)
                mentionsTab.tag(NotesTab.mentions)
            }
            .padding(.top, 8)

            Divider()
            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .padding(8)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            loadThemes()
            loadMentions()
            logOpen()
        }
        .sheet(item: $openThemeId) { tid in
            let query = instrumentCode.isEmpty ? instrumentName : instrumentCode.uppercased()
            let hint = instrumentCode.isEmpty ? "Showing theme notes mentioning \(instrumentName)" : "Showing theme notes mentioning \(instrumentCode.uppercased()) (\(instrumentName))"
            PortfolioThemeDetailView(themeId: tid, origin: "instrument_notes", initialTab: .updates, initialSearch: query, searchHint: hint)
                .environmentObject(dbManager)
        }
    }

    private var updatesTab: some View {
        VStack(alignment: .leading) {
            if let themeId = themeFilter, let theme = themes.first(where: { $0.id == themeId }) {
                InstrumentUpdatesView(themeId: themeId, instrumentId: instrumentId, instrumentName: instrumentName, themeName: theme.name, onClose: {})
                    .environmentObject(dbManager)
            } else {
                Text("Select a theme to view instrument updates.")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }

    private var mentionsTab: some View {
        VStack(alignment: .leading) {
            TextField("Search mentions", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16)
                .onChange(of: searchText) { _ in loadMentions() }
            if mentionsFiltered.isEmpty {
                Text(emptyMentionsMessage)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List(mentionsFiltered) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(DateFormatting.userFriendly(item.update.createdAt)) • Theme: \(item.themeName) • Type: \(item.update.type.rawValue)")
                                .font(.subheadline)
                            if item.isArchived {
                                Text("Archived")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Open in Theme") { openThemeId = item.themeId; logOpenTheme(item.themeId) }
                                .buttonStyle(.borderless)
                        }
                        Text("Title: \(item.update.title)").fontWeight(.semibold)
                        Text(MarkdownRenderer.attributedString(from: item.update.bodyMarkdown))
                            .lineLimit(3)
                    }
                }
            }
        }
    }

    private var mentionsFiltered: [MentionItem] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return mentions
        }
        return mentions.filter { item in
            let text = item.update.title + " " + item.update.bodyMarkdown
            return text.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var emptyMentionsMessage: String {
        if let themeId = themeFilter, let theme = themes.first(where: { $0.id == themeId }) {
            return "No theme notes in \(theme.name) mention \(instrumentCode)."
        }
        return "No theme notes mention \(instrumentCode)."
    }

    private func loadThemes() {
        let rows = dbManager.listThemesForInstrumentWithUpdateCounts(instrumentId: instrumentId, instrumentCode: instrumentCode, instrumentName: instrumentName)
        themes = rows.map { ThemeInfo(id: $0.themeId, name: $0.themeName, isArchived: $0.isArchived) }
    }

    private func loadMentions() {
        let themeIds: [Int]
        if let t = themeFilter {
            themeIds = [t]
        } else {
            themeIds = themes.map { $0.id }
        }
        var items: [MentionItem] = []
        for tid in themeIds {
            let updates = dbManager.listThemeUpdates(themeId: tid)
            if let theme = themes.first(where: { $0.id == tid }) {
                for upd in updates {
                    if InstrumentNotesView.mentionMatches(update: upd, code: instrumentCode, name: instrumentName) {
                        items.append(MentionItem(id: upd.id, themeId: tid, themeName: theme.name, isArchived: theme.isArchived, update: upd))
                    }
                }
            }
        }
        mentions = items.sorted { $0.update.createdAt > $1.update.createdAt }
    }

    private func logOpen() {
        let filter = themeFilter == nil ? "all" : String(themeFilter!)
        let payload: [String: Any] = ["instrumentId": instrumentId, "defaultTab": selectedTab == .updates ? "updates" : "mentions", "themeFilter": filter]
        if let data = try? JSONSerialization.data(withJSONObject: payload), let log = String(data: data, encoding: .utf8) {
            LoggingService.shared.log(log, logger: .ui)
        }
    }

    private func logOpenTheme(_ themeId: Int) {
        let payload: [String: Any] = ["instrumentId": instrumentId, "themeId": themeId, "action": "open_theme_from_mentions"]
        if let data = try? JSONSerialization.data(withJSONObject: payload), let log = String(data: data, encoding: .utf8) {
            LoggingService.shared.log(log, logger: .ui)
        }
    }

    static func mentionMatches(update: PortfolioThemeUpdate, code: String, name: String) -> Bool {
        let combined = update.title + " " + update.bodyMarkdown
        let norm = normalize(combined)
        if code.count >= 3 {
            let token = " " + code.lowercased() + " "
            if norm.contains(token) { return true }
        }
        let lowerName = name.lowercased()
        if norm.contains(lowerName) { return true }
        let tokens = lowerName.split { !$0.isLetter && !$0.isNumber }
        if !tokens.isEmpty && tokens.allSatisfy({ norm.contains(" \($0) ") }) {
            return true
        }
        return false
    }

    private static func normalize(_ text: String) -> String {
        let lowered = text.lowercased()
        let mapped = lowered.map { $0.isLetter || $0.isNumber ? String($0) : " " }.joined()
        let collapsed = mapped.split { $0 == " " }.joined(separator: " ")
        return " " + collapsed + " "
    }
}
