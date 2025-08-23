import SwiftUI
import AppKit

struct PortfolioThemeOverviewView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    var valuation: ValuationSnapshot?
    let isReadOnly: Bool
    var onMaintenance: () -> Void
    var onNavigate: (DetailTab) -> Void = { _ in }

    @State private var searchText: String = ""
    @State private var selectedType: PortfolioThemeUpdate.UpdateType? = nil
    @State private var pinnedFirst: Bool = true
    enum DateRange: String, CaseIterable, Identifiable { case last7 = "Last 7d", last30 = "Last 30d", last90 = "Last 90d", all = "All"; var id: Self { self } }
    @State private var dateRange: DateRange = .last90

    @State private var updates: [PortfolioThemeUpdate] = []
    @State private var attachmentCounts: [Int: Int] = [:]
    @State private var linkCounts: [Int: Int] = [:]
    @State private var searchDebounce: DispatchWorkItem?

    @State private var readerUpdate: PortfolioThemeUpdate?
    @State private var editingUpdate: PortfolioThemeUpdate?
    @State private var showEditor = false
    @State private var themeName: String = ""
    @State private var updateToDelete: PortfolioThemeUpdate?
    @State private var showDeleteConfirm = false

    // KPI
    @State private var instrumentCount: Int = 0
    @State private var totalValue: Double?
    @State private var lastUpdate: String?
    @State private var researchSum: Double = 0
    @State private var userSum: Double = 0
    @State private var excludedCount: Int = 0

    private let isoFormatter = ISO8601DateFormatter()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            filters
            if updates.isEmpty {
                emptyState
            } else {
                updatesList
            }
            snapshotTiles
        }
        .padding(24)
        .onAppear { load() }
        .sheet(item: $readerUpdate) { upd in
            ThemeUpdateReaderView(update: upd, isReadOnly: isReadOnly,
                                  onEdit: { editingUpdate = $0 },
                                  onPinToggle: { togglePin($0) },
                                  onDelete: { u in updateToDelete = u; showDeleteConfirm = true })
                .environmentObject(dbManager)
        }
        .sheet(isPresented: $showEditor) {
            ThemeUpdateEditorView(themeId: themeId, themeName: themeName, onSave: { _ in
                showEditor = false
                load()
            }, onCancel: { showEditor = false })
            .environmentObject(dbManager)
        }
        .sheet(item: $editingUpdate) { upd in
            ThemeUpdateEditorView(themeId: themeId, themeName: themeName, existing: upd, onSave: { _ in
                editingUpdate = nil
                load()
            }, onCancel: { editingUpdate = nil })
            .environmentObject(dbManager)
        }
        .confirmationDialog("Delete this update? This action can't be undone.", isPresented: $showDeleteConfirm, presenting: updateToDelete) { item in
            Button("Delete", role: .destructive) { delete(item) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Overview").font(.headline)
                Spacer()
                Button("Maintenance") { onMaintenance() }
            }
            HStack(spacing: 8) {
                Text("Total Value \(formattedCurrency(totalValue))")
                Text("•")
                Text("Instruments \(instrumentCount)")
                Text("•")
                Text("Last Update \(DateFormatting.userFriendly(lastUpdate))")
            }
            HStack(spacing: 8) {
                Text("Research Σ \(researchSum, format: .number.precision(.fractionLength(0)))%")
                Text("•")
                Text("User Σ \(userSum, format: .number.precision(.fractionLength(0)))%")
                Text("•")
                HStack(spacing: 4) {
                    Text("Excluded \(excludedCount)")
                    Button {
                        onNavigate(.valuation)
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(.subheadline)
        }
    }

    private var filters: some View {
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
                ForEach(DateRange.allCases) { r in
                    Text(r.rawValue).tag(r)
                }
            }
            .onChange(of: dateRange) { _, _ in load() }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No updates yet")
            if !isReadOnly {
                Button("+ New Update") { showEditor = true }
            }
        }
    }

    private var updatesList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(updates) { update in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(metaString(for: update))
                            .font(.subheadline)
                        Text("Title: \(update.title)").fontWeight(.semibold)
                        Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown))
                            .lineLimit(2)
                        HStack {
                            Button("View") { readerUpdate = update }
                            Button("Edit") { editingUpdate = update }.disabled(isReadOnly)
                            Button(update.pinned ? "Unpin" : "Pin") { togglePin(update) }.disabled(isReadOnly)
                            Button("Delete") {
                                updateToDelete = update
                                showDeleteConfirm = true
                            }.disabled(isReadOnly)
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
                }
            }
        }
    }

    private var snapshotTiles: some View {
        HStack(spacing: 16) {
            Button("Top Instruments by value") { onNavigate(.composition) }
            Button("Allocation deviation snapshot") { onNavigate(.valuation) }
            Button("Excluded items") { onNavigate(.valuation) }
        }
        .padding(.top, 16)
    }

    private func metaString(for update: PortfolioThemeUpdate) -> String {
        var parts: [String] = [
            DateFormatting.userFriendly(update.createdAt),
            update.author,
            update.type.rawValue
        ]
        if update.pinned { parts.append("★Pinned") }
        if let lc = linkCounts[update.id], lc > 0 { parts.append("Links \(lc)") }
        if let fc = attachmentCounts[update.id], fc > 0 { parts.append("Files \(fc)") }
        return parts.joined(separator: " • ")
    }

    private func formattedCurrency(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        return v.formatted(.currency(code: dbManager.baseCurrency).precision(.fractionLength(2)))
    }

    private func load() {
        let query = searchText.isEmpty ? nil : searchText
        var list = dbManager.listThemeUpdates(themeId: themeId, view: .active, type: selectedType, searchQuery: query, pinnedFirst: pinnedFirst)
        if let days = dateRangeDays(dateRange) {
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
            list = list.filter { isoFormatter.date(from: $0.createdAt)?.compare(cutoff) != .orderedAscending }
        }
        updates = list
        if FeatureFlags.portfolioAttachmentsEnabled(), !updates.isEmpty {
            attachmentCounts = dbManager.getAttachmentCounts(for: updates.map { $0.id })
        } else {
            attachmentCounts = [:]
        }
        if FeatureFlags.portfolioLinksEnabled(), !updates.isEmpty {
            let repo = ThemeUpdateLinkRepository(dbManager: dbManager)
            var counts: [Int: Int] = [:]
            for u in updates {
                counts[u.id] = repo.listLinks(updateId: u.id).count
            }
            linkCounts = counts
        } else {
            linkCounts = [:]
        }
        if let theme = dbManager.getPortfolioTheme(id: themeId) {
            themeName = theme.name
            instrumentCount = theme.instrumentCount
        }
        let assets = dbManager.listThemeAssets(themeId: themeId)
        researchSum = assets.reduce(0) { $0 + $1.researchTargetPct }
        userSum = assets.reduce(0) { $0 + $1.userTargetPct }
        totalValue = valuation?.totalValueBase
        excludedCount = valuation?.excludedFxCount ?? 0
        lastUpdate = dbManager.listThemeUpdates(themeId: themeId, view: .active, type: nil, searchQuery: nil, pinnedFirst: false).first?.createdAt
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
            DispatchQueue.main.async {
                readerUpdate = nil
                load()
            }
        }
    }

    private func dateRangeDays(_ range: DateRange) -> Int? {
        switch range {
        case .last7: return 7
        case .last30: return 30
        case .last90: return 90
        case .all: return nil
        }
    }
}
