import SwiftUI

struct PortfolioThemeOverviewView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    var onMaintenance: () -> Void

    @State private var updates: [PortfolioThemeUpdate] = []
    @State private var extras: [Int: UpdateExtras] = [:]
    @State private var editingUpdate: PortfolioThemeUpdate?
    @State private var readerUpdate: PortfolioThemeUpdate?
    @State private var showEditor = false
    @State private var searchText: String = ""
    @State private var selectedType: PortfolioThemeUpdate.UpdateType? = nil
    @State private var pinnedFirst: Bool = true
    @State private var dateFilter: DateFilter = .last90d
    @State private var kpis: KPIMetrics?
    @State private var searchDebounce: DispatchWorkItem?
    @State private var themeName: String = ""
    @State private var isArchived: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Overview").font(.headline)
                Spacer()
                Button("Maintenance") { onMaintenance() }
            }
            if let k = kpis { kpiRow(k) }
            filterRow
            if updates.isEmpty {
                VStack(spacing: 12) {
                    Text("No updates yet")
                    Button("+ New Update") { showEditor = true }
                        .disabled(isArchived)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Group {
                    Text("Latest Updates").font(.title3)
                    List(updates) { update in
                        VStack(alignment: .leading, spacing: 4) {
                            headerLine(update)
                            titleLine(update)
                            snippetLine(update)
                            actionRow(update)
                        }
                        .contentShape(Rectangle())
                    }
                    .listStyle(.inset)
                }
            }
        }
        .padding(24)
        .onAppear {
            load()
            loadKpis()
        }
        .sheet(isPresented: $showEditor) {
            ThemeUpdateEditorView(themeId: themeId, themeName: themeName, onSave: { _ in showEditor = false; load(); loadKpis() }, onCancel: { showEditor = false })
                .environmentObject(dbManager)
        }
        .sheet(item: $editingUpdate) { upd in
            ThemeUpdateEditorView(themeId: themeId, themeName: themeName, existing: upd, onSave: { _ in editingUpdate = nil; load(); loadKpis() }, onCancel: { editingUpdate = nil })
                .environmentObject(dbManager)
        }
        .sheet(item: $readerUpdate) { upd in
            ThemeUpdateReaderView(update: upd, links: extras[upd.id]?.links ?? [], attachments: extras[upd.id]?.attachments ?? [], onEdit: { editingUpdate = $0 }, onPin: { t in togglePin(t); if let refreshed = dbManager.getThemeUpdate(id: t.id) { readerUpdate = refreshed } }, onDelete: { t in delete(t); readerUpdate = nil })
                .environmentObject(dbManager)
        }
    }

    // MARK: - Subviews

    private func kpiRow(_ k: KPIMetrics) -> some View {
        HStack(spacing: 12) {
            Text("Total Value \(formattedChf(k.totalValue))")
            Text("Instruments \(k.instruments)")
            Text("Last Update \(DateFormatting.userFriendly(k.lastUpdate))")
            Text("Research Σ \(k.researchSum, format: .number)")
            Text("User Σ \(k.userSum, format: .number)")
            Text("Excluded \(k.excluded)")
            Spacer()
        }
        .font(.subheadline)
    }

    private var filterRow: some View {
        HStack {
            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: searchText) { _, _ in
                    searchDebounce?.cancel()
                    let task = DispatchWorkItem { load() }
                    searchDebounce = task
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: task)
                }
            Picker("Type", selection: $selectedType) {
                Text("All").tag(nil as PortfolioThemeUpdate.UpdateType?)
                ForEach(PortfolioThemeUpdate.UpdateType.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(Optional(t))
                }
            }
            .onChange(of: selectedType) { _, _ in load() }
            Toggle("Pinned first", isOn: $pinnedFirst)
                .toggleStyle(.checkbox)
                .onChange(of: pinnedFirst) { _, _ in load() }
            Picker("Date", selection: $dateFilter) {
                ForEach(DateFilter.allCases) { f in
                    Text(f.label).tag(f)
                }
            }
            .onChange(of: dateFilter) { _, _ in load() }
        }
    }

    private func headerLine(_ update: PortfolioThemeUpdate) -> some View {
        let extra = extras[update.id]
        var parts: [String] = [
            DateFormatting.userFriendly(update.createdAt),
            update.author,
            update.type.rawValue
        ]
        if update.pinned { parts.append("★Pinned") }
        if FeatureFlags.portfolioLinksEnabled(), let count = extra?.links.count, count > 0 {
            parts.append("Links \(count)")
        }
        if FeatureFlags.portfolioAttachmentsEnabled(), let count = extra?.attachments.count, count > 0 {
            parts.append("Files \(count)")
        }
        return Text(parts.joined(separator: " • "))
            .font(.subheadline)
    }

    private func titleLine(_ update: PortfolioThemeUpdate) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text("Title: ").fontWeight(.semibold)
            Group {
                if update.title.isEmpty {
                    Text("(No title)").italic().foregroundColor(.secondary)
                } else {
                    Text(update.title)
                }
            }
            .lineLimit(1)
            .help(PortfolioThemeOverviewView.titleOrPlaceholder(update.title))
        }
    }

    private func snippetLine(_ update: PortfolioThemeUpdate) -> some View {
        let snippet = String(update.bodyMarkdown.replacingOccurrences(of: "\n", with: " ").prefix(80))
        return HStack(alignment: .top, spacing: 0) {
            Text("Snippet: ").fontWeight(.semibold)
            Text(snippet)
                .lineLimit(1)
                .foregroundColor(.secondary)
        }
    }

    private func actionRow(_ update: PortfolioThemeUpdate) -> some View {
        HStack(spacing: 8) {
            Button("View") { readerUpdate = update }
                .buttonStyle(.link)
                .keyboardShortcut(.return)
            Button("Edit") { editingUpdate = update }
                .buttonStyle(.link)
                .disabled(isArchived)
            Button(update.pinned ? "Unpin" : "Pin") { togglePin(update) }
                .buttonStyle(.link)
                .disabled(isArchived)
            Button("Delete", role: .destructive) { delete(update) }
                .buttonStyle(.link)
                .disabled(isArchived)
        }
    }

    // MARK: - Data

    private func load() {
        let query = searchText.isEmpty ? nil : searchText
        var list = dbManager.listThemeUpdates(themeId: themeId, view: .active, type: selectedType, searchQuery: query, pinnedFirst: pinnedFirst)
        if dateFilter != .all {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let tz = TimeZone(identifier: dbManager.defaultTimeZone) ?? .current
            list = list.filter { upd in
                if let date = formatter.date(from: upd.createdAt) {
                    return dateFilter.contains(date, timeZone: tz)
                }
                return false
            }
        }
        updates = list
        var map: [Int: UpdateExtras] = [:]
        let linkRepo = ThemeUpdateLinkRepository(dbManager: dbManager)
        let attRepo = ThemeUpdateRepository(dbManager: dbManager)
        for upd in list {
            let links = linkRepo.listLinks(updateId: upd.id)
            let atts = attRepo.listAttachments(updateId: upd.id)
            map[upd.id] = UpdateExtras(links: links, attachments: atts)
        }
        extras = map
    }

    private func loadKpis() {
        if let theme = dbManager.getPortfolioTheme(id: themeId) {
            themeName = theme.name
            isArchived = theme.archivedAt != nil
            let assets = dbManager.listThemeAssets(themeId: themeId)
            let research = assets.reduce(0) { $0 + $1.researchTargetPct }
            let user = assets.reduce(0) { $0 + $1.userTargetPct }
            let valuation = PortfolioValuationService(dbManager: dbManager, fxService: FXConversionService(dbManager: dbManager)).snapshot(themeId: themeId)
            let last = dbManager.listThemeUpdates(themeId: themeId, view: .active, type: nil, searchQuery: nil, pinnedFirst: false).first?.createdAt
            kpis = KPIMetrics(totalValue: valuation.totalValueBase, instruments: theme.instrumentCount, lastUpdate: last, researchSum: research, userSum: user, excluded: valuation.excludedFxCount)
        }
    }

    private func togglePin(_ update: PortfolioThemeUpdate) {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = dbManager.updateThemeUpdate(id: update.id, title: nil, bodyMarkdown: nil, type: nil, pinned: !update.pinned, actor: NSFullUserName(), expectedUpdatedAt: update.updatedAt)
            DispatchQueue.main.async { load() }
        }
    }

    private func delete(_ update: PortfolioThemeUpdate) {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = dbManager.softDeleteThemeUpdate(id: update.id, actor: NSFullUserName())
            DispatchQueue.main.async { load(); loadKpis() }
        }
    }

    private func formattedChf(_ value: Double) -> String {
        value.formatted(.currency(code: dbManager.baseCurrency).precision(.fractionLength(2)))
    }

    // MARK: - Types

    struct KPIMetrics {
        let totalValue: Double
        let instruments: Int
        let lastUpdate: String?
        let researchSum: Double
        let userSum: Double
        let excluded: Int
    }

    struct UpdateExtras {
        let links: [Link]
        let attachments: [Attachment]
    }

    enum DateFilter: String, CaseIterable, Identifiable {
        case last7d
        case last30d
        case last90d
        case all
        var id: String { rawValue }
        var label: String {
            switch self {
            case .last7d: return "Last 7d"
            case .last30d: return "Last 30d"
            case .last90d: return "Last 90d"
            case .all: return "All"
            }
        }
        func contains(_ date: Date, timeZone: TimeZone) -> Bool {
            switch self {
            case .all:
                return true
            case .last7d, .last30d, .last90d:
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = timeZone
                let now = Date()
                let startOfToday = calendar.startOfDay(for: now)
                let days: Int
                switch self {
                case .last7d: days = 7
                case .last30d: days = 30
                case .last90d: days = 90
                case .all: days = 0
                }
                let start = calendar.date(byAdding: .day, value: -(days - 1), to: startOfToday)!
                let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: startOfToday)!
                return date >= start && date <= end
            }
        }
    }
}

extension PortfolioThemeOverviewView {
    static func titleOrPlaceholder(_ title: String) -> String {
        title.isEmpty ? "(No title)" : title
    }
}
