// DragonShield/Views/PortfolioThemesListView.swift
// MARK: - Version 2.5
// MARK: - History
// - Fixed compilation error by using the correct 'sortUsing' parameter for TableColumn.
// - Implemented custom sorting logic to sort the 'Status' column alphabetically by name.
// - Add Total Value and Instruments columns with sortable headers and archived row styling.

import SwiftUI

private struct PortfolioThemeRow: Identifiable, Hashable {
    var theme: PortfolioTheme
    var statusCode: String
    var statusName: String
    var totalValue: Double?
    var instrumentCount: Int
    var id: Int { theme.id }
}

struct PortfolioThemesListView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    // Local state for the data
    @State private var rows: [PortfolioThemeRow] = []
    @State private var statuses: [PortfolioThemeStatus] = []

    // Persisted sort preferences
    @AppStorage("PortfolioThemesSortKey") private var sortKeyStorage: String = "updatedAt"
    @AppStorage("PortfolioThemesSortAsc") private var sortAscStorage: Bool = false

    // State for selection and sheets
    @State private var selectedThemeId: PortfolioTheme.ID?
    @State private var themeToEdit: PortfolioTheme?
    @State private var showingAddSheet = false
    @State private var navigateThemeId: Int?

    // State to manage the table's sort order
    @State private var sortOrder = [KeyPathComparator<PortfolioThemeRow>]()
    @State private var themeToDelete: PortfolioTheme?
    @State private var showArchiveAlert = false
    @State private var alertMessage = ""
    @State private var showingResultAlert = false

    var body: some View {
        NavigationStack {
            VStack {
                themesTable

                // Invisible button to handle Return key opening the selected theme
                Button(action: openSelected) {
                    EmptyView()
                }
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

    // --- Subviews and Helper Methods ---

    private var themesTable: some View {
        Table(rows, selection: $selectedThemeId, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.theme.name) { row in
                let archived = row.statusCode == PortfolioThemeStatus.archivedCode
                Text(row.theme.name)
                    .foregroundStyle(archived ? .secondary : .primary)
            }
            TableColumn("Code", value: \.theme.code) { row in
                let archived = row.statusCode == PortfolioThemeStatus.archivedCode
                Text(row.theme.code)
                    .foregroundStyle(archived ? .secondary : .primary)
            }
            TableColumn("Status", value: \.statusName) { row in
                let archived = row.statusCode == PortfolioThemeStatus.archivedCode
                Text(row.statusName)
                    .foregroundStyle(archived ? .secondary : .primary)
            }
            TableColumn("Last Updated", value: \.theme.updatedAt) { row in
                let archived = row.statusCode == PortfolioThemeStatus.archivedCode
                Text(row.theme.updatedAt)
                    .foregroundStyle(archived ? .secondary : .primary)
            }
            TableColumn("Total Value", value: \.totalValue) { row in
                let archived = row.statusCode == PortfolioThemeStatus.archivedCode
                Group {
                    if let value = row.totalValue {
                        Text(value, format: .currency(code: dbManager.baseCurrency).precision(.fractionLength(2)))
                    } else {
                        HStack(spacing: 4) {
                            Text("—")
                            ProgressView().controlSize(.small)
                        }
                        .help("Valuation not available.")
                    }
                }
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .trailing)
                .foregroundStyle(archived ? .secondary : .primary)
            }
            TableColumn("Instruments", value: \.instrumentCount) { row in
                let archived = row.statusCode == PortfolioThemeStatus.archivedCode
                Text("\(row.instrumentCount)")
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .foregroundStyle(archived ? .secondary : .primary)
            }
            TableColumn("", content: { row in
                let archived = row.statusCode == PortfolioThemeStatus.archivedCode
                Button {
                    open(row.theme)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .help("Open Theme Details")
                .accessibilityLabel("Open details for \(row.theme.name)")
                .foregroundStyle(archived ? .secondary : .primary)
            })
            .width(30)
        }
        .onChange(of: sortOrder) { newOrder in
            guard let comparator = newOrder.first else { return }
            rows.sort(using: newOrder)
            sortKeyStorage = key(for: comparator)
            sortAscStorage = comparator.order == .forward
        }
        .onTapGesture(count: 2) { openSelected() }
        .contextMenu(forSelectionType: PortfolioTheme.ID.self) { _ in
            Button("Open Theme Details") { openSelected() }.disabled(selectedThemeId == nil)
        }
    }

    private func loadData() {
        statuses = dbManager.fetchPortfolioThemeStatuses()
        let statusById = Dictionary(uniqueKeysWithValues: statuses.map { ($0.id, $0) })
        let themes = dbManager.fetchPortfolioThemes(includeArchived: true, includeSoftDeleted: false, search: nil)
        rows = themes.map { theme in
            let status = statusById[theme.statusId]
            let count = dbManager.countThemeAssets(themeId: theme.id)
            return PortfolioThemeRow(theme: theme,
                                     statusCode: status?.code ?? "",
                                     statusName: status?.name ?? "N/A",
                                     totalValue: nil,
                                     instrumentCount: count)
        }
        applySavedSort()
        refreshValuations()
    }

    private func refreshValuations() {
        let service = PortfolioValuationService(dbManager: dbManager)
        for row in rows {
            Task.detached { [id = row.id] in
                let value = service.snapshot(themeId: id).totalValueBase
                await MainActor.run {
                    if let idx = rows.firstIndex(where: { $0.id == id }) {
                        rows[idx].totalValue = value
                        rows.sort(using: sortOrder)
                    }
                }
            }
        }
    }

    private func applySavedSort() {
        let asc = sortAscStorage
        switch sortKeyStorage {
        case "name":
            sortOrder = [KeyPathComparator(\.theme.name, order: asc ? .forward : .reverse)]
        case "code":
            sortOrder = [KeyPathComparator(\.theme.code, order: asc ? .forward : .reverse)]
        case "status":
            sortOrder = [KeyPathComparator(\.statusName, order: asc ? .forward : .reverse)]
        case "totalValue":
            sortOrder = [KeyPathComparator(\.totalValue, order: asc ? .forward : .reverse)]
        case "instruments":
            sortOrder = [KeyPathComparator(\.instrumentCount, order: asc ? .forward : .reverse)]
        default:
            sortOrder = [KeyPathComparator(\.theme.updatedAt, order: asc ? .forward : .reverse)]
        }
        rows.sort(using: sortOrder)
    }

    private func key(for comparator: KeyPathComparator<PortfolioThemeRow>) -> String {
        switch comparator.keyPath {
        case \PortfolioThemeRow.theme.name: return "name"
        case \PortfolioThemeRow.theme.code: return "code"
        case \PortfolioThemeRow.statusName: return "status"
        case \PortfolioThemeRow.theme.updatedAt: return "updatedAt"
        case \PortfolioThemeRow.totalValue: return "totalValue"
        case \PortfolioThemeRow.instrumentCount: return "instruments"
        default: return "updatedAt"
        }
    }

    private func handleDelete(_ theme: PortfolioTheme) {
        if theme.archivedAt == nil {
            themeToDelete = theme
            showArchiveAlert = true
        } else {
            performDelete(theme)
        }
    }

    private func archiveAndDelete() {
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

