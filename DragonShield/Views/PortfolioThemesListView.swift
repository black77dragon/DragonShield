// DragonShield/Views/PortfolioThemesListView.swift
// MARK: - Version 2.5
// MARK: - History
// - Added Total Value and Instruments columns with sortable headers and persisted sort order.
// - Render archived themes in gray and load valuations asynchronously.
// - Fixed compilation error by using the correct 'sortUsing' parameter for TableColumn.
// - Implemented custom sorting logic to sort the 'Status' column alphabetically by name.

import SwiftUI
import AppKit

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
    @State private var themeToOpen: PortfolioTheme?
    @State private var newUpdateTheme: PortfolioTheme?
    @State private var detailInitialTab: DetailTab = .overview
    @State private var detailOrigin: String = "themesList"

    // State to manage the table's sort order
    @State private var sortOrder = [KeyPathComparator<PortfolioTheme>]()
    @State private var themeToDelete: PortfolioTheme?
    @State private var showArchiveAlert = false
    @State private var alertMessage = ""
    @State private var showingResultAlert = false

    private var canNewUpdate: Bool { selectedThemeId != nil }

    var body: some View {
        NavigationStack {
            VStack {
                themesTable // The Table view, now correctly defined

                // Invisible button to handle Return key opening the selected theme
                Button(action: openSelected) {
                    EmptyView()
                }
                .keyboardShortcut(.return)
                .hidden()
                .disabled(selectedThemeId == nil)

                Button(action: { openNewUpdate(source: "shortcut") }) {
                    EmptyView()
                }
                .keyboardShortcut("u", modifiers: .command)
                .hidden()
                .disabled(!canNewUpdate)

                HStack {
                    Button(action: { showingAddSheet = true }) {
                        Label("Add Theme", systemImage: "plus")
                    }
                    Button(action: { openNewUpdate(source: "toolbar") }) {
                        Label("New Update", systemImage: "square.and.pencil")
                    }
                    .disabled(!canNewUpdate)

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
        .sheet(item: $newUpdateTheme) { theme in
            ThemeUpdateEditorView(themeId: theme.id, themeName: theme.name, onSave: { update in
                LoggingService.shared.log("new_update_saved themeId=\(theme.id) updateId=\(update.id) source=fast_path", logger: .ui)
                newUpdateTheme = nil
                detailInitialTab = .updates
                detailOrigin = "post_create"
                selectedThemeId = theme.id
                open(theme, source: "post_create", tab: .updates)
            }, onCancel: {
                LoggingService.shared.log("new_update_canceled themeId=\(theme.id) source=fast_path", logger: .ui)
                newUpdateTheme = nil
            })
            .environmentObject(dbManager)
        }
        .sheet(item: $themeToOpen, onDismiss: loadData) { theme in
            PortfolioThemeDetailView(themeId: theme.id, origin: detailOrigin, initialTab: detailInitialTab)
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
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .foregroundStyle(isArchived(theme) ? .secondary : .primary)
            }
            .width(min: 80)
            TableColumn("", content: { theme in
                Button {
                    open(theme)
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundColor(isArchived(theme) ? .secondary : .primary)
                }
                .buttonStyle(.plain)
                .help("Open Theme Details")
                .accessibilityLabel("Open details for \(theme.name)")
            })
            .width(30)
        }
        .onChange(of: sortOrder) { _, newOrder in
            guard let comparator = newOrder.first else { return }
            persistSortOrder()
            if comparator.keyPath == \.statusId {
                themes.sort { lhs, rhs in
                    let nameLHS = statusName(for: lhs.statusId)
                    let nameRHS = statusName(for: rhs.statusId)
                    if comparator.order == .forward {
                        return nameLHS.localizedStandardCompare(nameRHS) == .orderedAscending
                    } else {
                        return nameLHS.localizedStandardCompare(nameRHS) == .orderedDescending
                    }
                }
            } else if comparator.keyPath == \.totalValueBase {
                themes.sort { lhs, rhs in
                    let l = lhs.totalValueBase
                    let r = rhs.totalValueBase
                    if comparator.order == .forward {
                        switch (l, r) {
                        case let (l?, r?): return l < r
                        case (nil, _?): return true
                        case (_?, nil): return false
                        default: return false
                        }
                    } else {
                        switch (l, r) {
                        case let (l?, r?): return l > r
                        case (nil, _?): return false
                        case (_?, nil): return true
                        default: return false
                        }
                    }
                }
        } else {
            themes.sort(using: newOrder)
        }
    }
    .onTapGesture(count: 2) { openSelected() }
    .contextMenu(forSelectionType: PortfolioTheme.ID.self) { _ in
        Button("Open Theme Details") { openSelected() }.disabled(selectedThemeId == nil)
        Button("New Update…") { openNewUpdate(source: "context_menu") }
            .keyboardShortcut("u")
            .disabled(!canNewUpdate)
    }
}
    
    func loadData() {
        self.statuses = dbManager.fetchPortfolioThemeStatuses()
        self.themes = dbManager.fetchPortfolioThemes(includeArchived: true, includeSoftDeleted: false, search: nil)
        // Ensure data is sorted when first loaded
        self.themes.sort(using: self.sortOrder)
        loadValuations()
    }

    private func statusName(for id: Int) -> String {
        return statuses.first { $0.id == id }?.name ?? "N/A"
    }

    private func isArchived(_ theme: PortfolioTheme) -> Bool {
        statuses.first { $0.id == theme.statusId }?.code == PortfolioThemeStatus.archivedCode
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

    private func open(_ theme: PortfolioTheme, source: String = "list", tab: DetailTab? = nil) {
        let tabToLog: DetailTab
        if let t = tab {
            tabToLog = t
        } else {
            let raw = UserDefaults.standard.string(forKey: UserDefaultsKeys.portfolioThemeDetailLastTab) ?? DetailTab.overview.rawValue
            tabToLog = DetailTab(rawValue: raw) ?? .overview
        }
        LoggingService.shared.log("details_open themeId=\(theme.id) tab=\(tabToLog.rawValue) source=\(source)", logger: .ui)
        detailInitialTab = tabToLog
        detailOrigin = source
        themeToOpen = theme
    }

    private func openNewUpdate(source: String) {
        guard canNewUpdate, let selectedId = selectedThemeId, let theme = themes.first(where: { $0.id == selectedId }) else {
            NSSound.beep()
            return
        }
        LoggingService.shared.log("new_update_invoke themeId=\(theme.id) source=\(source)", logger: .ui)
        newUpdateTheme = theme
    }
}
