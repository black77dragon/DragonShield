// DragonShield/Views/PortfolioThemesListView.swift
// MARK: - Version 2.2
// MARK: - History
// - Implemented column sorting for the table.
// - Fixed bug where the view would not refresh after editing a theme.

import SwiftUI

struct PortfolioThemesListView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    
    // Local state for the data displayed in this view
    @State private var themes: [PortfolioTheme] = []
    @State private var statuses: [PortfolioThemeStatus] = []
    
    // State for selection and launching sheets
    @State private var selectedThemeId: PortfolioTheme.ID?
    @State private var themeToEdit: PortfolioTheme?
    @State private var showingAddSheet = false

    // State to manage the table's sort order
    @State private var sortOrder = [KeyPathComparator<PortfolioTheme>]()

    var body: some View {
        VStack {
            // Use a sortable Table by binding it to the `sortOrder` state
            Table(themes, selection: $selectedThemeId, sortOrder: $sortOrder) {
                TableColumn("Name", value: \.name)
                TableColumn("Code", value: \.code)
                
                // Make the Status column sortable by its name
                TableColumn("Status", comparator: KeyPathComparator(\.statusId)) { theme in
                    Text(statusName(for: theme.statusId))
                }
                
                TableColumn("Last Updated", value: \.updatedAt)
            }
            // This modifier detects clicks on column headers and applies the sort
            .onChange(of: sortOrder) { newOrder in
                themes.sort(using: newOrder)
            }
            
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
            // onDismiss here ensures the list reloads after adding a new theme
            AddPortfolioThemeView(isPresented: $showingAddSheet, onSave: {})
                .environmentObject(dbManager)
        }
        // Add onDismiss to the edit sheet to ensure it reloads data on close
        .sheet(item: $themeToEdit, onDismiss: loadData) { theme in
            EditPortfolioThemeView(theme: theme, onSave: {})
                .environmentObject(dbManager)
        }
    }

    /// Fetches and sorts all necessary data from the database.
    private func loadData() {
        self.statuses = dbManager.fetchPortfolioThemeStatuses()
        self.themes = dbManager.fetchPortfolioThemes(includeArchived: true, includeSoftDeleted: false, search: nil)
        // Apply the current sort order to the newly fetched data
        self.themes.sort(using: self.sortOrder)
    }

    /// Finds the name for a given status ID.
    private func statusName(for id: Int) -> String {
        return statuses.first { $0.id == id }?.name ?? "N/A"
    }
    
    /// Deletes the selected theme and reloads the table.
    private func deleteTheme(_ theme: PortfolioTheme) {
        if dbManager.softDeletePortfolioTheme(id: theme.id) {
            selectedThemeId = nil
            loadData()
        } else {
            print("Error: Failed to delete theme with ID \(theme.id)")
        }
    }
}
