// DragonShield/Views/PortfolioThemesListView.swift
// MARK: - Version 2.1
// MARK: - History
// - Replaced List with Table for proper column display.
// - Implemented a functional Edit sheet.
// - Added Status column and data loading.

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

    var body: some View {
        VStack {
            // Use a Table for a clean, column-based layout with headers
            Table(themes, selection: $selectedThemeId) {
                TableColumn("Name", value: \.name)
                TableColumn("Code", value: \.code)
                
                // Add the Status column by looking up the status name
                TableColumn("Status") { theme in
                    Text(statusName(for: theme.statusId))
                }
                
                TableColumn("Last Updated", value: \.updatedAt)
            }
            
            HStack {
                Button(action: { showingAddSheet = true }) {
                    Label("Add Theme", systemImage: "plus")
                }

                Button(action: {
                    // Find the selected theme and set it to trigger the edit sheet
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
        // Use .sheet(item:) to present the edit view when `themeToEdit` is not nil
        .sheet(item: $themeToEdit) { theme in
            EditPortfolioThemeView(theme: theme, onSave: loadData)
                .environmentObject(dbManager)
        }
    }

    /// Fetches all necessary data from the database.
    private func loadData() {
        self.statuses = dbManager.fetchPortfolioThemeStatuses()
        self.themes = dbManager.fetchPortfolioThemes(includeArchived: true, includeSoftDeleted: false, search: nil)
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
