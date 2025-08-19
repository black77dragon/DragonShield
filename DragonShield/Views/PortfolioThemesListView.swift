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
                    let defaultStatus = dbManager.fetchPortfolioThemeStatuses().first { $0.isDefault }?.id ?? 0
                    editing = PortfolioTheme(id: 0, name: "", code: "", statusId: defaultStatus, createdAt: "", updatedAt: "", archivedAt: nil, softDelete: false)
                    isNew = true
                }
                Spacer()
            }.padding()
        }
        .navigationTitle("Portfolio Themes")
        .onAppear(perform: load)
        .sheet(item: $editing, onDismiss: load) { theme in
            PortfolioThemeDetailView(theme: theme, isNew: isNew) { updated in
                if isNew {
                    _ = dbManager.createPortfolioTheme(name: updated.name, code: updated.code, statusId: updated.statusId)
                } else {
                    _ = dbManager.updatePortfolioTheme(id: updated.id, name: updated.name, statusId: updated.statusId, archivedAt: updated.archivedAt)
                }
            } onArchive: {
                _ = dbManager.archivePortfolioTheme(id: theme.id)
                load()
            } onUnarchive: { statusId in
                _ = dbManager.unarchivePortfolioTheme(id: theme.id, statusId: statusId)
                load()
            } onSoftDelete: {
                _ = dbManager.softDeletePortfolioTheme(id: theme.id)
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
