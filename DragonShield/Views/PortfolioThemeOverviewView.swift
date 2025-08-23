import SwiftUI
import AppKit

struct PortfolioThemeOverviewView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    @Binding var selectedTab: DetailTab

    // MARK: - KPI State
    @State private var totalValue: Double?
    @State private var instrumentCount: Int = 0
    @State private var lastUpdate: Date?
    @State private var researchSum: Double = 0
    @State private var userSum: Double = 0
    @State private var excludedCount: Int = 0
    @State private var themeName: String = ""
    @State private var isReadOnly: Bool = false

    // MARK: - Filters
    @State private var searchText: String = ""
    @State private var selectedType: PortfolioThemeUpdate.UpdateType? = nil
    @State private var pinnedFirst: Bool = true
    @State private var dateRange: DateRange = .last90
    @State private var searchDebounce: DispatchWorkItem?

    // MARK: - Updates
    @State private var updates: [PortfolioThemeUpdate] = []
    @State private var attachmentCounts: [Int: Int] = [:]
    @State private var linkCounts: [Int: Int] = [:]
    @State private var selectedUpdate: PortfolioThemeUpdate?
    @State private var showEditor = false
    @State private var editingUpdate: PortfolioThemeUpdate?
    @State private var updateToDelete: PortfolioThemeUpdate?
    @State private var showDeleteConfirm = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .trailing) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    filterBar
                    if updates.isEmpty {
                        emptyState
                    } else {
                        updatesList
                    }
                    snapshotTiles
                }
                .padding(24)
                if let upd = selectedUpdate {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation { selectedUpdate = nil } }
                    ThemeUpdateReaderView(update: upd, onChanged: load, onClose: { withAnimation { selectedUpdate = nil } })
                        .environmentObject(dbManager)
                        .frame(width: max(480, geo.size.width * 0.4))
                        .background(Color(nsColor: .windowBackgroundColor))
                        .transition(.move(edge: .trailing))
                        .shadow(radius: 8)
                        .zIndex(1)
                }
            }
        }
        .onAppear { load() }
        .animation(.default, value: selectedUpdate)
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
        .confirmationDialog("Delete this update? This action can't be undone.", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let u = updateToDelete {
                    DispatchQueue.global(qos: .userInitiated).async {
                        if dbManager.softDeleteThemeUpdate(id: u.id, actor: NSFullUserName(), source: "overview") {
                            DispatchQueue.main.async { load() }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Overview").font(.headline)
                Spacer()
                Button("Maintenance") { selectedTab = .composition }
            }
            HStack(spacing: 8) {
                Text("Total Value \(formattedCurrency(totalValue))")
                Text("• Instruments \(instrumentCount)")
                Text("• Last Update \(formattedDate(lastUpdate))")
                Text("• Research Σ \(researchSum, format: .number)%")
                Text("• User Σ \(userSum, format: .number)%")
                Text("• Excluded \(excludedCount)")
                Image(systemName: "info.circle")
                    .onTapGesture { selectedTab = .valuation }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }

    private var filterBar: some View {
        HStack {
            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: searchText) { _, _ in debouncedLoad() }
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
                    Text(r.label).tag(r)
                }
            }
            .onChange(of: dateRange) { _, _ in load() }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No updates yet")
            Button("+ New Update") { showEditor = true }
                .buttonStyle(.borderedProminent)
                .disabled(isReadOnly)
        }
    }

    private var updatesList: some View {
        List(updates) { update in
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(ts(update.createdAt))
                    Text("• \(update.author) • \(update.type.rawValue)")
                    if update.pinned { Text("• ★Pinned") }
                    Text("• Links \(linkCounts[update.id] ?? 0)")
                    Text("• Files \(attachmentCounts[update.id] ?? 0)")
                }
                .font(.subheadline)
                Text("Title: \(update.title)").fontWeight(.semibold)
                Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown))
                    .lineLimit(2)
                HStack {
                    Button("View") { selectedUpdate = update }
                    Button("Edit") { editingUpdate = update }
                        .disabled(isReadOnly)
                    Button(update.pinned ? "Unpin" : "Pin") { togglePin(update) }
                        .disabled(isReadOnly)
                    Button("Delete") {
                        updateToDelete = update
                        showDeleteConfirm = true
                    }
                        .disabled(isReadOnly)
                }
            }
        }
        .listStyle(.inset)
    }

    private var snapshotTiles: some View {
        HStack {
            Button("Top Instruments by value") { selectedTab = .composition }
            Button("Allocation deviation snapshot") { selectedTab = .valuation }
            Button("Excluded items") { selectedTab = .valuation }
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func load() {
        if let theme = dbManager.getPortfolioTheme(id: themeId) {
            totalValue = theme.totalValueBase
            instrumentCount = theme.instrumentCount
            researchSum = theme.researchSum
            userSum = theme.userSum
            excludedCount = theme.excludedCount
            themeName = theme.name
            isReadOnly = theme.archivedAt != nil
        }
        let query = searchText.isEmpty ? nil : searchText
        var list = dbManager.listThemeUpdates(themeId: themeId, view: .active, type: selectedType, searchQuery: query, pinnedFirst: pinnedFirst)
        if let days = dateRange.days {
            let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
            list = list.filter { $0.createdAt >= cutoff }
        }
        updates = list
        lastUpdate = list.map { $0.createdAt }.max()
        if !list.isEmpty {
            attachmentCounts = dbManager.getAttachmentCounts(for: list.map { $0.id })
            let repo = ThemeUpdateLinkRepository(dbManager: dbManager)
            var l: [Int: Int] = [:]
            for u in list {
                l[u.id] = repo.listLinks(updateId: u.id).count
            }
            linkCounts = l
        } else {
            attachmentCounts = [:]
            linkCounts = [:]
        }
    }

    private func debouncedLoad() {
        searchDebounce?.cancel()
        let task = DispatchWorkItem { load() }
        searchDebounce = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: task)
    }

    private func togglePin(_ update: PortfolioThemeUpdate) {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = dbManager.updateThemeUpdate(id: update.id, title: nil, bodyMarkdown: nil, type: nil, pinned: !update.pinned, actor: NSFullUserName(), expectedUpdatedAt: update.updatedAt)
            DispatchQueue.main.async { load() }
        }
    }

    private func formattedCurrency(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        return v.formatted(.currency(code: dbManager.baseCurrency).precision(.fractionLength(2)))
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let d = date else { return "—" }
        return Self.tsFormatter.string(from: d)
    }

    private func ts(_ date: Date) -> String {
        Self.tsFormatter.string(from: date)
    }

    private static let tsFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()
}

// MARK: - DateRange

enum DateRange: String, CaseIterable, Identifiable {
    case last7, last30, last90, all
    var id: String { rawValue }
    var label: String {
        switch self {
        case .last7: return "Last 7d"
        case .last30: return "Last 30d"
        case .last90: return "Last 90d"
        case .all: return "All"
        }
    }
    var days: Int? {
        switch self {
        case .last7: return 7
        case .last30: return 30
        case .last90: return 90
        case .all: return nil
        }
    }
}
