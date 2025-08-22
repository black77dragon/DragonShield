// DragonShield/Views/NewThemeUpdateView.swift
// Sheet for creating a new PortfolioThemeUpdate with breadcrumb capture.

import SwiftUI

struct NewThemeUpdateView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) private var dismiss
    let theme: PortfolioTheme
    var onSave: (PortfolioThemeUpdate) -> Void
    var onCancel: () -> Void

    @State private var title: String = ""
    @State private var body: String = ""
    @State private var type: PortfolioThemeUpdate.UpdateType = .General

    private var valid: Bool {
        PortfolioThemeUpdate.isValidTitle(title) && PortfolioThemeUpdate.isValidBody(body)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Update — \(theme.name)").font(.headline)
            TextField("Title", text: $title)
            Picker("Type", selection: $type) {
                ForEach(PortfolioThemeUpdate.UpdateType.allCases, id: \.
self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(MenuPickerStyle())
            TextEditor(text: $body)
                .frame(minHeight: 120)
            HStack {
                Spacer()
                Button("Cancel") { onCancel(); dismiss() }
                Button("Save") { save() }
                    .disabled(!valid)
            }
        }
        .padding()
        .frame(width: 480)
    }

    private func save() {
        let fx = FXConversionService(dbManager: dbManager)
        let service = PortfolioValuationService(dbManager: dbManager, fxService: fx)
        let snap = service.snapshot(themeId: theme.id)
        let fmt = ISO8601DateFormatter()
        let asOf = snap.positionsAsOf.map { fmt.string(from: $0) }
        let total = snap.positionsAsOf == nil ? nil : snap.totalValueBase
        if let upd = dbManager.createThemeUpdate(themeId: theme.id, title: title, bodyText: body, type: type, author: NSUserName(), positionsAsOf: asOf, totalValueChf: total) {
            onSave(upd)
            dismiss()
        }
    }
}
