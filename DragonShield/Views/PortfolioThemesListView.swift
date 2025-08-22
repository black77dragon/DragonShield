// DragonShield/Views/PortfolioThemesListView.swift
// MARK: - Version 2.6
// MARK: - History
// - 2.5 -> 2.6: Add fast path and toolbar access to Portfolio Theme Updates.

import SwiftUI
import AppKit

struct PortfolioThemesListView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    // Local state
    @State var themes: [PortfolioTheme] = []
    @State private var statuses: [PortfolioThemeStatus] = []
    @State private var selectedThemeId: PortfolioTheme.ID?
    @State private var themeToEdit: PortfolioTheme?
    @State private var showingAddSheet = false
    @State private var themeToOpen: PortfolioTheme?
    @State private var detailSource = "list"
    @State private var updateTheme: PortfolioTheme?

    // Delete handling
    @State private var themeToDelete: PortfolioTheme?
    @State private var showArchiveAlert = false
    @State private var alertMessage = ""
    @State private var showingResultAlert = false

    var body: some View {
        NavigationStack {
            VStack {
                themesTable
                Button(action: openSelected) { EmptyView() }
                    .keyboardShortcut(.return)
                    .hidden()
                    .disabled(selectedThemeId == nil)
                if dbManager.portfolioThemeUpdatesEnabled {
                    Button(action: { openNewUpdate(source: "shortcut") }) { EmptyView() }
                        .keyboardShortcut("u", modifiers: .command)
                        .hidden()
                        .disabled(selectedThemeId == nil)
                }
                HStack {
                    Button(action: { showingAddSheet = true }) { Label("Add Theme", systemImage: "plus") }
                    Button(action: { if let id = selectedThemeId { themeToEdit = themes.first { $0.id == id } } }) { Label("Edit Theme", systemImage: "pencil") }
                        .disabled(selectedThemeId == nil)
                    Button(action: { if let id = selectedThemeId, let t = themes.first(where: { $0.id == id }) { handleDelete(t) } }) { Label("Delete Theme", systemImage: "trash") }
                        .disabled(selectedThemeId == nil)
                    if dbManager.portfolioThemeUpdatesEnabled {
                        Button(action: { openNewUpdate(source: "toolbar") }) { Label("+ New Update", systemImage: "text.badge.plus") }
                            .disabled(selectedThemeId == nil)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Portfolio Themes")
        .onAppear { loadData() }
        .sheet(isPresented: $showingAddSheet, onDismiss: loadData) {
            AddPortfolioThemeView(isPresented: $showingAddSheet, onSave: {}).environmentObject(dbManager)
        }
        .sheet(item: $themeToEdit, onDismiss: loadData) { theme in
            EditPortfolioThemeView(theme: theme, onSave: {}).environmentObject(dbManager)
        }
        .sheet(item: $themeToOpen, onDismiss: loadData) { theme in
            PortfolioThemeDetailView(themeId: theme.id, origin: detailSource).environmentObject(dbManager)
        }
        .sheet(item: $updateTheme) { theme in
            NewThemeUpdateView(theme: theme, valuation: nil) { _ in
                themeToOpen = theme
                detailSource = "post_create"
                LoggingService.shared.log("new_update_saved themeId=\(theme.id) source=fast_path", logger: .database)
            } onCancel: {
                LoggingService.shared.log("new_update_canceled themeId=\(theme.id) source=fast_path", logger: .database)
            }
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

    // MARK: - Table
    private var themesTable: some View {
        Table(themes, selection: $selectedThemeId) {
            TableColumn("Name", value: \.name)
            TableColumn("Code", value: \.code)
            TableColumn("Status") { theme in Text(statusName(for: theme.statusId)) }
            TableColumn("Last Updated", value: \.updatedAt)
            TableColumn("Total Value") { theme in
                Text(theme.totalValueBase.map { String(format: "%.2f", $0) } ?? "-")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            TableColumn("Instruments", value: \.instrumentCount)
            TableColumn("", content: { theme in
                Button { open(theme) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.plain)
                    .help("Open Theme Details")
            })
            .width(30)
        }
        .onTapGesture(count: 2) { openSelected() }
        .contextMenu(forSelectionType: PortfolioTheme.ID.self) { _ in
            Button("Open Theme Details") { openSelected() }.disabled(selectedThemeId == nil)
            if dbManager.portfolioThemeUpdatesEnabled {
                Button("New Update…") { openNewUpdate(source: "context_menu") }
            }
        }
    }

    // MARK: - Helpers
    func loadData() {
        statuses = dbManager.fetchPortfolioThemeStatuses()
        themes = dbManager.fetchPortfolioThemes(includeArchived: true, includeSoftDeleted: false, search: nil)
    }

    private func statusName(for id: Int) -> String {
        statuses.first { $0.id == id }?.name ?? "N/A"
    }

    private func open(_ theme: PortfolioTheme) {
        themeToOpen = theme
        detailSource = "list"
    }

    private func openSelected() {
        if let id = selectedThemeId, let theme = themes.first(where: { $0.id == id }) {
            open(theme)
        }
    }

    private func openNewUpdate(source: String) {
        guard dbManager.portfolioThemeUpdatesEnabled else { return }
        if let id = selectedThemeId, let theme = themes.first(where: { $0.id == id }) {
            updateTheme = theme
            LoggingService.shared.log("new_update_invoke themeId=\(theme.id) source=\(source)", logger: .database)
        } else {
            NSBeep()
        }
    }

    func handleDelete(_ theme: PortfolioTheme) {
        if isArchived(theme) {
            themeToDelete = theme
            archiveAndDelete()
        } else {
            themeToDelete = theme
            showArchiveAlert = true
        }
    }

    func archiveAndDelete() {
        guard let theme = themeToDelete else { return }
        if !isArchived(theme) {
            _ = dbManager.archivePortfolioTheme(id: theme.id)
        }
        _ = dbManager.softDeletePortfolioTheme(id: theme.id)
        alertMessage = "Deleted theme \(theme.name)"
        showingResultAlert = true
        loadData()
        themeToDelete = nil
    }

    private func isArchived(_ theme: PortfolioTheme) -> Bool {
        statuses.first { $0.id == theme.statusId }?.code == PortfolioThemeStatus.archivedCode
    }
}
