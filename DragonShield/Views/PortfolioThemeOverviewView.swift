import SwiftUI
import AppKit

struct PortfolioThemeOverviewView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    var onMaintenance: () -> Void

    @State private var updates: [PortfolioThemeUpdate] = []
    @State private var extras: [Int: UpdateExtras] = [:]
    @State private var editingUpdate: PortfolioThemeUpdate?
    @State private var showEditor = false
    @State private var searchText: String = ""
    @State private var selectedType: PortfolioThemeUpdate.UpdateType? = nil
    @State private var pinnedFirst: Bool = true
    @State private var dateFilter: UpdateDateFilter = .last90d
    @State private var kpis: KPIMetrics?
    @State private var searchDebounce: DispatchWorkItem?
    @State private var themeName: String = ""
    @State private var isArchived: Bool = false
    @State private var expandedId: Int? = nil

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
                    VStack(alignment: .leading, spacing: 4) {
                        headerLine(update)
                        titleLine(update)
                        indicatorRow(update)
                        if expandedId == update.id {
                            expandedDetails(update)
                        }
                    }
                    .contentShape(Rectangle())
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
                ForEach(UpdateDateFilter.allCases) { f in
                    Text(f.label).tag(f)
                }
            }
            .onChange(of: dateFilter) { _, _ in load() }
        }
    }

    private func headerLine(_ update: PortfolioThemeUpdate) -> some View {
        HStack(alignment: .top) {
            Text("\(DateFormatting.userFriendly(update.createdAt)) • \(update.author) • \(update.type.rawValue)\(update.pinned ? " • ★Pinned" : "")")
                .font(.subheadline)
            Spacer()
            HStack(spacing: 8) {
                Button(expandedId == update.id ? "View ▴" : "View ▾") { toggleExpand(update) }
                    .buttonStyle(.link)
                    .keyboardShortcut(.return)
                Button("Edit") { editingUpdate = update }
                    .buttonStyle(.link)
                    .disabled(isArchived)
                    .keyboardShortcut("e", modifiers: .command)
                Button(update.pinned ? "Unpin" : "Pin") { togglePin(update) }
                    .buttonStyle(.link)
                    .disabled(isArchived)
                    .keyboardShortcut("p", modifiers: .command)
                Button("Delete", role: .destructive) { delete(update) }
                    .buttonStyle(.link)
                    .disabled(isArchived)
                    .keyboardShortcut(.delete)
            }
        }
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

    private func indicatorRow(_ update: PortfolioThemeUpdate) -> some View {
        let extra = extras[update.id]
        var items: [Indicator] = []
        if let atts = extra?.attachments {
            items += atts.map { .file($0) }
        }
        if let links = extra?.links {
            items += links.map { .link($0) }
        }
        let displayed = Array(items.prefix(3))
        let remaining = items.count - displayed.count
        return HStack {
            ForEach(0..<displayed.count, id: \.self) { idx in
                switch displayed[idx] {
                case .file(let att):
                    Text("! File: \(att.originalFilename)")
                        .foregroundColor(.blue)
                        .onTapGesture { quickLook(att) }
                case .link(let l):
                    Text("! Link: \(displayTitle(l))")
                        .foregroundColor(.blue)
                        .onTapGesture { openLink(l) }
                }
            }
            if remaining > 0 {
                Text("… +\(remaining) more")
                    .foregroundColor(.blue)
                    .onTapGesture { expandedId = update.id }
            }
            Spacer()
        }
        .font(.subheadline)
    }

    private func expandedDetails(_ update: PortfolioThemeUpdate) -> some View {
        let extra = extras[update.id]
        return VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown))
            if let links = extra?.links, !links.isEmpty {
                Text("Links (\(links.count))").font(.subheadline)
                ForEach(links, id: \.id) { link in
                    HStack {
                        Text(displayTitle(link))
                        Spacer()
                        Button("Open") { openLink(link) }
                            .buttonStyle(.link)
                        Button("Copy") { copyLink(link) }
                            .buttonStyle(.link)
                    }
                }
            }
            if let atts = extra?.attachments, !atts.isEmpty {
                Text("Files (\(atts.count))").font(.subheadline)
                ForEach(atts, id: \.id) { att in
                    HStack {
                        Text(att.originalFilename)
                        Spacer()
                        Button("Quick Look") { quickLook(att) }
                            .buttonStyle(.link)
                        Button("Reveal") { reveal(att) }
                            .buttonStyle(.link)
                    }
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

    private func toggleExpand(_ update: PortfolioThemeUpdate) {
        if expandedId == update.id {
            expandedId = nil
        } else {
            expandedId = update.id
        }
    }

    private func openLink(_ link: Link) {
        if let url = URL(string: link.rawURL) {
            if !NSWorkspace.shared.open(url) {
                LoggingService.shared.log("Could not open link \(link.rawURL)", type: .error, logger: .ui)
            }
        }
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
        if let url = URL(string: link.rawURL) {
            return url.host ?? link.rawURL
        }
        return link.rawURL
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

    enum Indicator {
        case file(Attachment)
        case link(Link)
    }

}

extension PortfolioThemeOverviewView {
    static func titleOrPlaceholder(_ title: String) -> String {
        title.isEmpty ? "(No title)" : title
    }
}
