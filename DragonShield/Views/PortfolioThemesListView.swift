// DragonShield/Views/PortfolioThemesListView.swift
// MARK: - Version 2.4
// MARK: - History
// - Fixed compilation error by using the correct 'sortUsing' parameter for TableColumn.
// - Implemented custom sorting logic to sort the 'Status' column alphabetically by name.

import SwiftUI

struct PortfolioThemesListView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    
    // Local state for the data
    @State private var themes: [PortfolioTheme] = []
    @State private var statuses: [PortfolioThemeStatus] = []
    
    // State for selection and sheets
    @State private var selectedThemeId: PortfolioTheme.ID?
    @State private var themeToEdit: PortfolioTheme?
    @State private var showingAddSheet = false
    @State private var navigateThemeId: Int?

    // State to manage the table's sort order
    @State private var sortOrder = [KeyPathComparator<PortfolioTheme>]()

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
                        deleteTheme(theme)
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
    }

    // --- Subviews and Helper Methods ---

    private var themesTable: some View {
        Table(themes, selection: $selectedThemeId, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name)
            TableColumn("Code", value: \.code)

            TableColumn("Status", sortUsing: KeyPathComparator(\.statusId)) { theme in
                Text(statusName(for: theme.statusId))
            }

            TableColumn("Last Updated", value: \.updatedAt)

            TableColumn("", content: { theme in
                Button {
                    open(theme)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .help("Open Theme Details")
                .accessibilityLabel("Open details for \(theme.name)")
            })
            .width(30)
        }
        .onChange(of: sortOrder) { newOrder in
            // This custom logic sorts the table correctly when any header is clicked
            guard let comparator = newOrder.first else { return }

            if comparator.keyPath == \.statusId {
                // If the "Status" column is clicked, sort by the status name string
                themes.sort { lhs, rhs in
                    let nameLHS = statusName(for: lhs.statusId)
                    let nameRHS = statusName(for: rhs.statusId)
                    if comparator.order == .forward {
                        return nameLHS.localizedStandardCompare(nameRHS) == .orderedAscending
                    } else {
                        return nameLHS.localizedStandardCompare(nameRHS) == .orderedDescending
                    }
                }
            } else {
                // For all other columns, use the default sorting
                themes.sort(using: newOrder)
            }
        }
        .onTapGesture(count: 2) { openSelected() }
        .contextMenu(forSelectionType: PortfolioTheme.ID.self) { _ in
            Button("Open Theme Details") { openSelected() }.disabled(selectedThemeId == nil)
        }
    }
    
    private func loadData() {
        self.statuses = dbManager.fetchPortfolioThemeStatuses()
        self.themes = dbManager.fetchPortfolioThemes(includeArchived: true, includeSoftDeleted: false, search: nil)
        // Ensure data is sorted when first loaded
        self.themes.sort(using: self.sortOrder)
    }

    private func statusName(for id: Int) -> String {
        return statuses.first { $0.id == id }?.name ?? "N/A"
    }
    
    private func deleteTheme(_ theme: PortfolioTheme) {
        if dbManager.softDeletePortfolioTheme(id: theme.id) {
            selectedThemeId = nil
            loadData()
        } else {
            print("Error: Failed to delete theme with ID \(theme.id)")
        }
    }

    private func openSelected() {
        if let selectedId = selectedThemeId, let theme = themes.first(where: { $0.id == selectedId }) {
            open(theme)
        }
    }

    private func open(_ theme: PortfolioTheme) {
        navigateThemeId = theme.id
    }
}
