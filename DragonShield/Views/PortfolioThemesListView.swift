import SwiftUI

struct ThemeRow: Identifiable, Hashable {
    var theme: PortfolioTheme
    var status: PortfolioThemeStatus?
    var instrumentCount: Int
    var totalValue: Double?
    var excludedFx: Int
    var id: Int { theme.id }
    var statusName: String { status?.name ?? "" }
    var statusCode: String { status?.code ?? "" }
    var isArchived: Bool { statusCode == PortfolioThemeStatus.archivedCode || theme.archivedAt != nil }
    var updatedDate: Date { Self.dateFormatter.date(from: theme.updatedAt) ?? .distantPast }
    private static let dateFormatter = ISO8601DateFormatter()
}

struct PortfolioThemesListView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    @AppStorage("PortfolioThemesList.sortKey") private var sortKey = "updatedAt"
    @AppStorage("PortfolioThemesList.sortAsc") private var sortAsc = false

    @State private var rows: [ThemeRow] = []
    @State private var statuses: [PortfolioThemeStatus] = []

    @State private var selectedThemeId: PortfolioTheme.ID?
    @State private var themeToEdit: PortfolioTheme?
    @State private var showingAddSheet = false
    @State private var navigateThemeId: Int?

    @State private var sortOrder = [KeyPathComparator<ThemeRow>]()
    @State private var themeToDelete: PortfolioTheme?
    @State private var showArchiveAlert = false
    @State private var alertMessage = ""
    @State private var showingResultAlert = false

    var body: some View {
        NavigationStack {
            VStack {
                themesTable
                Button(action: openSelected) { EmptyView() }
                    .keyboardShortcut(.return)
                    .hidden()
                    .disabled(selectedThemeId == nil)
                HStack {
                    Button(action: { showingAddSheet = true }) {
                        Label("Add Theme", systemImage: "plus")
                    }
                    Button(action: {
                        if let selectedId = selectedThemeId {
                            themeToEdit = rows.first { $0.id == selectedId }?.theme
                        }
                    }) {
                        Label("Edit Theme", systemImage: "pencil")
                    }
                    .disabled(selectedThemeId == nil)
                    Button(action: {
                        if let selectedId = selectedThemeId, let row = rows.first(where: { $0.id == selectedId }) {
                            handleDelete(row.theme)
                        }
                    }) {
                        Label("Delete Theme", systemImage: "trash")
                    }
                    .disabled(selectedThemeId == nil)
                }
                .padding()
            }
            .navigationDestination(isPresented: Binding(get: { navigateThemeId != nil }, set: { if !$0 { navigateThemeId = nil } })) {
                if let id = navigateThemeId {
                    PortfolioThemeDetailView(themeId: id, origin: "themesList")
                        .environmentObject(dbManager)
                }
            }
        }
        .navigationTitle("Portfolio Themes")
        .onAppear(perform: loadData)
        .sheet(isPresented: $showingAddSheet, onDismiss: loadData) {
            AddPortfolioThemeView(isPresented: $showingAddSheet, onSave: {})
                .environmentObject(dbManager)
        }
        .sheet(item: $themeToEdit, onDismiss: loadData) { theme in
            EditPortfolioThemeView(theme: theme, onSave: {})
                .environmentObject(dbManager)
        }
        .alert("Delete Theme", isPresented: $showArchiveAlert) {
            Button("Archive and Delete") { archiveAndDelete() }
            Button("Cancel", role: .cancel) { themeToDelete = nil }
        } message: {
            Text("Theme must be archived before deletion.")
        }
        .alert("Result", isPresented: $showingResultAlert) {
            Button("OK") { showingResultAlert = false }
        } message: {
            Text(alertMessage)
        }
    }

    private var themesTable: some View {
        Table(rows, selection: $selectedThemeId, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.theme.name) { row in
                Text(row.theme.name)
                    .foregroundStyle(row.isArchived ? .secondary : .primary)
            }

            TableColumn("Code", value: \.theme.code) { row in
                Text(row.theme.code)
                    .foregroundStyle(row.isArchived ? .secondary : .primary)
            }

            TableColumn("Status", value: \.statusName) { row in
                Text(row.statusName)
                    .foregroundStyle(row.isArchived ? .secondary : .primary)
            }

            TableColumn("Last Updated", value: \.updatedDate) { row in
                Text(row.updatedDate, format: .dateTime.year().month().day().hour().minute())
                    .foregroundStyle(row.isArchived ? .secondary : .primary)
            }

            TableColumn("Total Value", sortUsing: KeyPathComparator(\.totalValue)) { row in
                if let value = row.totalValue {
                    Text(value, format: .currency(code: dbManager.baseCurrency).precision(.fractionLength(2)))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .foregroundStyle(row.isArchived ? .secondary : .primary)
                        .help(row.excludedFx > 0 ? "Partial valuation (FX missing for \(row.excludedFx) instruments)." : "")
                } else {
                    HStack(spacing: 4) {
                        Text("—")
                        ProgressView().scaleEffect(0.5)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .foregroundStyle(row.isArchived ? .secondary : .primary)
                    .help("Valuation not available.")
                }
            }
            .width(min: 120)

            TableColumn("Instruments", value: \.instrumentCount) { row in
                Text("\(row.instrumentCount)")
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .foregroundStyle(row.isArchived ? .secondary : .primary)
            }
            .width(min: 80)

            TableColumn("") { row in
                Button { open(row.theme) } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(row.isArchived ? .secondary : .primary)
                }
                .buttonStyle(.plain)
                .help("Open Theme Details")
                .accessibilityLabel("Open details for \(row.theme.name)")
            }
            .width(30)
        }
        .onChange(of: sortOrder) { newOrder in
            guard let comparator = newOrder.first else { return }
            rows.sort(using: newOrder)
            if comparator.keyPath == \ThemeRow.theme.name { sortKey = "name" }
            else if comparator.keyPath == \ThemeRow.theme.code { sortKey = "code" }
            else if comparator.keyPath == \ThemeRow.statusName { sortKey = "status" }
            else if comparator.keyPath == \ThemeRow.updatedDate { sortKey = "updatedAt" }
            else if comparator.keyPath == \ThemeRow.totalValue { sortKey = "totalValue" }
            else if comparator.keyPath == \ThemeRow.instrumentCount { sortKey = "instrumentCount" }
            sortAsc = comparator.order == .forward
        }
        .onTapGesture(count: 2) { openSelected() }
        .contextMenu(forSelectionType: PortfolioTheme.ID.self) { _ in
            Button("Open Theme Details") { openSelected() }.disabled(selectedThemeId == nil)
        }
    }

    private func loadData() {
        statuses = dbManager.fetchPortfolioThemeStatuses()
        let statusDict = Dictionary(uniqueKeysWithValues: statuses.map { ($0.id, $0) })
        let themes = dbManager.fetchPortfolioThemes(includeArchived: true, includeSoftDeleted: false, search: nil)
        rows = themes.map { theme in
            let status = statusDict[theme.statusId]
            let count = dbManager.themeAssetCount(themeId: theme.id)
            return ThemeRow(theme: theme, status: status, instrumentCount: count, totalValue: nil, excludedFx: 0)
        }
        applyStoredSort()
        rows.sort(using: sortOrder)
        for row in rows {
            startValuation(for: row.id)
        }
    }

    private func applyStoredSort() {
        let order: SortOrder = sortAsc ? .forward : .reverse
        let comparator: KeyPathComparator<ThemeRow>
        switch sortKey {
        case "name": comparator = .init(\.theme.name, order: order)
        case "code": comparator = .init(\.theme.code, order: order)
        case "status": comparator = .init(\.statusName, order: order)
        case "totalValue": comparator = .init(\.totalValue, order: order)
        case "instrumentCount": comparator = .init(\.instrumentCount, order: order)
        default: comparator = .init(\.updatedDate, order: order)
        }
        sortOrder = [comparator]
    }

    private func startValuation(for themeId: Int) {
        Task {
            let service = PortfolioValuationService(dbManager: dbManager)
            let snap = service.snapshot(themeId: themeId)
            await MainActor.run {
                if let idx = rows.firstIndex(where: { $0.id == themeId }) {
                    rows[idx].totalValue = snap.totalValueBase
                    rows[idx].excludedFx = snap.excludedFxCount
                    rows.sort(using: sortOrder)
                }
            }
        }
    }

    func handleDelete(_ theme: PortfolioTheme) {
        if theme.archivedAt == nil {
            themeToDelete = theme
            showArchiveAlert = true
        } else {
            performDelete(theme)
        }
    }

    func archiveAndDelete() {
        guard let theme = themeToDelete else { return }
        if dbManager.archivePortfolioTheme(id: theme.id) {
            performDelete(theme)
        } else {
            alertMessage = "❌ Failed to archive theme"
            showingResultAlert = true
        }
        themeToDelete = nil
    }

    private func performDelete(_ theme: PortfolioTheme) {
        if dbManager.softDeletePortfolioTheme(id: theme.id) {
            alertMessage = "✅ Theme deleted"
            showingResultAlert = true
            selectedThemeId = nil
            loadData()
        } else {
            alertMessage = "❌ Failed to delete theme"
            showingResultAlert = true
        }
    }

    private func openSelected() {
        if let selectedId = selectedThemeId, let row = rows.first(where: { $0.id == selectedId }) {
            open(row.theme)
        }
    }

    private func open(_ theme: PortfolioTheme) {
        navigateThemeId = theme.id
    }
}
