import SwiftUI

struct PortfolioThemesListView: View {
    @StateObject private var dbManager = DatabaseManager.shared
    @State private var showingAddThemeSheet = false
    @State private var selectedTheme: PortfolioTheme?
    @State private var showingEditSheet = false // This can be refactored later

    var body: some View {
        VStack {
            // The list remains largely the same
            List(selection: $selectedTheme) {
                ForEach(dbManager.portfolioThemes) { theme in
                    VStack(alignment: .leading) {
                        Text(theme.name).font(.headline)
                        Text(theme.code).font(.subheadline).foregroundColor(.secondary)
                        if let description = theme.description, !description.isEmpty {
                            Text(description).font(.caption).foregroundColor(.gray)
                        }
                    }
                    .tag(theme)
                    .padding(.vertical, 4)
                }
            }
            .contextMenu(forSelectionType: PortfolioTheme.ID.self) { _ in } primaryAction: { items in
                guard let themeId = items.first, let theme = dbManager.portfolioThemes.first(where: { $0.id == themeId }) else { return }
                self.selectedTheme = theme
                self.showingEditSheet = true
            }
            
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
            // Use the new, dedicated view for the sheet content
            AddPortfolioThemeView(isPresented: $showingAddThemeSheet, dbManager: dbManager)
        }
        .sheet(isPresented: $showingEditSheet) {
            // The edit sheet logic can be similarly refactored into its own view
            if let themeToEdit = selectedTheme {
                // An `EditPortfolioThemeView` would go here
                Text("Edit View for \(themeToEdit.name)")
            }
        }
        .onAppear {
            dbManager.fetchPortfolioThemes()
            dbManager.fetchPortfolioThemeStatuses()
        }
        .navigationTitle("Portfolio Themes")
    }

    private func deleteTheme(_ theme: PortfolioTheme) {
        do {
            try dbManager.deletePortfolioTheme(id: theme.id)
            selectedTheme = nil // Deselect after deletion
        } catch {
            print("Error deleting theme: \(error.localizedDescription)")
            // Consider showing an error alert to the user
        }
    }
}// DragonShield/Views/PortfolioThemesListView.swift
// MARK: - Version 1.0
// MARK: - History
// - Initial creation: List and manage PortfolioTheme records.

import SwiftUI

struct PortfolioThemesListView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var themes: [PortfolioTheme] = []
    @State private var editing: PortfolioTheme?
    @State private var isNew: Bool = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        VStack {
            List {
                ForEach(themes) { theme in
                    HStack {
                        Text(theme.name).frame(width: 160, alignment: .leading)
                        Text(theme.code).frame(width: 120, alignment: .leading)
                        Text(statusName(theme.statusId)).frame(width: 80, alignment: .leading)
                        Text(theme.updatedAt).frame(width: 180, alignment: .leading)
                        Spacer()
                        Button("Open") { editing = theme; isNew = false }
                        if theme.archivedAt == nil {
                            Button("Archive") {
                                if !dbManager.archivePortfolioTheme(id: theme.id) {
                                    errorMessage = "Failed to archive theme"
                                    showErrorAlert = true
                                }
                                load()
                            }
                        } else {
                Button("Unarchive") {
                    if let defaultStatus = dbManager.defaultThemeStatusId() {
                        if !dbManager.unarchivePortfolioTheme(id: theme.id, statusId: defaultStatus) {
                            errorMessage = "Failed to unarchive theme"
                            showErrorAlert = true
                        }
                        load()
                    } else {
                        errorMessage = "Cannot unarchive theme: No default status is configured."
                        showErrorAlert = true
                    }
                }
                        }
                    }
                }
            }
            HStack {
                Button("+ New Theme") {
                    if let defaultStatus = dbManager.defaultThemeStatusId() {
                        isNew = true
                        editing = PortfolioTheme(id: 0, name: "", code: "", statusId: defaultStatus, createdAt: "", updatedAt: "", archivedAt: nil, softDelete: false)
                    } else {
                        errorMessage = "Cannot create a new theme: No default status is configured."
                        showErrorAlert = true
                    }
                }
                Spacer()
            }.padding()
        }
        .navigationTitle("Portfolio Themes")
        .onAppear(perform: load)
        .sheet(item: $editing, onDismiss: load) { theme in
            PortfolioThemeDetailView(theme: theme, isNew: isNew) { updated in
                if isNew {
                    if dbManager.createPortfolioTheme(name: updated.name, code: updated.code, statusId: updated.statusId) == nil {
                        errorMessage = "Failed to create theme"
                        showErrorAlert = true
                    }
                } else {
                    if !dbManager.updatePortfolioTheme(id: updated.id, name: updated.name, statusId: updated.statusId, archivedAt: updated.archivedAt) {
                        errorMessage = "Failed to update theme"
                        showErrorAlert = true
                    } else {
                        load()
                    }
                }
            } onArchive: {
                if !dbManager.archivePortfolioTheme(id: theme.id) {
                    errorMessage = "Failed to archive theme"
                    showErrorAlert = true
                }
                load()
            } onUnarchive: { statusId in
                if !dbManager.unarchivePortfolioTheme(id: theme.id, statusId: statusId) {
                    errorMessage = "Failed to unarchive theme"
                    showErrorAlert = true
                }
                load()
            } onSoftDelete: {
                if !dbManager.softDeletePortfolioTheme(id: theme.id) {
                    errorMessage = "Failed to delete theme"
                    showErrorAlert = true
                }
                load()
            }
        }
        .alert("Database Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func load() {
        themes = dbManager.fetchPortfolioThemes(includeArchived: true, includeSoftDeleted: false, search: nil)
    }

    private func statusName(_ id: Int) -> String {
        dbManager.fetchPortfolioThemeStatuses().first { $0.id == id }?.name ?? "-"
    }
}
