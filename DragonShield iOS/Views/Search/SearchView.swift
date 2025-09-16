#if os(iOS)
import SwiftUI

struct SearchView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var searchText: String = ""
    @State private var results = SearchResults()
    @State private var state: SearchState = .idle
    @State private var lastQuery: String = ""
    @State private var searchTask: Task<Void, Never>? = nil

    private let instrumentLimit = 25
    private let themeLimit = 20
    private let themeUpdateLimit = 15
    private let instrumentUpdateLimit = 15

    var body: some View {
        content
            .navigationTitle("Search")
            .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Instruments, themes, notes...")
            .onChange(of: searchText) { newValue in
                scheduleSearch(for: newValue)
            }
            .onSubmit(of: .search) {
                scheduleSearch(for: searchText)
            }
            .onDisappear {
                searchTask?.cancel()
                searchTask = nil
            }
    }

    @ViewBuilder
    private var content: some View {
        List {
            if dbManager.db == nil {
                importRequiredSection
            } else {
                switch state {
                case .idle:
                    idleState
                case .searching:
                    searchingState
                case .results:
                    resultsState
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var importRequiredSection: some View {
        Section {
            if #available(iOS 17.0, *) {
                ContentUnavailableView(
                    "Import a snapshot to search",
                    systemImage: "tray.and.arrow.down",
                    description: Text("Use Settings to import a DragonShield SQLite snapshot.")
                )
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)
                    Text("Import a snapshot to search")
                        .font(.headline)
                    Text("Use Settings to import a DragonShield SQLite snapshot.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 24)
            }
        }
    }

    private var idleState: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Search across your snapshot")
                    .font(.headline)
                Text("Find instruments, portfolio themes, and research notes without leaving this tab.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Divider()
                Label("Instrument names, tickers, or ISINs", systemImage: "magnifyingglass")
                Label("Portfolio themes by name or code", systemImage: "square.grid.2x2")
                Label("Theme & instrument updates (notes)", systemImage: "doc.text.magnifyingglass")
            }
            .padding(.vertical, 4)
        }
    }

    private var searchingState: some View {
        let trimmed = searchText.trimmedForDisplay()
        return Section {
            HStack(spacing: 12) {
                ProgressView()
                VStack(alignment: .leading) {
                    Text("Searching...")
                    if !trimmed.isEmpty {
                        Text("Query \(trimmed)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var resultsState: some View {
        Group {
            if results.isEmpty {
                Section {
                    Text("No matches for \"\(lastQuery)\"")
                        .font(.headline)
                    Text("Refine the query or try another keyword.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Section {
                    Text("Results for \"\(lastQuery)\"")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if !results.instruments.isEmpty {
                    Section {
                        ForEach(results.instruments, id: \.id) { row in
                            NavigationLink(destination: InstrumentDetailView(instrumentId: row.id)) {
                                instrumentRow(row)
                            }
                        }
                    } header: {
                        Label("Instruments", systemImage: "chart.bar.doc.horizontal")
                    } footer: {
                        if results.instruments.count >= instrumentLimit {
                            Text("Showing first \(instrumentLimit) matches. Narrow your search to see more.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                if !results.themes.isEmpty {
                    Section {
                        ForEach(results.themes, id: \.id) { theme in
                            NavigationLink(destination: ThemeDetailIOSView(themeId: theme.id)) {
                                themeRow(theme)
                            }
                        }
                    } header: {
                        Label("Themes", systemImage: "square.grid.2x2")
                    } footer: {
                        if results.themes.count >= themeLimit {
                            Text("Showing first \(themeLimit) matches. Try adding more keywords.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                if !results.themeUpdates.isEmpty {
                    Section {
                        ForEach(results.themeUpdates, id: \.id) { hit in
                            NavigationLink(destination: ThemeUpdateDetailView(hit: hit)) {
                                themeUpdateRow(hit)
                            }
                        }
                    } header: {
                        Label("Theme Updates", systemImage: "doc.text")
                    } footer: {
                        if results.themeUpdates.count >= themeUpdateLimit {
                            Text("Showing first \(themeUpdateLimit) notes. Filter by specific keywords to drill down.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                if !results.instrumentUpdates.isEmpty {
                    Section {
                        ForEach(results.instrumentUpdates, id: \.id) { hit in
                            NavigationLink(destination: InstrumentUpdateDetailView(hit: hit)) {
                                instrumentUpdateRow(hit)
                            }
                        }
                    } header: {
                        Label("Instrument Updates", systemImage: "doc.plaintext")
                    } footer: {
                        if results.instrumentUpdates.count >= instrumentUpdateLimit {
                            Text("Showing first \(instrumentUpdateLimit) notes. Add instrument or theme keywords to narrow it down.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func instrumentRow(_ row: DatabaseManager.InstrumentRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(row.name)
                .font(.headline)
            HStack(spacing: 8) {
                if let ticker = row.tickerSymbol, !ticker.isEmpty {
                    badge(ticker)
                }
                if let isin = row.isin, !isin.isEmpty {
                    badge(isin)
                }
                if let valor = row.valorNr, !valor.isEmpty {
                    badge(valor)
                }
            }
            .font(.caption)
            Text("Currency: \(row.currency)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func themeRow(_ theme: PortfolioTheme) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(theme.name)
                    .font(.headline)
                if theme.archivedAt != nil {
                    Text("Archived")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            HStack(spacing: 12) {
                badge(theme.code)
                if theme.instrumentCount > 0 {
                    Text("\(theme.instrumentCount) instruments")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let budget = theme.theoreticalBudgetChf {
                    Text("Budget \(ValueFormatting.large(budget))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func themeUpdateRow(_ hit: DatabaseManager.ThemeUpdateSearchHit) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(hit.themeName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                badge(hit.themeCode)
                if hit.update.pinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .accessibilityLabel("Pinned")
                }
            }
            Text(hit.update.title)
                .font(.headline)
            Text(snippet(from: hit.update.bodyMarkdown))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
            HStack(spacing: 12) {
                if let typeName = hit.update.typeDisplayName ?? (hit.update.typeCode.isEmpty ? nil : hit.update.typeCode) {
                    badge(typeName)
                }
                Text(hit.update.author)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatTimestamp(hit.update.updatedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func instrumentUpdateRow(_ hit: DatabaseManager.InstrumentUpdateSearchHit) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(hit.instrumentName)
                    .font(.headline)
                if let ticker = hit.instrumentTicker, !ticker.isEmpty {
                    badge(ticker)
                }
                if hit.update.pinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .accessibilityLabel("Pinned")
                }
            }
            Text(hit.themeName)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(snippet(from: hit.update.bodyMarkdown))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
            HStack(spacing: 12) {
                if let typeName = hit.update.typeDisplayName ?? (hit.update.typeCode.isEmpty ? nil : hit.update.typeCode) {
                    badge(typeName)
                }
                Text(hit.update.author)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatTimestamp(hit.update.updatedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.1))
            .clipShape(Capsule())
    }

    private func snippet(from text: String, maxLength: Int = 160) -> String {
        let clean = text.replacingOccurrences(of: "\n", with: " ")
        guard clean.count > maxLength else { return clean }
        let idx = clean.index(clean.startIndex, offsetBy: maxLength)
        return clean[..<idx].trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private func scheduleSearch(for raw: String) {
        searchTask?.cancel()
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard dbManager.db != nil else {
            state = .idle
            results = SearchResults()
            lastQuery = ""
            searchTask = nil
            return
        }
        guard !trimmed.isEmpty else {
            state = .idle
            results = SearchResults()
            lastQuery = ""
            searchTask = nil
            return
        }
        state = .searching
        let query = trimmed
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            if Task.isCancelled { return }
            let payload = await Task.detached(priority: .userInitiated) { [dbManager] () -> SearchResults in
                let instruments = dbManager.searchInstrumentsIOS(query: query, limit: instrumentLimit)
                let themes = dbManager.searchThemesIOS(query: query, limit: themeLimit)
                let themeNotes = dbManager.searchThemeUpdatesIOS(query: query, limit: themeUpdateLimit)
                let instrumentNotes = dbManager.searchInstrumentUpdatesIOS(query: query, limit: instrumentUpdateLimit)
                return SearchResults(
                    instruments: instruments,
                    themes: themes,
                    themeUpdates: themeNotes,
                    instrumentUpdates: instrumentNotes
                )
            }.value
            if Task.isCancelled { return }
            await MainActor.run {
                results = payload
                state = .results
                lastQuery = query
                searchTask = nil
            }
        }
    }

    private func formatTimestamp(_ value: String) -> String {
        if let date = Self.parseISODate(value) {
            return Self.displayFormatter.string(from: date)
        }
        if let date = DateFormatter.iso8601DateOnly.date(from: value) {
            return Self.shortDateFormatter.string(from: date)
        }
        return value
    }

    fileprivate static let isoParsers: [ISO8601DateFormatter] = {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let basic = ISO8601DateFormatter()
        basic.formatOptions = [.withInternetDateTime]
        return [withFraction, basic]
    }()

    fileprivate static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    fileprivate static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    fileprivate static func parseISODate(_ value: String) -> Date? {
        for parser in isoParsers {
            if let date = parser.date(from: value) { return date }
        }
        return nil
    }
}

private enum SearchState {
    case idle
    case searching
    case results
}

private struct SearchResults {
    var instruments: [DatabaseManager.InstrumentRow] = []
    var themes: [PortfolioTheme] = []
    var themeUpdates: [DatabaseManager.ThemeUpdateSearchHit] = []
    var instrumentUpdates: [DatabaseManager.InstrumentUpdateSearchHit] = []

    var isEmpty: Bool {
        instruments.isEmpty && themes.isEmpty && themeUpdates.isEmpty && instrumentUpdates.isEmpty
    }
}

private extension String {
    func trimmedForDisplay() -> String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ThemeUpdateDetailView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let hit: DatabaseManager.ThemeUpdateSearchHit

    var body: some View {
        Form {
            Section(header: Text("Theme")) {
                HStack { Text("Name"); Spacer(); Text(hit.themeName).foregroundColor(.secondary) }
                HStack { Text("Code"); Spacer(); Text(hit.themeCode).foregroundColor(.secondary) }
                NavigationLink("Open theme overview") {
                    ThemeDetailIOSView(themeId: hit.themeId)
                }
            }
            Section(header: Text("Metadata")) {
                if let typeName = hit.update.typeDisplayName ?? (hit.update.typeCode.isEmpty ? nil : hit.update.typeCode) {
                    HStack { Text("Category"); Spacer(); Text(typeName).foregroundColor(.secondary) }
                }
                HStack { Text("Author"); Spacer(); Text(hit.update.author).foregroundColor(.secondary) }
                HStack { Text("Updated"); Spacer(); Text(SearchView.displayFormatter.string(from: parseDate(hit.update.updatedAt) ?? Date())).foregroundColor(.secondary) }
                if let created = parseDate(hit.update.createdAt) {
                    HStack { Text("Created"); Spacer(); Text(SearchView.displayFormatter.string(from: created)).foregroundColor(.secondary) }
                }
                if let positions = hit.update.positionsAsOf {
                    HStack { Text("Positions as of"); Spacer(); Text(formatDateOnly(positions)).foregroundColor(.secondary) }
                }
                if let total = hit.update.totalValueChf {
                    HStack {
                        Text("Total value")
                        Spacer()
                        Text(formatAmount(total))
                            .foregroundColor(.secondary)
                            .privacyBlur()
                    }
                }
                if hit.update.pinned {
                    Label("Pinned update", systemImage: "pin.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            Section(header: Text("Content")) {
                Text(attributedBody(hit.update.bodyMarkdown))
                    .textSelection(.enabled)
            }
        }
        .navigationTitle(hit.update.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func parseDate(_ string: String) -> Date? {
        if let date = SearchView.parseISODate(string) { return date }
        if let date = DateFormatter.iso8601DateOnly.date(from: string) { return date }
        return nil
    }

    private func formatAmount(_ value: Double) -> String {
        if abs(value) >= 1_000 {
            return ValueFormatting.large(value)
        }
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = dbManager.baseCurrency
        nf.maximumFractionDigits = 2
        nf.minimumFractionDigits = 2
        return nf.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private func formatDateOnly(_ string: String) -> String {
        if let date = DateFormatter.iso8601DateOnly.date(from: string) {
            return SearchView.shortDateFormatter.string(from: date)
        }
        if let date = SearchView.parseISODate(string) {
            return SearchView.shortDateFormatter.string(from: date)
        }
        return string
    }

    private func attributedBody(_ markdown: String) -> AttributedString {
        if let value = try? AttributedString(markdown: markdown) { return value }
        return AttributedString(markdown.replacingOccurrences(of: "\n\n", with: "\n"))
    }
}

struct InstrumentUpdateDetailView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let hit: DatabaseManager.InstrumentUpdateSearchHit

    var body: some View {
        Form {
            Section(header: Text("Instrument")) {
                HStack { Text("Name"); Spacer(); Text(hit.instrumentName).foregroundColor(.secondary) }
                if let ticker = hit.instrumentTicker, !ticker.isEmpty {
                    HStack { Text("Ticker"); Spacer(); Text(ticker).foregroundColor(.secondary) }
                }
                NavigationLink("Open instrument details") {
                    InstrumentDetailView(instrumentId: hit.instrumentId)
                }
            }
            Section(header: Text("Theme")) {
                HStack { Text("Name"); Spacer(); Text(hit.themeName).foregroundColor(.secondary) }
                HStack { Text("Code"); Spacer(); Text(hit.themeCode).foregroundColor(.secondary) }
                NavigationLink("Open theme overview") {
                    ThemeDetailIOSView(themeId: hit.themeId)
                }
            }
            Section(header: Text("Metadata")) {
                if let typeName = hit.update.typeDisplayName ?? (hit.update.typeCode.isEmpty ? nil : hit.update.typeCode) {
                    HStack { Text("Category"); Spacer(); Text(typeName).foregroundColor(.secondary) }
                }
                HStack { Text("Author"); Spacer(); Text(hit.update.author).foregroundColor(.secondary) }
                HStack { Text("Updated"); Spacer(); Text(SearchView.displayFormatter.string(from: parseDate(hit.update.updatedAt) ?? Date())).foregroundColor(.secondary) }
                if let created = parseDate(hit.update.createdAt) {
                    HStack { Text("Created"); Spacer(); Text(SearchView.displayFormatter.string(from: created)).foregroundColor(.secondary) }
                }
                if let positions = hit.update.positionsAsOf {
                    HStack { Text("Positions as of"); Spacer(); Text(formatDateOnly(positions)).foregroundColor(.secondary) }
                }
                if let value = hit.update.valueChf {
                    HStack {
                        Text("Value (") + Text(dbManager.baseCurrency).bold() + Text(")")
                        Spacer()
                        Text(formatAmount(value))
                            .foregroundColor(.secondary)
                            .privacyBlur()
                    }
                }
                if let actual = hit.update.actualPercent {
                    HStack {
                        Text("Allocation")
                        Spacer()
                        Text(String(format: "%.2f%%", actual))
                            .foregroundColor(.secondary)
                    }
                }
                if hit.update.pinned {
                    Label("Pinned update", systemImage: "pin.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            Section(header: Text("Content")) {
                Text(attributedBody(hit.update.bodyMarkdown))
                    .textSelection(.enabled)
            }
        }
        .navigationTitle(hit.update.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func parseDate(_ string: String) -> Date? {
        if let date = SearchView.parseISODate(string) { return date }
        if let date = DateFormatter.iso8601DateOnly.date(from: string) { return date }
        return nil
    }

    private func formatDateOnly(_ string: String) -> String {
        if let date = DateFormatter.iso8601DateOnly.date(from: string) {
            return SearchView.shortDateFormatter.string(from: date)
        }
        if let date = SearchView.parseISODate(string) {
            return SearchView.shortDateFormatter.string(from: date)
        }
        return string
    }

    private func formatAmount(_ value: Double) -> String {
        if abs(value) >= 1_000 {
            return ValueFormatting.large(value)
        }
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = dbManager.baseCurrency
        nf.maximumFractionDigits = 2
        nf.minimumFractionDigits = 2
        return nf.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private func attributedBody(_ markdown: String) -> AttributedString {
        if let value = try? AttributedString(markdown: markdown) { return value }
        return AttributedString(markdown.replacingOccurrences(of: "\n\n", with: "\n"))
    }
}

#endif
