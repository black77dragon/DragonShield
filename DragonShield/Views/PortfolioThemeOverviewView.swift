import SwiftUI
import AppKit

struct PortfolioThemeOverviewView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    var onMaintenance: () -> Void

    @State private var updates: [PortfolioThemeUpdate] = []
    @State private var selectedUpdate: PortfolioThemeUpdate?
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
                        Text("\(DateFormatting.userFriendly(update.createdAt)) • \(update.author) • \(update.type.rawValue)\(update.pinned ? " • ★Pinned" : "")")
                            .font(.subheadline)
                        Text("Title: \(update.title)").fontWeight(.semibold)
                        Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown))
                            .lineLimit(2)
                        HStack {
                            Button("View") { selectedUpdate = update }
                            Button("Edit") { editingUpdate = update }
                                .disabled(isArchived)
                            Button(update.pinned ? "Unpin" : "Pin") { togglePin(update) }
                                .disabled(isArchived)
                            Button("Delete", role: .destructive) { delete(update) }
                                .disabled(isArchived)
                        }
                        .buttonStyle(.borderless)
                    }
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
        .sheet(item: $selectedUpdate) { upd in
            ThemeUpdateReaderView(update: upd, onEdit: { editingUpdate = $0 }, onRefresh: { load(); loadKpis() })
                .environmentObject(dbManager)
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
            let calendar = Calendar.current
            switch self {
            case .all: return true
            case .last7d:
                return date >= calendar.date(byAdding: .day, value: -7, to: Date())!
            case .last30d:
                return date >= calendar.date(byAdding: .day, value: -30, to: Date())!
            case .last90d:
                return date >= calendar.date(byAdding: .day, value: -90, to: Date())!
            }
        }
    }
}

