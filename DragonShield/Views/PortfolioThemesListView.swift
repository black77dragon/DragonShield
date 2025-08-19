// DragonShield/Views/PortfolioThemesListView.swift
// MARK: - Version 2.3
// MARK: - History
// - Refactored the Table into a separate computed property to fix compiler performance issues.
// - Implemented column sorting for the table.
// - Fixed bug where the view would not refresh after editing a theme.

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

    // State for table sorting
    @State private var sortOrder = [KeyPathComparator<PortfolioTheme>]()

    var body: some View {
        VStack {
            // The main view body is now simplified, referencing the table property below
            themesTable
            
            // Toolbar buttons remain the same
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

    // --- Helper Properties and Methods ---

    /// A private computed property for the Table view.
    /// Extracting this complex view prevents the compiler from timing out.
    private var themesTable: some View {
        Table(themes, selection: $selectedThemeId, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name)
            TableColumn("Code", value: \.code)
            TableColumn("Status", comparator: KeyPathComparator(\.statusId)) { theme in
                Text(statusName(for: theme.statusId))
            }
            TableColumn("Last Updated", value: \.updatedAt)
        }
        .onChange(of: sortOrder) { newOrder in
            themes.sort(using: newOrder)
        }
    }
    
    private func loadData() {
        self.statuses = dbManager.fetchPortfolioThemeStatuses()
        self.themes = dbManager.fetchPortfolioThemes(includeArchived: true, includeSoftDeleted: false, search: nil)
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
}
