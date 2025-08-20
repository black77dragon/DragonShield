// DragonShield/Views/PortfolioThemesListView.swift
// MARK: - Version 3.0
// MARK: - History
// - Add Total Value and Instruments columns with sortable headers.
// - Persist sort selection and render archived themes in gray.

import SwiftUI

struct ThemeRow: Identifiable {
    var theme: PortfolioTheme
    var instrumentCount: Int
    var totalValue: Double?
    var loading: Bool

    var id: Int { theme.id }
    var name: String { theme.name }
    var code: String { theme.code }
    var statusId: Int { theme.statusId }
    var updatedAt: String { theme.updatedAt }
}

struct PortfolioThemesListView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var rows: [ThemeRow] = []
    @State private var statuses: [PortfolioThemeStatus] = []

    @State private var selectedThemeId: PortfolioTheme.ID?
    @State private var themeToEdit: PortfolioTheme?
    @State private var showingAddSheet = false
    @State private var navigateThemeId: Int?

    enum SortKey: String {
        case name, code, status, updated, totalValue, instruments
    }
    @AppStorage("PortfolioThemesSortKey") private var storedSortKey = SortKey.updated.rawValue
    @AppStorage("PortfolioThemesSortAsc") private var storedSortAsc: Bool = false
    @State private var sortOrder: [KeyPathComparator<ThemeRow>] = []

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
                        if let selectedId = selectedThemeId,
                           let theme = rows.first(where: { $0.id == selectedId })?.theme {
                            handleDelete(theme)
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
        .onAppear {
            let key = SortKey(rawValue: storedSortKey) ?? .updated
            sortOrder = [comparator(for: key, asc: storedSortAsc)]
            loadData()
        }
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
            TableColumn("Name", value: \.name) { row in
                Text(row.name)
                    .foregroundStyle(color(for: row))
            }
            TableColumn("Code", value: \.code) { row in
                Text(row.code)
                    .foregroundStyle(color(for: row))
            }
            TableColumn("Status", sortUsing: KeyPathComparator(\.statusId, comparator: { lhs, rhs in
                let nameLHS = statusName(for: lhs)
                let nameRHS = statusName(for: rhs)
                return nameLHS.localizedStandardCompare(nameRHS)
            })) { row in
                Text(statusName(for: row.statusId))
                    .foregroundStyle(color(for: row))
            }
            TableColumn("Last Updated", value: \.updatedAt) { row in
                Text(row.updatedAt)
                    .foregroundStyle(color(for: row))
            }
            TableColumn("Total Value", sortUsing: KeyPathComparator(\.totalValue, comparator: totalValueComparator)) { row in
                totalValueView(for: row)
            }
            TableColumn("Instruments", value: \.instrumentCount) { row in
                Text("\(row.instrumentCount)")
                    .monospacedDigit()
                    .foregroundStyle(color(for: row))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            TableColumn("", content: { row in
                Button { open(row.theme) } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .help("Open Theme Details")
                .accessibilityLabel("Open details for \(row.name)")
                .foregroundStyle(color(for: row))
            })
            .width(30)
        }
        .onChange(of: sortOrder) { newOrder in
            guard let comparator = newOrder.first else { return }
            rows.sort(using: newOrder)
            storedSortAsc = comparator.order == .forward
            if comparator.keyPath == \ThemeRow.name { storedSortKey = SortKey.name.rawValue }
            else if comparator.keyPath == \ThemeRow.code { storedSortKey = SortKey.code.rawValue }
            else if comparator.keyPath == \ThemeRow.statusId { storedSortKey = SortKey.status.rawValue }
            else if comparator.keyPath == \ThemeRow.updatedAt { storedSortKey = SortKey.updated.rawValue }
            else if comparator.keyPath == \ThemeRow.totalValue { storedSortKey = SortKey.totalValue.rawValue }
            else if comparator.keyPath == \ThemeRow.instrumentCount { storedSortKey = SortKey.instruments.rawValue }
        }
        .onTapGesture(count: 2) { openSelected() }
        .contextMenu(forSelectionType: PortfolioTheme.ID.self) { _ in
            Button("Open Theme Details") { openSelected() }.disabled(selectedThemeId == nil)
        }
    }

    private func loadData() {
        statuses = dbManager.fetchPortfolioThemeStatuses()
        let themes = dbManager.fetchPortfolioThemes(includeArchived: true, includeSoftDeleted: false, search: nil)
        rows = themes.map { theme in
            ThemeRow(theme: theme,
                     instrumentCount: dbManager.countThemeAssets(themeId: theme.id),
                     totalValue: nil,
                     loading: true)
        }
        rows.sort(using: sortOrder)
        loadValuations()
    }

    private func loadValuations() {
        let service = PortfolioValuationService(dbManager: dbManager)
        for row in rows {
            let id = row.id
            Task {
                let snap = service.snapshot(themeId: id)
                await MainActor.run {
                    if let idx = rows.firstIndex(where: { $0.id == id }) {
                        rows[idx].totalValue = snap.totalValueBase
                        rows[idx].loading = false
                        if sortOrder.first?.keyPath == \ThemeRow.totalValue {
                            rows.sort(using: sortOrder)
                        }
                    }
                }
            }
        }
    }

    private func statusName(for id: Int) -> String {
        statuses.first { $0.id == id }?.name ?? "N/A"
    }

    private func statusCode(for id: Int) -> String {
        statuses.first { $0.id == id }?.code ?? ""
    }

    private func isArchived(_ row: ThemeRow) -> Bool {
        statusCode(for: row.statusId) == PortfolioThemeStatus.archivedCode
    }

    private func color(for row: ThemeRow) -> Color {
        isArchived(row) ? .secondary : .primary
    }

    private func totalValueView(for row: ThemeRow) -> some View {
        Group {
            if row.loading {
                HStack(spacing: 4) {
                    Text("—")
                    ProgressView().controlSize(.small)
                }
            } else if let value = row.totalValue {
                Text(formatValue(value))
            } else {
                Text("—")
            }
        }
        .monospacedDigit()
        .foregroundStyle(color(for: row))
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var totalValueComparator: (Double?, Double?) -> ComparisonResult {
        { lhs, rhs in
            switch (lhs, rhs) {
            case let (l?, r?):
                if l < r { return .orderedAscending }
                if l > r { return .orderedDescending }
                return .orderedSame
            case (.none, .none):
                return .orderedSame
            case (.none, _):
                return .orderedAscending
            case (_, .none):
                return .orderedDescending
            }
        }
    }

    private func formatValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = dbManager.baseCurrency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? ""
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
        if let selectedId = selectedThemeId,
           let theme = rows.first(where: { $0.id == selectedId })?.theme {
            open(theme)
        }
    }

    private func open(_ theme: PortfolioTheme) {
        navigateThemeId = theme.id
    }

    private func comparator(for key: SortKey, asc: Bool) -> KeyPathComparator<ThemeRow> {
        let order: SortOrder = asc ? .forward : .reverse
        switch key {
        case .name:
            return KeyPathComparator(\.name, order: order)
        case .code:
            return KeyPathComparator(\.code, order: order)
        case .status:
            return KeyPathComparator(\.statusId, order: order, comparator: { lhs, rhs in
                let l = statusName(for: lhs)
                let r = statusName(for: rhs)
                return l.localizedStandardCompare(r)
            })
        case .updated:
            return KeyPathComparator(\.updatedAt, order: order)
        case .totalValue:
            return KeyPathComparator(\.totalValue, order: order, comparator: totalValueComparator)
        case .instruments:
            return KeyPathComparator(\.instrumentCount, order: order)
        }
    }
}

