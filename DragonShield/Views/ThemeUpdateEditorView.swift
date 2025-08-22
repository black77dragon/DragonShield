// DragonShield/Views/ThemeUpdateEditorView.swift
// MARK: - Version 1.0
// MARK: - History
// - Initial creation: Plain text editor for portfolio theme updates with breadcrumb capture.

import SwiftUI

struct ThemeUpdateEditorView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    let themeName: String
    var existing: PortfolioThemeUpdate?
    var onSave: (PortfolioThemeUpdate) -> Void
    var onCancel: () -> Void

    @State private var title: String
    @State private var bodyText: String
    @State private var type: PortfolioThemeUpdate.UpdateType
    @State private var positionsAsOf: String?
    @State private var totalValueChf: Double?

    init(themeId: Int, themeName: String, existing: PortfolioThemeUpdate? = nil, onSave: @escaping (PortfolioThemeUpdate) -> Void, onCancel: @escaping () -> Void) {
        self.themeId = themeId
        self.themeName = themeName
        self.existing = existing
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: existing?.title ?? "")
        _bodyText = State(initialValue: existing?.bodyText ?? "")
        _type = State(initialValue: existing?.type ?? .General)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existing == nil ? "New Update — \(themeName)" : "Edit Update — \(themeName)")
                .font(.headline)
            TextField("Title", text: $title)
            Picker("Type", selection: $type) {
                ForEach(PortfolioThemeUpdate.UpdateType.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            TextEditor(text: $bodyText)
                .frame(minHeight: 120)
            Text("\(bodyText.count) / 5000")
                .font(.caption)
                .foregroundColor(bodyText.count > 5000 ? .red : .secondary)
            Text("On save we will capture: Positions \(positionsAsOf ?? "—") • Total CHF \(formatted(totalValueChf))")
                .font(.footnote)
                .foregroundColor(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!valid)
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 340)
        .onAppear { loadSnapshot() }
    }

    private var valid: Bool {
        PortfolioThemeUpdate.isValidTitle(title) && PortfolioThemeUpdate.isValidBody(bodyText)
    }

    private func formatted(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        return v.formatted(.currency(code: dbManager.baseCurrency).precision(.fractionLength(2)))
    }

    private func loadSnapshot() {
        let fx = FXConversionService(dbManager: dbManager)
        let service = PortfolioValuationService(dbManager: dbManager, fxService: fx)
        let snap = service.snapshot(themeId: themeId)
        positionsAsOf = snap.positionsAsOf
        totalValueChf = snap.totalValueBase
    }

    private func save() {
        if let existing = existing {
            if let updated = dbManager.updateThemeUpdate(id: existing.id, title: title, bodyText: bodyText, type: type, expectedUpdatedAt: existing.updatedAt) {
                onSave(updated)
            }
        } else {
            if let created = dbManager.createThemeUpdate(themeId: themeId, title: title, bodyText: bodyText, type: type, author: "system", positionsAsOf: positionsAsOf, totalValueChf: totalValueChf) {
                onSave(created)
            }
        }
    }
}
