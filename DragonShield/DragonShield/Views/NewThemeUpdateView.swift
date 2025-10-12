// DragonShield/Views/NewThemeUpdateView.swift
// Wrapper view to keep project references valid while using ThemeUpdateEditorView.

import SwiftUI

struct NewThemeUpdateView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    let themeName: String
    var onSave: (PortfolioThemeUpdate) -> Void
    var onCancel: () -> Void

    var body: some View {
        ThemeUpdateEditorView(themeId: themeId, themeName: themeName, onSave: onSave, onCancel: onCancel)
            .environmentObject(dbManager)
    }
}
