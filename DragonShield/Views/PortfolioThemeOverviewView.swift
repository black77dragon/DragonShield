import SwiftUI
import AppKit

struct PortfolioThemeOverviewView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    var onMaintenance: () -> Void

    @State private var updates: [PortfolioThemeUpdate] = []
    @State private var editingUpdate: PortfolioThemeUpdate?
    @State private var showEditor = false
    @State private var searchText: String = ""
    @State private var selectedType: PortfolioThemeUpdate.UpdateType? = nil
    @State private var pinnedFirst: Bool = true
    @State private var dateFilter: DateFilter = .last90d
    @State private var kpis: KPIMetrics?
    @State private var searchDebounce: DispatchWorkItem?
    @State private var themeName: String = ""
    @State private var isArchived: Bool = false
    @State private var expandedId: Int? = nil
    @State private var linkMap: [Int: [Link]] = [:]
    @State private var attachmentMap: [Int: [Attachment]] = [:]

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
                List(updates) { update in
                    updateRow(update)
                        .tag(update.id)
                }
                .listStyle(.inset)
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

    @ViewBuilder
    private func updateRow(_ update: PortfolioThemeUpdate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                HStack(spacing: 4) {
                    Text("\(DateFormatting.userFriendly(update.createdAt)) • \(update.author) • \(update.type.rawValue)")
                        .font(.subheadline)
                    if update.pinned { Image(systemName: "star.fill") }
                }
                Spacer()
                HStack(spacing: 12) {
                    Button(expandedId == update.id ? "View ▴" : "View ▾") { toggleExpand(update.id) }
                    Button("Edit") { editingUpdate = update }
                        .disabled(isArchived)
                    Button(update.pinned ? "Unpin" : "Pin") { togglePin(update) }
                        .disabled(isArchived)
                    Button("Delete", role: .destructive) { delete(update) }
                        .disabled(isArchived)
                }
                .buttonStyle(.borderless)
                .foregroundColor(.blue)
            }
            Text(update.title).fontWeight(.bold)
            Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown))
                .lineLimit(1)
            indicatorLine(update)
            if expandedId == update.id {
                Divider()
                Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown))
                if FeatureFlags.portfolioLinksEnabled(), let links = linkMap[update.id], !links.isEmpty {
                    Divider()
                    Text("Links").font(.subheadline)
                    ForEach(links, id: \.id) { link in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(displayTitle(link))
                                Text(link.rawURL).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Open") { openLink(link) }
                            Button("Copy") { copyLink(link) }
                        }
                    }
                }
                if FeatureFlags.portfolioAttachmentsEnabled(), let files = attachmentMap[update.id], !files.isEmpty {
                    Divider()
                    Text("Files").font(.subheadline)
                    ForEach(files, id: \.id) { att in
                        HStack {
                            Text(att.originalFilename)
                            Spacer()
                            Button("Quick Look") { quickLook(att) }
                            Button("Reveal") { reveal(att) }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func indicatorLine(_ update: PortfolioThemeUpdate) -> some View {
        let files = FeatureFlags.portfolioAttachmentsEnabled() ? (attachmentMap[update.id] ?? []) : []
        let links = FeatureFlags.portfolioLinksEnabled() ? (linkMap[update.id] ?? []) : []
        let items: [Indicator] = files.map { .file($0) } + links.map { .link($0) }
        if !items.isEmpty {
            let total = items.count
            let displayed = Array(items.prefix(3))
            HStack {
                ForEach(Array(displayed.enumerated()), id: \.offset) { _, item in
                    switch item {
                    case .file(let att):
                        Button("! File: \(att.originalFilename)") { quickLook(att) }
                            .buttonStyle(.link)
                    case .link(let link):
                        Button("! Link: \(displayTitle(link))") { openLink(link) }
                            .buttonStyle(.link)
                    }
                }
                if total > 3 {
                    Button("... +\(total - 3) more") { toggleExpand(update.id) }
                        .buttonStyle(.link)
                }
            }
        }
    }

    // MARK: - Data

    private func load() {
        let query = searchText.isEmpty ? nil : searchText
        var list = dbManager.listThemeUpdates(themeId: themeId, view: .active, type: selectedType, searchQuery: query, pinnedFirst: pinnedFirst)
        if dateFilter != .all {
            let formatter = ISO8601DateFormatter()
            list = list.filter { upd in
                if let date = formatter.date(from: upd.createdAt) {
                    return dateFilter.contains(date)
                }
                return false
            }
        }
        updates = list
        if FeatureFlags.portfolioAttachmentsEnabled() {
            let repo = ThemeUpdateRepository(dbManager: dbManager)
            var map: [Int: [Attachment]] = [:]
            for u in list {
                map[u.id] = repo.listAttachments(updateId: u.id)
            }
            attachmentMap = map
        } else { attachmentMap = [:] }
        if FeatureFlags.portfolioLinksEnabled() {
            let repo = ThemeUpdateLinkRepository(dbManager: dbManager)
            var map: [Int: [Link]] = [:]
            for u in list {
                map[u.id] = repo.listLinks(updateId: u.id)
            }
            linkMap = map
        } else { linkMap = [:] }
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

    private func toggleExpand(_ id: Int) {
        if expandedId == id {
            expandedId = nil
        } else {
            expandedId = id
        }
    }

    private func formattedChf(_ value: Double) -> String {
        value.formatted(.currency(code: dbManager.baseCurrency).precision(.fractionLength(2)))
    }

    private func openLink(_ link: Link) {
        if let url = URL(string: link.rawURL) {
            if !NSWorkspace.shared.open(url) {
                LoggingService.shared.log("failed_to_open_link url=\(link.rawURL)", logger: .ui)
            }
        }
    }

    private func copyLink(_ link: Link) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(link.rawURL, forType: .string)
    }

    private func quickLook(_ attachment: Attachment) {
        AttachmentService(dbManager: dbManager).quickLook(attachmentId: attachment.id)
    }

    private func reveal(_ attachment: Attachment) {
        AttachmentService(dbManager: dbManager).revealInFinder(attachmentId: attachment.id)
    }

    private func displayTitle(_ link: Link) -> String {
        if let t = link.title, !t.isEmpty { return t }
        if let url = URL(string: link.rawURL) { return url.host ?? link.rawURL }
        return link.rawURL
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
        func contains(_ date: Date) -> Bool {
            var calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())
            guard let todayEnd = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: todayStart) else { return false }
            switch self {
            case .all:
                return true
            case .last7d:
                let start = calendar.date(byAdding: .day, value: -6, to: todayStart)!
                return date >= start && date <= todayEnd
            case .last30d:
                let start = calendar.date(byAdding: .day, value: -29, to: todayStart)!
                return date >= start && date <= todayEnd
            case .last90d:
                let start = calendar.date(byAdding: .day, value: -89, to: todayStart)!
                return date >= start && date <= todayEnd
            }
        }
    }

    private enum Indicator {
        case file(Attachment)
        case link(Link)
    }
}
