// DragonShield/Views/PortfolioThemesListView.swift
// MARK: - Version 2.6
// MARK: - History
// - Added Total Value and Instruments columns with sortable headers and persisted sort order.
// - Render archived themes in gray and load valuations asynchronously.
// - Fixed compilation error by using the correct 'sortUsing' parameter for TableColumn.
// - Implemented custom sorting logic to sort the 'Status' column alphabetically by name.
// - Present theme details in modal sheet with navigation title.

import SwiftUI

struct PortfolioThemesListView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    private enum SortField: String { case name, code, status, updatedAt, totalValue, instruments }
    private let sortDefaultsKey = "PortfolioThemesListView.sort"

    // Local state for the data
    @State var themes: [PortfolioTheme] = []
    @State private var statuses: [PortfolioThemeStatus] = []

    // State for selection and sheets
    @State private var selectedThemeId: PortfolioTheme.ID?
    @State private var themeToEdit: PortfolioTheme?
    @State private var showingAddSheet = false
    @State private var detailTheme: PortfolioTheme?

    // State to manage the table's sort order
    @State private var sortOrder = [KeyPathComparator<PortfolioTheme>]()
    @State private var themeToDelete: PortfolioTheme?
    @State private var showArchiveAlert = false
    @State private var alertMessage = ""
    @State private var showingResultAlert = false

    var body: some View {
        NavigationStack {
            VStack {
                themesTable

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
                            themeToEdit = themes.first { $0.id == selectedId }
                        }
                    }) {
                        Label("Edit Theme", systemImage: "pencil")
                    }
                    .disabled(selectedThemeId == nil)

                    Button(action: {
                        if let selectedId = selectedThemeId, let theme = themes.first(where: { $0.id == selectedId }) {
                            handleDelete(theme)
                        }
                    }) {
                        Label("Delete Theme", systemImage: "trash")
                    }
                    .disabled(selectedThemeId == nil)
                }
                .padding()
            }
        }
        .navigationTitle("Portfolio Themes")
        .onAppear { restoreSortOrder(); loadData() }
        .sheet(isPresented: $showingAddSheet, onDismiss: loadData) {
            AddPortfolioThemeView(isPresented: $showingAddSheet, onSave: {})
                .environmentObject(dbManager)
        }
        .sheet(item: $themeToEdit, onDismiss: loadData) { theme in
            EditPortfolioThemeView(theme: theme, onSave: {})
                .environmentObject(dbManager)
        }
        .sheet(item: $detailTheme, onDismiss: loadData) { theme in
            NavigationStack {
                PortfolioThemeDetailView(themeId: theme.id, origin: "themesList") { _ in loadData() }
                    .environmentObject(dbManager)
            }
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
        Table(themes, selection: $selectedThemeId, sortOrder: $sortOrder) {
            TableColumn(headerLabel("Name", field: .name), value: \.name) { theme in
                Text(theme.name).foregroundStyle(isArchived(theme) ? .secondary : .primary)
            }
            TableColumn(headerLabel("Code", field: .code), value: \.code) { theme in
                Text(theme.code).foregroundStyle(isArchived(theme) ? .secondary : .primary)
            }
            TableColumn(headerLabel("Status", field: .status), sortUsing: KeyPathComparator(\.statusId)) { theme in
                Text(statusName(for: theme.statusId)).foregroundStyle(isArchived(theme) ? .secondary : .primary)
            }
            TableColumn(headerLabel("Last Updated", field: .updatedAt), value: \.updatedAt) { theme in
                Text(theme.updatedAt).foregroundStyle(isArchived(theme) ? .secondary : .primary)
            }
            TableColumn(headerLabel("Total Value", field: .totalValue), sortUsing: KeyPathComparator(\.totalValueBase)) { theme in
                totalValueCell(for: theme)
            }
            .width(min: 120)
            TableColumn(headerLabel("Instruments", field: .instruments), value: \.instrumentCount) { theme in
                Text("\(theme.instrumentCount)")
                    .foregroundStyle(isArchived(theme) ? .secondary : .primary)
            }
            .width(min: 100)
        }
        .onChange(of: sortOrder) { _, _ in
            themes.sort(using: sortOrder)
            persistSortOrder()
        }
        .onChange(of: selectedThemeId) { _, id in
            if id != nil {
                loadValuations()
            }
        }
    }

    private func statusName(for statusId: Int) -> String {
        statuses.first { $0.id == statusId }?.name ?? "#\(statusId)"
    }

    private func headerLabel(_ title: String, field: SortField) -> Text {
        if let comp = sortOrder.first, sortField(for: comp) == field {
            let asc = comp.order == .forward
            return Text("\(title) \(asc ? "▲" : "▼")").foregroundColor(.accentColor)
        } else {
            return Text("\(title) ↕").foregroundColor(.secondary)
        }
    }

    private func sortField(for comparator: KeyPathComparator<PortfolioTheme>) -> SortField? {
        switch comparator.keyPath {
        case \.name: return .name
        case \.code: return .code
        case \.statusId: return .status
        case \.updatedAt: return .updatedAt
        case \.totalValueBase: return .totalValue
        case \.instrumentCount: return .instruments
        default: return nil
        }
    }

    private func persistSortOrder() {
        guard let comp = sortOrder.first, let field = sortField(for: comp) else { return }
        let asc = comp.order == .forward ? "asc" : "desc"
        UserDefaults.standard.set("\(field.rawValue)|\(asc)", forKey: sortDefaultsKey)
    }

    private func restoreSortOrder() {
        guard let saved = UserDefaults.standard.string(forKey: sortDefaultsKey) else {
            sortOrder = [KeyPathComparator(\.updatedAt, order: .reverse)]
            return
        }
        let parts = saved.split(separator: "|")
        guard parts.count == 2, let field = SortField(rawValue: String(parts[0])) else {
            sortOrder = [KeyPathComparator(\.updatedAt, order: .reverse)]
            return
        }
        let asc = parts[1] == "asc"
        switch field {
        case .name: sortOrder = [KeyPathComparator(\.name, order: asc ? .forward : .reverse)]
        case .code: sortOrder = [KeyPathComparator(\.code, order: asc ? .forward : .reverse)]
        case .status: sortOrder = [KeyPathComparator(\.statusId, order: asc ? .forward : .reverse)]
        case .updatedAt: sortOrder = [KeyPathComparator(\.updatedAt, order: asc ? .forward : .reverse)]
        case .totalValue: sortOrder = [KeyPathComparator(\.totalValueBase, order: asc ? .forward : .reverse)]
        case .instruments: sortOrder = [KeyPathComparator(\.instrumentCount, order: asc ? .forward : .reverse)]
        }
    }

    func loadValuations() {
        Task(priority: .background) {
            let fxService = FXConversionService(dbManager: dbManager)
            let service = PortfolioValuationService(dbManager: dbManager, fxService: fxService)
            let ids = await MainActor.run { themes.map(\.id) }
            for id in ids {
                if Task.isCancelled { break }
                let value = service.snapshot(themeId: id).totalValueBase
                await MainActor.run {
                    if let idx = themes.firstIndex(where: { $0.id == id }) {
                        themes[idx].totalValueBase = value
                        themes.sort(using: sortOrder)
                    }
                }
            }
        }
    }

    private func totalValueCell(for theme: PortfolioTheme) -> some View {
        Group {
            if let value = theme.totalValueBase {
                Text(value, format: .currency(code: dbManager.baseCurrency).precision(.fractionLength(2)))
                    .monospacedDigit()
            } else {
                HStack(spacing: 4) {
                    Text("—")
                    ProgressView().controlSize(.small)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .foregroundStyle(isArchived(theme) ? .secondary : .primary)
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
        if let selectedId = selectedThemeId, let theme = themes.first(where: { $0.id == selectedId }) {
            open(theme)
        }
    }

    private func open(_ theme: PortfolioTheme) {
        detailTheme = theme
    }
}
