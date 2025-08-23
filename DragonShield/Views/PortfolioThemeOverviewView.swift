// DragonShield/Views/PortfolioThemeOverviewView.swift
// Overview tab with latest theme updates.

import SwiftUI

struct PortfolioThemeOverviewView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    @State private var updates: [PortfolioThemeUpdate] = []
    @State private var readerItem: PortfolioThemeUpdate?

    var body: some View {
        List(updates) { update in
            HStack {
                VStack(alignment: .leading) {
                    Text(update.createdAt)
                        .font(.caption)
                    Text(update.title)
                        .font(.headline)
                }
                Spacer()
                Button("View") { readerItem = update }
            }
        }
        .listStyle(.plain)
        .onAppear { load() }
        .sheet(item: $readerItem) { item in
            ThemeUpdateReaderView(update: item)
        }
    }

    private func load() {
        updates = dbManager.listThemeUpdates(themeId: themeId, view: .active, type: nil, searchQuery: nil, pinnedFirst: true)
    }
}
