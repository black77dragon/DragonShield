// DragonShield/Views/InstrumentUpdateEditorView.swift
// MARK: - Version 1.1
// MARK: - History
// - 1.1: Add Markdown body and pin toggle for Step 7B.
// - 1.0: Initial instrument update editor for Step 7A.

import SwiftUI

struct InstrumentUpdateEditorView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    let instrumentId: Int
    let instrumentName: String
    let themeName: String
    var existing: PortfolioThemeAssetUpdate?
    var valuation: ValuationSnapshot?
    var onSave: (PortfolioThemeAssetUpdate) -> Void
    var onCancel: () -> Void

    @State private var title: String
    @State private var bodyMarkdown: String
    @State private var type: PortfolioThemeAssetUpdate.UpdateType
    @State private var pinned: Bool
    @State private var breadcrumb: (positionsAsOf: String?, valueChf: Double?, actualPercent: Double?)?

    init(themeId: Int, instrumentId: Int, instrumentName: String, themeName: String, existing: PortfolioThemeAssetUpdate? = nil, valuation: ValuationSnapshot? = nil, onSave: @escaping (PortfolioThemeAssetUpdate) -> Void, onCancel: @escaping () -> Void) {
        self.themeId = themeId
        self.instrumentId = instrumentId
        self.instrumentName = instrumentName
        self.themeName = themeName
        self.existing = existing
        self.valuation = valuation
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: existing?.title ?? "")
        _bodyMarkdown = State(initialValue: existing?.bodyMarkdown ?? "")
        _type = State(initialValue: existing?.type ?? .General)
        _pinned = State(initialValue: existing?.pinned ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existing == nil ? "New Instrument Update — \(instrumentName)" : "Edit Instrument Update — \(instrumentName)")
                .font(.headline)
            Text("Theme: \(themeName)")
                .font(.subheadline)
            TextField("Title (1–120)", text: $title)
            Picker("Type", selection: $type) {
                ForEach(PortfolioThemeAssetUpdate.UpdateType.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            Toggle("Pin this update", isOn: $pinned)
            TextEditor(text: $bodyMarkdown)
                .frame(minHeight: 120)
            HStack {
                Text("\(bodyMarkdown.count) / 5000")
                    .font(.caption)
                    .foregroundColor(bodyMarkdown.count > 5000 ? .red : .secondary)
                Spacer()
                if let existing = existing {
                    Text("Created: \(DateFormatting.userFriendly(existing.createdAt))   Edited: \(DateFormatting.userFriendly(existing.updatedAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Text("On save we will capture: Positions \(DateFormatting.userFriendly(breadcrumb?.positionsAsOf)) • Value CHF \(formatted(breadcrumb?.valueChf)) • Actual \(formattedPct(breadcrumb?.actualPercent))")
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
        .frame(minWidth: 520, minHeight: 360)
        .onAppear { loadBreadcrumb() }
    }

    private var valid: Bool {
        PortfolioThemeAssetUpdate.isValidTitle(title) && PortfolioThemeAssetUpdate.isValidBody(bodyMarkdown)
    }

    private func loadBreadcrumb() {
        guard breadcrumb == nil else { return }
        guard let snap = valuation else { return }
        let formatter = ISO8601DateFormatter()
        let pos = snap.positionsAsOf.map { formatter.string(from: $0) }
        let row = snap.rows.first { $0.instrumentId == instrumentId }
        breadcrumb = (pos, row?.currentValueBase, row?.actualPct)
    }

    private func formatted(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        return v.formatted(.currency(code: dbManager.baseCurrency).precision(.fractionLength(2)))
    }

    private func formattedPct(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        return v.formatted(.number.precision(.fractionLength(2))) + "%"
    }

    private func save() {
        if let existing = existing {
            if let updated = dbManager.updateInstrumentUpdate(id: existing.id, title: title, bodyMarkdown: bodyMarkdown, type: type, pinned: pinned, actor: NSFullUserName(), expectedUpdatedAt: existing.updatedAt) {
                onSave(updated)
            }
        } else {
            if let created = dbManager.createInstrumentUpdate(themeId: themeId, instrumentId: instrumentId, title: title, bodyMarkdown: bodyMarkdown, type: type, pinned: pinned, author: NSFullUserName(), breadcrumb: breadcrumb) {
                onSave(created)
            }
        }
    }
}
