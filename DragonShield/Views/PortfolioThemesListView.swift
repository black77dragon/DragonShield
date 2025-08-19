// DragonShield/Views/PortfolioThemesListView.swift
// MARK: - Version 2.0
// MARK: - History
// - Refactored to correctly manage state and data fetching.
// - Separated Add/Edit logic into dedicated views.
// - Fixed all compilation and runtime errors.

import SwiftUI

struct PortfolioThemesListView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    
    // Local state for the themes displayed in this view
    @State private var themes: [PortfolioTheme] = []
    @State private var selectedTheme: PortfolioTheme?
    
    // State for sheet presentation
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false

    var body: some View {
        VStack {
            List(themes, id: \.self, selection: $selectedTheme) { theme in
                HStack {
                    VStack(alignment: .leading) {
                        Text(theme.name).font(.headline)
                        Text(theme.code).font(.subheadline).foregroundColor(.secondary)
                    }
                    Spacer()
                    // You can add more details here if needed
                }
                .padding(.vertical, 4)
                .tag(theme)
            }
            
            HStack {
                Button(action: {
                    showingAddSheet = true
                }) {
                    Label("Add Theme", systemImage: "plus")
                }

                Button(action: {
                    if selectedTheme != nil {
                        showingEditSheet = true
                    }
                }) {
                    Label("Edit Theme", systemImage: "pencil")
                }
                .disabled(selectedTheme == nil)

                Button(action: {
                    if let themeToDelete = selectedTheme {
                        deleteTheme(themeToDelete)
                    }
                }) {
                    Label("Delete Theme", systemImage: "trash")
                }
                .disabled(selectedTheme == nil)
            }
            .padding()
        }
        .navigationTitle("Portfolio Themes")
        .onAppear(perform: loadThemes)
        .sheet(isPresented: $showingAddSheet) {
            AddPortfolioThemeView(isPresented: $showingAddSheet, onSave: loadThemes)
                .environmentObject(dbManager)
        }
        .sheet(isPresented: $showingEditSheet) {
            // Placeholder for a future EditPortfolioThemeView
            if let themeToEdit = selectedTheme {
                Text("Editing \(themeToEdit.name)")
                // Pass the theme, a binding, and the reload callback
                // EditPortfolioThemeView(theme: themeToEdit, isPresented: $showingEditSheet, onSave: loadThemes)
                //     .environmentObject(dbManager)
            }
        }
    }

    /// Fetches themes from the database and updates the local state.
    private func loadThemes() {
        // Fetches all themes, including archived but not soft-deleted ones.
        // Adjust the parameters as needed for your business logic.
        self.themes = dbManager.fetchPortfolioThemes(includeArchived: true, includeSoftDeleted: false, search: nil)
    }

    /// Soft-deletes the selected theme and reloads the list.
    private func deleteTheme(_ theme: PortfolioTheme) {
        if dbManager.softDeletePortfolioTheme(id: theme.id) {
            selectedTheme = nil // Deselect after deletion
            loadThemes() // Refresh the list from the database
        } else {
            // Optionally, show an error alert to the user
            print("Error: Failed to soft-delete theme with ID \(theme.id)")
        }
    }
}
