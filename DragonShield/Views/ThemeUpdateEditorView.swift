import SwiftUI
import AppKit

struct ThemeUpdateEditorView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let theme: PortfolioTheme
    var update: PortfolioThemeUpdate?
    var onSave: (PortfolioThemeUpdate) -> Void
    var onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var bodyText: String
    @State private var type: PortfolioThemeUpdate.UpdateType
    @State private var positionsAsOf: String? = nil
    @State private var totalValue: Double? = nil
    @State private var showAlert = false

    private let fmt = ISO8601DateFormatter()

    init(theme: PortfolioTheme, update: PortfolioThemeUpdate? = nil, onSave: @escaping (PortfolioThemeUpdate) -> Void, onCancel: @escaping () -> Void) {
        self.theme = theme
        self.update = update
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: update?.title ?? "")
        _bodyText = State(initialValue: update?.bodyText ?? "")
        _type = State(initialValue: update?.type ?? .General)
        if let up = update {
            _positionsAsOf = State(initialValue: up.positionsAsOf)
            _totalValue = State(initialValue: up.totalValueChf)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Title (1–120):")
            TextField("", text: $title)
                .textFieldStyle(.roundedBorder)
            Picker("Type:", selection: $type) {
                ForEach(PortfolioThemeUpdate.UpdateType.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            Text("Body (plain text, 1–5000):")
            TextEditor(text: $bodyText)
                .frame(minHeight: 120)
                .border(Color.secondary)
            Text("\(bodyText.count) / 5000 characters")
                .font(.caption)
                .foregroundColor(bodyText.count > 5000 ? .red : .secondary)
            Text("On save we will capture: Positions \(positionsAsOf ?? "—") • Total CHF \(totalValue.map { String(format: "%.2f", $0) } ?? "—")")
                .font(.footnote)
                .foregroundColor(.secondary)
            Spacer()
            HStack {
                Spacer()
                Button("Cancel") { dismiss(); onCancel() }
                Button("Save") { save() }
                    .disabled(!valid)
            }
        }
        .padding(24)
        .frame(minWidth: 500, minHeight: 400)
        .onAppear(perform: captureSnapshot)
        .alert("This update was modified elsewhere. Please reload and try again.", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        }
    }

    private var valid: Bool {
        PortfolioThemeUpdate.isValidTitle(title) && PortfolioThemeUpdate.isValidBody(bodyText)
    }

    private func captureSnapshot() {
        guard update == nil else { return }
        let fx = FXConversionService(dbManager: dbManager)
        let service = PortfolioValuationService(dbManager: dbManager, fxService: fx)
        let snap = service.snapshot(themeId: theme.id)
        positionsAsOf = snap.positionsAsOf.map { fmt.string(from: $0) }
        totalValue = snap.positionsAsOf == nil ? nil : snap.totalValueBase
    }

    private func save() {
        if let existing = update {
            if let updated = dbManager.updateThemeUpdate(id: existing.id, title: title, bodyText: bodyText, type: type, expectedUpdatedAt: existing.updatedAt) {
                onSave(updated)
                dismiss()
            } else {
                showAlert = true
            }
        } else {
            let author = NSFullUserName()
            if let created = dbManager.createThemeUpdate(themeId: theme.id, title: title, bodyText: bodyText, type: type, author: author, positionsAsOf: positionsAsOf, totalValueChf: totalValue) {
                onSave(created)
                dismiss()
            }
        }
    }
}
