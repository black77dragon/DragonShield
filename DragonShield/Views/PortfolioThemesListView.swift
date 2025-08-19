// DragonShield/Views/PortfolioThemesListView.swift
// MARK: - Version 1.1
// MARK: - History
// - Refactored to use EnvironmentObject for dbManager.
// - Fixed selection and state management bugs.
// - Initial creation: List and manage PortfolioTheme records.

import SwiftUI

struct PortfolioThemesListView: View {
    // Use @EnvironmentObject to receive the dbManager from the environment
    @EnvironmentObject var dbManager: DatabaseManager
    
    // State for this view
    @State private var showingAddThemeSheet = false
    @State private var selectedTheme: PortfolioTheme?
    @State private var showingEditSheet = false

    var body: some View {
        VStack {
            List(dbManager.portfolioThemes, id: \.self, selection: $selectedTheme) { theme in
                VStack(alignment: .leading) {
                    Text(theme.name).font(.headline)
                    Text(theme.code).font(.subheadline).foregroundColor(.secondary)
                    
                    // Safely unwrap and display description
                    if let description = theme.description, !description.isEmpty {
                        Text(description).font(.caption).foregroundColor(.gray)
                    }
                }
                .tag(theme) // Tagging the row with the theme object
                .padding(.vertical, 4)
            }
            .contextMenu(forSelectionType: PortfolioTheme.ID.self) { items in
                // This context menu logic remains the same
            } primaryAction: { items in
                guard let themeId = items.first, let theme = dbManager.portfolioThemes.first(where: { $0.id == themeId }) else { return }
                self.selectedTheme = theme
                self.showingEditSheet = true
            }
            
            // --- Toolbar Buttons ---
            HStack {
                Button(action: {
                    showingAddThemeSheet = true
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
        .sheet(isPresented: $showingAddThemeSheet) {
            // The sheet presentation remains the same
            AddPortfolioThemeView(isPresented: $showingAddThemeSheet, dbManager: dbManager)
        }
        .sheet(isPresented: $showingEditSheet) {
            if let themeToEdit = selectedTheme {
                // Placeholder for the Edit View
                Text("Edit View for \(themeToEdit.name)")
            }
        }
        .onAppear {
            // Load data when the view appears
            dbManager.fetchPortfolioThemes()
            dbManager.fetchPortfolioThemeStatuses()
        }
        .navigationTitle("Portfolio Themes")
    }

    private func deleteTheme(_ theme: PortfolioTheme) {
        do {
            try dbManager.deletePortfolioTheme(id: theme.id)
            selectedTheme = nil // Clear selection after deleting
        } catch {
            print("Error deleting theme: \(error.localizedDescription)")
            // Future improvement: Show an error alert to the user
        }
    }
}
