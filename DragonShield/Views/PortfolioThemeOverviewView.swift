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
    @State private var expandedId: Int?
    @State private var links: [Int: [Link]] = [:]
    @State private var attachments: [Int: [Attachment]] = [:]

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
                List(updates, id: \.id) { update in
                    UpdateRow(
                        update: update,
                        isExpanded: expandedId == update.id,
                        attachments: attachments[update.id] ?? [],
                        links: links[update.id] ?? [],
                        isReadOnly: isArchived,
                        onToggle: { toggleExpand(update.id) },
                        onEdit: { editingUpdate = update },
                        onPin: { togglePin(update) },
                        onDelete: { delete(update) }
                    )
                    .environmentObject(dbManager)
                }
                .listStyle(.inset)
            }
        }
        .padding(24)
        .onAppear {
            load()
            loadKpis()
        }
        .onReceive(dbManager.$defaultTimeZone) { _ in load() }
        .sheet(isPresented: $showEditor) {
            ThemeUpdateEditorView(
                themeId: themeId,
                themeName: themeName,
                onSave: { _ in showEditor = false; load(); loadKpis() },
                onCancel: { showEditor = false }
            )
            .environmentObject(dbManager)
        }
        .sheet(item: $editingUpdate) { upd in
            ThemeUpdateEditorView(
                themeId: themeId,
                themeName: themeName,
                existing: upd,
                onSave: { _ in editingUpdate = nil; load(); loadKpis() },
                onCancel: { editingUpdate = nil }
            )
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

    // MARK: - Data

    private func load() {
        let query = searchText.isEmpty ? nil : searchText
        var list = dbManager.listThemeUpdates(
            themeId: themeId,
            view: .active,
            type: selectedType,
            searchQuery: query,
            pinnedFirst: pinnedFirst
        )
        if dateFilter != .all {
            let formatter = ISO8601DateFormatter()
            let tz = TimeZone(identifier: dbManager.defaultTimeZone) ?? .current
            list = list.filter { upd in
                if let date = formatter.date(from: upd.createdAt) {
                    return dateFilter.contains(date, in: tz)
                }
                return false
            }
        }
        updates = list
        if FeatureFlags.portfolioLinksEnabled() && !list.isEmpty {
            let repo = ThemeUpdateLinkRepository(dbManager: dbManager)
            var map: [Int: [Link]] = [:]
            for u in list { map[u.id] = repo.listLinks(updateId: u.id) }
            links = map
        } else {
            links = [:]
        }
        if FeatureFlags.portfolioAttachmentsEnabled() && !list.isEmpty {
            let repo = ThemeUpdateRepository(dbManager: dbManager)
            var map: [Int: [Attachment]] = [:]
            for u in list { map[u.id] = repo.listAttachments(updateId: u.id) }
            attachments = map
        } else {
            attachments = [:]
        }
    }

    private func loadKpis() {
        if let theme = dbManager.getPortfolioTheme(id: themeId) {
            themeName = theme.name
            isArchived = theme.archivedAt != nil
            let assets = dbManager.listThemeAssets(themeId: themeId)
            let research = assets.reduce(0) { $0 + $1.researchTargetPct }
            let user = assets.reduce(0) { $0 + $1.userTargetPct }
            let valuation = PortfolioValuationService(
                dbManager: dbManager,
                fxService: FXConversionService(dbManager: dbManager)
            ).snapshot(themeId: themeId)
            let last = dbManager.listThemeUpdates(
                themeId: themeId,
                view: .active,
                type: nil,
                searchQuery: nil,
                pinnedFirst: false
            ).first?.createdAt
            kpis = KPIMetrics(
                totalValue: valuation.totalValueBase,
                instruments: theme.instrumentCount,
                lastUpdate: last,
                researchSum: research,
                userSum: user,
                excluded: valuation.excludedFxCount
            )
        }
    }

    private func togglePin(_ update: PortfolioThemeUpdate) {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = dbManager.updateThemeUpdate(
                id: update.id,
                title: nil,
                bodyMarkdown: nil,
                type: nil,
                pinned: !update.pinned,
                actor: NSFullUserName(),
                expectedUpdatedAt: update.updatedAt
            )
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
        case last1d
        case last7d
        case last30d
        case last90d
        case all
        var id: String { rawValue }
        var label: String {
            switch self {
            case .last1d: return "Last 1d"
            case .last7d: return "Last 7d"
            case .last30d: return "Last 30d"
            case .last90d: return "Last 90d"
            case .all: return "All"
            }
        }
        private var days: Int? {
            switch self {
            case .last1d: return 1
            case .last7d: return 7
            case .last30d: return 30
            case .last90d: return 90
            case .all: return nil
            }
        }
        func contains(_ date: Date, in timeZone: TimeZone, now: Date = Date()) -> Bool {
            guard let days = days else { return true }
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = timeZone
            let startToday = cal.startOfDay(for: now)
            let endToday = cal.date(byAdding: .day, value: 1, to: startToday)!.addingTimeInterval(-1)
            let windowStart = cal.date(byAdding: .day, value: -(days - 1), to: startToday)!
            return date >= windowStart && date <= endToday
        }
    }

    private struct UpdateRow: View {
        @EnvironmentObject var dbManager: DatabaseManager
        let update: PortfolioThemeUpdate
        let isExpanded: Bool
        let attachments: [Attachment]
        let links: [Link]
        let isReadOnly: Bool
        let onToggle: () -> Void
        let onEdit: () -> Void
        let onPin: () -> Void
        let onDelete: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(header)
                        .font(.subheadline)
                    Spacer()
                    HStack(spacing: 12) {
                        Button(isExpanded ? "View ▴" : "View ▾", action: onToggle)
                        Button("Edit", action: onEdit).disabled(isReadOnly)
                        Button(update.pinned ? "Unpin" : "Pin", action: onPin).disabled(isReadOnly)
                        Button("Delete", action: onDelete).disabled(isReadOnly)
                    }
                    .buttonStyle(.link)
                }
                Text("Title: \(update.title)")
                    .fontWeight(.semibold)
                Text(snippet)
                    .lineLimit(1)
                indicatorLine
                if isExpanded {
                    Divider()
                    Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown))
                    if FeatureFlags.portfolioLinksEnabled(), !links.isEmpty {
                        Divider()
                        Text("Links").font(.subheadline)
                        ForEach(links, id: \.id) { link in
                            HStack {
                                Text(displayTitle(link))
                                Spacer()
                                Button("Open") { openLink(link) }
                                Button("Copy") { copyLink(link) }
                            }
                        }
                    }
                    if FeatureFlags.portfolioAttachmentsEnabled(), !attachments.isEmpty {
                        Divider()
                        Text("Files").font(.subheadline)
                        ForEach(attachments, id: \.id) { att in
                            HStack {
                                Text(att.originalFilename)
                                Spacer()
                                Button("Quick Look") { quickLook(att) }
                                Button("Reveal in Finder") { reveal(att) }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }

        private var header: String {
            let base = "\(DateFormatting.userFriendly(update.createdAt)) • \(update.author) • \(update.type.rawValue)"
            return update.pinned ? base + " • ★" : base
        }

        private var snippet: String {
            MarkdownRenderer.attributedString(from: update.bodyMarkdown)
                .string
                .replacingOccurrences(of: "\n", with: " ")
        }

        @ViewBuilder
        private var indicatorLine: some View {
            let items = indicators()
            if !items.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(items.prefix(3)).indices, id: \.self) { idx in
                        let indicator = items[idx]
                        switch indicator {
                        case .file(let att):
                            Button("! File: \(att.originalFilename)") { quickLook(att) }
                                .buttonStyle(.link)
                        case .link(let link):
                            Button("! Link: \(displayTitle(link))") { openLink(link) }
                                .buttonStyle(.link)
                        }
                    }
                    if items.count > 3 {
                        Button("+\(items.count - 3) more", action: onToggle)
                            .buttonStyle(.link)
                    }
                }
            }
        }

        private enum Indicator {
            case file(Attachment)
            case link(Link)
        }

        private func indicators() -> [Indicator] {
            var result: [Indicator] = []
            if FeatureFlags.portfolioAttachmentsEnabled() {
                result.append(contentsOf: attachments.map { .file($0) })
            }
            if FeatureFlags.portfolioLinksEnabled() {
                result.append(contentsOf: links.map { .link($0) })
            }
            return result
        }

        private func openLink(_ link: Link) {
            guard let url = URL(string: link.rawURL) else { return }
            NSWorkspace.shared.open(url)
        }

        private func copyLink(_ link: Link) {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(link.rawURL, forType: .string)
        }

        private func quickLook(_ att: Attachment) {
            AttachmentService(dbManager: dbManager).quickLook(attachmentId: att.id)
        }

        private func reveal(_ att: Attachment) {
            AttachmentService(dbManager: dbManager).revealInFinder(attachmentId: att.id)
        }

        private func displayTitle(_ link: Link) -> String {
            if let t = link.title, !t.isEmpty { return t }
            if let url = URL(string: link.rawURL) { return url.host ?? link.rawURL }
            return link.rawURL
        }
    }
}

