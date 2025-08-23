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
                List {
                    ForEach(updates) { update in
                        UpdateRow(
                            update: update,
                            links: linkMap[update.id] ?? [],
                            attachments: attachmentMap[update.id] ?? [],
                            isExpanded: expandedBinding(for: update.id),
                            isArchived: isArchived,
                            onEdit: { editingUpdate = update },
                            onPin: { togglePin(update) },
                            onDelete: { delete(update) }
                        )
                    }
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

    private func expandedBinding(for id: Int) -> Binding<Bool> {
        Binding(get: { expandedId == id }, set: { expandedId = $0 ? id : nil })
    }

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
            let range = dateFilter.range(timeZone: tz)
            list = list.filter { upd in
                if let date = formatter.date(from: upd.createdAt) {
                    return range.contains(date)
                }
                return false
            }
        }
        updates = list
        if FeatureFlags.portfolioAttachmentsEnabled(), !updates.isEmpty {
            let repo = ThemeUpdateRepository(dbManager: dbManager)
            var dict: [Int: [Attachment]] = [:]
            for u in updates { dict[u.id] = repo.listAttachments(updateId: u.id) }
            attachmentMap = dict
        } else {
            attachmentMap = [:]
        }
        if FeatureFlags.portfolioLinksEnabled(), !updates.isEmpty {
            let repo = ThemeUpdateLinkRepository(dbManager: dbManager)
            var dict: [Int: [Link]] = [:]
            for u in updates { dict[u.id] = repo.listLinks(updateId: u.id) }
            linkMap = dict
        } else {
            linkMap = [:]
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
            _ = dbManager.softDeleteThemeUpdate(
                id: update.id,
                actor: NSFullUserName()
            )
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
        func range(timeZone: TimeZone) -> ClosedRange<Date> {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let todayStart = calendar.startOfDay(for: Date())
            let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: todayStart)!
            switch self {
            case .all:
                return Date.distantPast...Date.distantFuture
            case .last7d:
                let start = calendar.date(byAdding: .day, value: -6, to: todayStart)!
                return start...end
            case .last30d:
                let start = calendar.date(byAdding: .day, value: -29, to: todayStart)!
                return start...end
            case .last90d:
                let start = calendar.date(byAdding: .day, value: -89, to: todayStart)!
                return start...end
            }
        }
        func contains(_ date: Date, timeZone: TimeZone) -> Bool {
            range(timeZone: timeZone).contains(date)
        }
    }
}

private struct UpdateRow: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let update: PortfolioThemeUpdate
    let links: [Link]
    let attachments: [Attachment]
    @Binding var isExpanded: Bool
    let isArchived: Bool
    var onEdit: () -> Void
    var onPin: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Text("\(DateFormatting.userFriendly(update.createdAt)) • \(update.author) • \(update.type.rawValue)\(update.pinned ? " • ★Pinned" : "")")
                    .font(.subheadline)
                Spacer()
                HStack(spacing: 8) {
                    Button(isExpanded ? "View ▴" : "View ▾") { isExpanded.toggle() }
                    Button("Edit", action: onEdit).disabled(isArchived)
                    Button(update.pinned ? "Unpin" : "Pin", action: onPin).disabled(isArchived)
                    Button("Delete", role: .destructive, action: onDelete).disabled(isArchived)
                }
                .buttonStyle(.plain)
            }
            Text(update.title).fontWeight(.semibold)
            Text(snippet).lineLimit(1)
            indicatorLine
            if isExpanded { expandedContent }
        }
    }

    private var snippet: String {
        let text = MarkdownRenderer.attributedString(from: update.bodyMarkdown).string
        return text.replacingOccurrences(of: "\n", with: " ")
    }

    private enum Indicator {
        case link(Link)
        case file(Attachment)
    }

    private var allIndicators: [Indicator] {
        var arr: [Indicator] = []
        if FeatureFlags.portfolioAttachmentsEnabled() {
            arr.append(contentsOf: attachments.map { .file($0) })
        }
        if FeatureFlags.portfolioLinksEnabled() {
            arr.append(contentsOf: links.map { .link($0) })
        }
        return arr
    }

    private var indicatorLine: some View {
        let arr = allIndicators
        let shown = Array(arr.prefix(3))
        let extra = max(0, arr.count - 3)
        return HStack(spacing: 8) {
            ForEach(Array(shown.enumerated()), id: \.offset) { _, ind in
                indicatorButton(for: ind)
            }
            if extra > 0 {
                Button("… +\(extra) more") { isExpanded = true }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
            }
        }
    }

    @ViewBuilder
    private func indicatorButton(for indicator: Indicator) -> some View {
        switch indicator {
        case .file(let att):
            Button("! File: \(att.originalFilename)") {
                AttachmentService(dbManager: dbManager).quickLook(attachmentId: att.id)
            }
            .buttonStyle(.plain)
            .foregroundColor(.blue)
        case .link(let link):
            Button("! Link: \(displayTitle(link))") {
                openLink(link)
            }
            .buttonStyle(.plain)
            .foregroundColor(.blue)
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown))
            if FeatureFlags.portfolioLinksEnabled(), !links.isEmpty {
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
            if FeatureFlags.portfolioAttachmentsEnabled(), !attachments.isEmpty {
                Divider()
                Text("Files").font(.subheadline)
                ForEach(attachments, id: \.id) { att in
                    HStack {
                        Text(att.originalFilename)
                        Text(fileSize(att)).font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Button("Quick Look") { AttachmentService(dbManager: dbManager).quickLook(attachmentId: att.id) }
                        Button("Reveal") { AttachmentService(dbManager: dbManager).revealInFinder(attachmentId: att.id) }
                    }
                }
            }
        }
    }

    private func openLink(_ link: Link) {
        if let url = URL(string: link.rawURL) {
            NSWorkspace.shared.open(url)
        }
    }

    private func copyLink(_ link: Link) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(link.rawURL, forType: .string)
    }

    private func displayTitle(_ link: Link) -> String {
        if let t = link.title, !t.isEmpty { return t }
        if let url = URL(string: link.rawURL) { return url.host ?? link.rawURL }
        return link.rawURL
    }

    private func fileSize(_ att: Attachment) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(att.byteSize), countStyle: .file)
    }
}
