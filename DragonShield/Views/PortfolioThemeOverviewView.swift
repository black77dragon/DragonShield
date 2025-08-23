import SwiftUI
import AppKit

struct PortfolioThemeOverviewView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    @Binding var selectedTab: DetailTab

    @State private var searchText: String = ""
    @State private var selectedType: PortfolioThemeUpdate.UpdateType? = nil
    @State private var pinnedFirst: Bool = true
    @State private var dateRange: DateRange = .last90
    @State private var updates: [PortfolioThemeUpdate] = []
    @State private var linkCounts: [Int: Int] = [:]
    @State private var attachmentCounts: [Int: Int] = [:]
    @State private var viewing: PortfolioThemeUpdate?
    @State private var editing: PortfolioThemeUpdate?
    @State private var showDeleteConfirm = false
    @State private var kpis = KPIs()
    @State private var isArchived: Bool = false

    struct KPIs {
        var totalValue: Double = 0
        var instruments: Int = 0
        var lastUpdate: String? = nil
        var researchSum: Double = 0
        var userSum: Double = 0
        var excluded: Int = 0
    }

    enum DateRange: String, CaseIterable, Identifiable {
        case last7 = "Last 7d"
        case last30 = "Last 30d"
        case last90 = "Last 90d"
        case all = "All"
        var id: String { rawValue }
        var days: Int? {
            switch self {
            case .last7: return 7
            case .last30: return 30
            case .last90: return 90
            case .all: return nil
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            kpiRow
            filterRow
            List {
                if updates.isEmpty {
                    Text("No updates yet")
                } else {
                    ForEach(updates) { update in
                        VStack(alignment: .leading, spacing: 4) {
                            headerText(update)
                            Text("Title: \(update.title)").fontWeight(.semibold)
                            Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown)).lineLimit(2)
                            HStack {
                                Button("View") { viewing = update }
                                Button("Edit") { editing = update }.disabled(isReadOnly)
                Button(update.pinned ? "Unpin" : "Pin") { togglePin(update) }.disabled(isReadOnly)
                                Button("Delete", role: .destructive) { viewing = update; showDeleteConfirm = true }.disabled(isReadOnly)
                            }
                        }
                    }
                }
            }
        }
        .padding(24)
        .onAppear { loadAll() }
        .confirmationDialog("Delete this update?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let upd = viewing { deleteUpdate(upd) }
            }
        }
        .sheet(item: $viewing, onDismiss: loadUpdates) { upd in
            ThemeUpdateReaderView(update: upd, themeId: themeId, isArchived: isReadOnly) {
                editing = upd
            }
            .environmentObject(dbManager)
        }
        .sheet(item: $editing, onDismiss: loadUpdates) { upd in
            ThemeUpdateEditorView(themeId: themeId, themeName: themeName, existing: upd, onSave: { _ in
                editing = nil
            }, onCancel: { editing = nil })
            .environmentObject(dbManager)
        }
    }

    private var isReadOnly: Bool { isArchived }

    private var themeName: String {
        dbManager.getPortfolioTheme(id: themeId)?.name ?? ""
    }

    private var attachmentsEnabled: Bool { FeatureFlags.portfolioAttachmentsEnabled() }
    private var linksEnabled: Bool { FeatureFlags.portfolioLinksEnabled() }

    private var kpiRow: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Total Value  \(kpis.totalValue.formatted(.currency(code: dbManager.baseCurrency).precision(.fractionLength(2))))")
                Text("• Instruments  \(kpis.instruments)")
                Text("• Last Update  \(DateFormatting.userFriendly(kpis.lastUpdate))")
            }
            HStack {
                Text("Research Σ  \(String(format: "%.0f%%", kpis.researchSum))")
                Text("• User Σ  \(String(format: "%.0f%%", kpis.userSum))")
                HStack(spacing: 4) {
                    Text("• Excluded  \(kpis.excluded)")
                    Button("i") { selectedTab = .valuation }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private var filterRow: some View {
        HStack {
            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: searchText) { _, _ in loadUpdates() }
            Picker("Type", selection: $selectedType) {
                Text("All").tag(nil as PortfolioThemeUpdate.UpdateType?)
                ForEach(PortfolioThemeUpdate.UpdateType.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(Optional(t))
                }
            }
            .onChange(of: selectedType) { _, _ in loadUpdates() }
            Toggle("Pinned first", isOn: $pinnedFirst)
                .toggleStyle(.checkbox)
                .onChange(of: pinnedFirst) { _, _ in loadUpdates() }
            Picker("Date", selection: $dateRange) {
                ForEach(DateRange.allCases) { r in
                    Text(r.rawValue).tag(r)
                }
            }
            .onChange(of: dateRange) { _, _ in loadUpdates() }
        }
    }

    private func headerText(_ update: PortfolioThemeUpdate) -> Text {
        var parts: [String] = [DateFormatting.userFriendly(update.createdAt), update.author, update.type.rawValue]
        if update.pinned { parts.append("★Pinned") }
        if linksEnabled { parts.append("Links \(linkCounts[update.id] ?? 0)") }
        if attachmentsEnabled { parts.append("Files \(attachmentCounts[update.id] ?? 0)") }
        return Text(parts.joined(separator: " • ")).font(.subheadline)
    }

    private func loadAll() {
        let theme = dbManager.getPortfolioTheme(id: themeId)
        isArchived = theme?.archivedAt != nil
        loadKpis()
        loadUpdates()
    }

    private func loadKpis() {
        let assets = dbManager.listThemeAssets(themeId: themeId)
        kpis.instruments = assets.count
        kpis.researchSum = assets.reduce(0) { $0 + $1.researchTargetPct }
        kpis.userSum = assets.reduce(0) { $0 + $1.userTargetPct }
        let fx = FXConversionService(dbManager: dbManager)
        let service = PortfolioValuationService(dbManager: dbManager, fxService: fx)
        let snap = service.snapshot(themeId: themeId)
        kpis.totalValue = snap.totalValueBase
        kpis.excluded = snap.excludedFxCount
        let latest = dbManager.listThemeUpdates(themeId: themeId, view: .active, type: nil, searchQuery: nil, pinnedFirst: true).first
        kpis.lastUpdate = latest?.createdAt
    }

    private func loadUpdates() {
        let q = searchText.isEmpty ? nil : searchText
        var items = dbManager.listThemeUpdates(themeId: themeId, view: .active, type: selectedType, searchQuery: q, pinnedFirst: pinnedFirst)
        if let days = dateRange.days {
            let formatter = ISO8601DateFormatter()
            let threshold = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
            items = items.filter { update in
                if let d = formatter.date(from: update.createdAt) { return d >= threshold } else { return true }
            }
        }
        updates = items
        if attachmentsEnabled {
            var counts: [Int: Int] = [:]
            let repo = ThemeUpdateRepository(dbManager: dbManager)
            for u in items { counts[u.id] = repo.listAttachments(updateId: u.id).count }
            attachmentCounts = counts
        }
        if linksEnabled {
            var counts: [Int: Int] = [:]
            let repo = ThemeUpdateLinkRepository(dbManager: dbManager)
            for u in items { counts[u.id] = repo.listLinks(updateId: u.id).count }
            linkCounts = counts
        }
    }

    private func togglePin(_ update: PortfolioThemeUpdate) {
        _ = dbManager.updateThemeUpdate(id: update.id, title: nil, bodyMarkdown: nil, type: nil, pinned: !update.pinned, actor: NSFullUserName(), expectedUpdatedAt: update.updatedAt)
        loadUpdates()
    }

    private func deleteUpdate(_ update: PortfolioThemeUpdate) {
        _ = dbManager.softDeleteThemeUpdate(id: update.id, actor: NSFullUserName())
        loadUpdates()
    }
}

