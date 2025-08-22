import SwiftUI

struct NewThemeUpdateView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let theme: PortfolioTheme
    let valuation: ValuationSnapshot?
    var onSave: (PortfolioThemeUpdate) -> Void
    var onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var bodyText: String = ""
    @State private var type: PortfolioThemeUpdate.UpdateType = .General

    private var breadcrumbText: String {
        let pos = valuation?.positionsAsOf.map { ISO8601DateFormatter().string(from: $0) } ?? "—"
        let total = valuation.map { String(format: "%.2f", $0.totalValueBase) } ?? "—"
        return "Positions \(pos) • Total CHF \(total)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Update — \(theme.name)").font(.headline)
            TextField("Title", text: $title)
            Picker("Type", selection: $type) {
                ForEach(PortfolioThemeUpdate.UpdateType.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(MenuPickerStyle())
            TextEditor(text: $bodyText)
                .frame(minHeight: 120)
            Text("\(bodyText.count) / 5000")
                .font(.caption)
                .foregroundColor(bodyText.count > 5000 ? .red : .secondary)
            Text("On save: capture \(breadcrumbText)")
                .font(.caption)
                .foregroundColor(.secondary)
            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                    dismiss()
                }
                Button("Save") {
                    let breadcrumb = valuation
                    let update = dbManager.createThemeUpdate(
                        themeId: theme.id,
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                        bodyText: bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
                        type: type,
                        author: "user",
                        positionsAsOf: breadcrumb?.positionsAsOf.map { ISO8601DateFormatter().string(from: $0) },
                        totalValueChf: breadcrumb?.totalValueBase
                    )
                    if let update = update {
                        onSave(update)
                        dismiss()
                    }
                }
                .disabled(!PortfolioThemeUpdate.isValidTitle(title) || !PortfolioThemeUpdate.isValidBody(bodyText))
            }
        }
        .padding(20)
        .frame(minWidth: 400, minHeight: 300)
    }
}
