// DragonShield/Views/PortfolioThemesListView.swift
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
                        Button("Open") {
                            isNew = false
                            editing = theme
                        }
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
                                let defaultStatus = dbManager.fetchPortfolioThemeStatuses().first { $0.isDefault }?.id ?? theme.statusId
                                if !dbManager.unarchivePortfolioTheme(id: theme.id, statusId: defaultStatus) {
                                    errorMessage = "Failed to unarchive theme"
                                    showErrorAlert = true
                                }
                                load()
                            }
                        }
                    }
                }
            }
            HStack {
                Button("+ New Theme") {
                    isNew = true
                    let defaultStatus = dbManager.fetchPortfolioThemeStatuses().first { $0.isDefault }?.id ?? 0
                    editing = PortfolioTheme(id: 0,
                                             name: "",
                                             code: "",
                                             statusId: defaultStatus,
                                             createdAt: "",
                                             updatedAt: "",
                                             archivedAt: nil,
                                             softDelete: false)
                }
                Spacer()
            }.padding()
        }
        .navigationTitle("Portfolio Themes")
        .onAppear(perform: load)
        .sheet(item: $editing, onDismiss: {
            isNew = false
            load()
        }) { theme in
            PortfolioThemeDetailView(theme: theme, isNew: isNew) { updated in
                if isNew {
                    if let created = dbManager.createPortfolioTheme(name: updated.name, code: updated.code, statusId: updated.statusId) {
                        themes.append(created)
                    } else {
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
