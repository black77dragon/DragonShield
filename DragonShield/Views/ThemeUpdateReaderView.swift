// DragonShield/Views/ThemeUpdateReaderView.swift
// Read-only view for a single theme update.

import SwiftUI

struct ThemeUpdateReaderView: View {
    let update: PortfolioThemeUpdate

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(update.title)
                .font(.title2)
            ScrollView {
                Text(update.bodyMarkdown)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer()
        }
        .padding()
        .frame(minWidth: 360, idealWidth: 400)
    }
}
