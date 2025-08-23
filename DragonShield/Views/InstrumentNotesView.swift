import SwiftUI

struct InstrumentNotesView: View {
    enum Tab { case updates, mentions }
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) private var dismiss

    let instrumentId: Int
    let instrumentName: String
    let instrumentCode: String
    let initialTab: Tab
    let initialThemeId: Int?

    @State private var selectedTab: Tab
    @State private var themeFilter: Int?
    @State private var themes: [(id: Int, name: String, archived: Bool)] = []
    @State private var mentions: [MentionItem] = []
    @State private var search = ""
    @State private var openTheme: MentionItem?

    struct MentionItem: Identifiable {
        let id: Int
        let themeId: Int
        let themeName: String
        let isArchived: Bool
        let update: PortfolioThemeUpdate
    }

    init(instrumentId: Int, instrumentName: String, instrumentCode: String, initialTab: Tab = .updates, initialThemeId: Int? = nil) {
        self.instrumentId = instrumentId
        self.instrumentName = instrumentName
        self.instrumentCode = instrumentCode
        self.initialTab = initialTab
        self.initialThemeId = initialThemeId
        _selectedTab = State(initialValue: initialTab)
        _themeFilter = State(initialValue: initialThemeId)
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Instrument Notes — \(instrumentName) (Code: \(instrumentCode))")
                .font(.headline)
                .padding(16)
            Picker("Theme", selection: $themeFilter) {
                Text("All themes").tag(Int?.none)
                ForEach(themes, id: \..id) { info in
                    Text(info.name).tag(Int?(info.id))
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 16)
            Picker("Tab", selection: $selectedTab) {
                Text("Instrument Updates").tag(Tab.updates)
                Text("Theme Mentions").tag(Tab.mentions)
            }
            .pickerStyle(.segmented)
            .padding(16)
            Divider()
            switch selectedTab {
            case .updates:
                updatesTab
            case .mentions:
                mentionsTab
            }
            Divider()
            HStack { Spacer(); Button("Close") { dismiss() } }
                .padding(16)
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear { loadThemes(); loadMentions() }
        .onChange(of: themeFilter) { _ in loadMentions() }
        .onChange(of: selectedTab) { _ in loadMentions() }
        .sheet(item: $openTheme) { item in
            let query = instrumentCode.isEmpty ? instrumentName : instrumentCode.uppercased()
            PortfolioThemeDetailView(themeId: item.themeId, origin: "instrument_mentions", initialTab: .updates, initialSearch: query, searchHint: "Showing theme notes mentioning \(query)")
                .environmentObject(dbManager)
        }
    }

    private var updatesTab: some View {
        Group {
            if let tid = themeFilter, let theme = themes.first(where: { $0.id == tid }) {
                InstrumentUpdatesView(themeId: theme.id, instrumentId: instrumentId, instrumentName: instrumentName, themeName: theme.name, onClose: {})
                    .environmentObject(dbManager)
            } else {
                Text("Select a theme to view updates.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var mentionsTab: some View {
        VStack(alignment: .leading) {
            TextField("Search mentions", text: $search)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16)
            List(filteredMentions) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(DateFormatting.userFriendly(item.update.createdAt)) • Theme: \(item.themeName) • Type: \(item.update.type.rawValue)")
                        if item.isArchived {
                            Text("Archived").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Text("Title: \(item.update.title)").fontWeight(.semibold)
                    Text(MarkdownRenderer.attributedString(from: item.update.bodyMarkdown)).lineLimit(3)
                    HStack { Spacer(); Button("Open in Theme") { openTheme = item } }
                        .font(.caption)
                }
            }
        }
    }

    private var filteredMentions: [MentionItem] {
        if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return mentions }
        return mentions.filter { m in
            let text = m.update.title + " " + m.update.bodyMarkdown
            return text.localizedCaseInsensitiveContains(search)
        }
    }

    private func loadThemes() {
        let rows = dbManager.listThemesForInstrumentWithUpdateCounts(instrumentId: instrumentId, instrumentCode: instrumentCode, instrumentName: instrumentName)
        themes = rows.map { (id: $0.themeId, name: $0.themeName, archived: $0.isArchived) }
    }

    private func loadMentions() {
        mentions = dbManager.listThemeMentionsForInstrument(instrumentId: instrumentId, instrumentCode: instrumentCode, instrumentName: instrumentName, themeId: themeFilter)
            .map { (upd, tid, name, archived) in
                MentionItem(id: upd.id, themeId: tid, themeName: name, isArchived: archived, update: upd)
            }
    }
}
