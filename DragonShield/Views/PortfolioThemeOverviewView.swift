// DragonShield/Views/PortfolioThemeOverviewView.swift
// Placeholder overview tab for portfolio theme details.

import SwiftUI

struct PortfolioThemeOverviewView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int

    var body: some View {
        Text("Overview placeholder")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

