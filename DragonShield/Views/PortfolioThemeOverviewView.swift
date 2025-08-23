import SwiftUI
import AppKit

struct PortfolioThemeOverviewView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    var navigateTo: (DetailTab) -> Void

    @State private var theme: PortfolioTheme?
    @State private var valuation: ValuationSnapshot?
    @State private var assets: [PortfolioThemeAsset] = []
    @State private var updates: [PortfolioThemeUpdate] = []
    @State private var selectedUpdate: PortfolioThemeUpdate?
    @State private var showEditor = false
    @State private var editingUpdate: PortfolioThemeUpdate?
    @State private var isArchived = false

    @State private var searchText = ""
    @State private var selectedType: PortfolioThemeUpdate.UpdateType? = nil
    @State private var pinnedFirst = true
    enum DateRange: String, CaseIterable { case last7 = "Last 7d", last30 = "Last 30d", last90 = "Last 90d", all = "All"
        var days: Int {
            switch self {
            case .last7: return 7
            case .last30: return 30
            case .last90: return 90
            case .all: return 3650
            }
        }
    }
    @State private var dateRange: DateRange = .last90
    @State private var searchDebounce: DispatchWorkItem?
    @State private var attachmentCounts: [Int: Int] = [:]
    @State private var linkCounts: [Int: Int] = [:]

    private let isoParser: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    var body: some View {
        ZStack {
            content
            if let selected = selectedUpdate {
                HStack(spacing: 0) {
                    Spacer()
                    ThemeUpdateReaderView(
                        update: selected,
                        onEdit: { editingUpdate = selected },
                        onPinToggle: { togglePin(selected) },
                        onDelete: { deleteUpdate(selected) },
                        onClose: { selectedUpdate = nil }
                    )
                    .frame(width: 420)
                    .background(Color(NSColor.windowBackgroundColor))
                    .shadow(radius: 4)
                    .transition(.move(edge: .trailing))
                }
            }
        }
        .onAppear { load() }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            kpiRow
            filterRow
            if updates.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(updates) { update in
                        updateRow(update)
                    }
                }
                .listStyle(.inset)
            }
            snapshotTiles
        }
        .padding(24)
        .sheet(isPresented: $showEditor) {
            ThemeUpdateEditorView(themeId: themeId, themeName: theme?.name ?? "", onSave: { _ in
                showEditor = false
                load()
            }, onCancel: { showEditor = false })
            .environmentObject(dbManager)
        }
        .sheet(item: $editingUpdate) { upd in
            ThemeUpdateEditorView(themeId: themeId, themeName: theme?.name ?? "", existing: upd, onSave: { _ in
                editingUpdate = nil
                load()
            }, onCancel: { editingUpdate = nil })
            .environmentObject(dbManager)
        }
    }

    private var header: some View {
        HStack {
            Text("Overview").font(.headline)
            Spacer()
            Button("Maintenance") { navigateTo(.composition) }
        }
    }

    private var kpiRow: some View {
        HStack(spacing: 12) {
            Text("Total Value \(formatted(valuation?.totalValueBase))")
            Text("Instruments \(theme?.instrumentCount ?? 0)")
            Text("Last Update \(lastUpdateString)")
            Text("Research Σ \(researchSum, specifier: "%.0f")%")
            Text("User Σ \(userSum, specifier: "%.0f")%")
            HStack(spacing: 4) {
                Text("Excluded \(valuation?.excludedFxCount ?? 0)")
                Button { navigateTo(.valuation) } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.plain)
            }
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
            Picker("Date", selection: $dateRange) {
                ForEach(DateRange.allCases, id: \.self) { r in
                    Text(r.rawValue).tag(r)
                }
            }
            .onChange(of: dateRange) { _, _ in load() }
            Spacer()
            Button("+ New Update") { showEditor = true }
                .disabled(isArchived)
        }
    }

    private func updateRow(_ update: PortfolioThemeUpdate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(DateFormatting.userFriendly(update.createdAt)) • \(update.author) • \(update.type.rawValue)")
                if update.pinned { Text("★Pinned") }
                if let lc = linkCounts[update.id], lc > 0 { Text("• Links \(lc)") }
                if let ac = attachmentCounts[update.id], ac > 0 { Text("• Files \(ac)") }
            }
            .font(.subheadline)
            Text("Title: \(update.title)").fontWeight(.semibold)
            Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown))
                .lineLimit(2)
            HStack {
                Button("View") { selectedUpdate = update }
                Button("Edit") { editingUpdate = update }
                Button(update.pinned ? "Unpin" : "Pin") { togglePin(update) }
                Button("Delete", role: .destructive) { deleteUpdate(update) }
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No updates yet")
            if !isArchived {
                Button("+ New Update") { showEditor = true }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var snapshotTiles: some View {
        HStack {
            Button("Top Instruments by value") { navigateTo(.valuation) }
            Button("Allocation deviation snapshot") { navigateTo(.valuation) }
            Button("Excluded items") { navigateTo(.valuation) }
        }
        .buttonStyle(.bordered)
        .padding(.top, 16)
    }

    private var lastUpdateString: String {
        if let first = updates.first { return DateFormatting.userFriendly(first.createdAt) }
        return "—"
    }

    private var researchSum: Double { assets.reduce(0) { $0 + $1.researchTargetPct } }
    private var userSum: Double { assets.reduce(0) { $0 + $1.userTargetPct } }

    private func formatted(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        return v.formatted(.currency(code: dbManager.baseCurrency).precision(.fractionLength(2)))
    }

    private func load() {
        theme = dbManager.getPortfolioTheme(id: themeId)
        isArchived = theme?.archivedAt != nil
        assets = dbManager.listThemeAssets(themeId: themeId)
        let fxService = FXConversionService(dbManager: dbManager)
        let service = PortfolioValuationService(dbManager: dbManager, fxService: fxService)
        valuation = service.snapshot(themeId: themeId)
        let query = searchText.isEmpty ? nil : searchText
        var list = dbManager.listThemeUpdates(themeId: themeId, view: .active, type: selectedType, searchQuery: query, pinnedFirst: pinnedFirst)
        if dateRange != .all {
            let cutoff = Calendar.current.date(byAdding: .day, value: -dateRange.days, to: Date())!
            list = list.filter { upd in
                if let d = isoParser.date(from: upd.createdAt) { return d >= cutoff }
                return false
            }
        }
        updates = list
        if FeatureFlags.portfolioAttachmentsEnabled(), !updates.isEmpty {
            attachmentCounts = dbManager.getAttachmentCounts(for: updates.map { $0.id })
        } else {
            attachmentCounts = [:]
        }
        if !updates.isEmpty {
            let lrepo = ThemeUpdateLinkRepository(dbManager: dbManager)
            var dict: [Int: Int] = [:]
            for u in updates { dict[u.id] = lrepo.listLinks(updateId: u.id).count }
            linkCounts = dict
        } else {
            linkCounts = [:]
        }
    }

    private func togglePin(_ update: PortfolioThemeUpdate) {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = dbManager.updateThemeUpdate(id: update.id, title: nil, bodyMarkdown: nil, type: nil, pinned: !update.pinned, actor: NSFullUserName(), expectedUpdatedAt: update.updatedAt)
            DispatchQueue.main.async { load() }
        }
    }

    private func deleteUpdate(_ update: PortfolioThemeUpdate) {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = dbManager.softDeleteThemeUpdate(id: update.id, actor: NSFullUserName())
            DispatchQueue.main.async { load() }
        }
    }
}
