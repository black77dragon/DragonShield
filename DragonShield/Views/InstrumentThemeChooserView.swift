import SwiftUI

struct InstrumentThemeChooserView: View {
    struct ThemeInfo: Identifiable {
        let themeId: Int
        let name: String
        let isArchived: Bool
        let count: Int
        var id: Int { themeId }
    }

    let instrumentId: Int
    let instrumentName: String
    var onSelect: (ThemeInfo) -> Void

    @State private var themes: [ThemeInfo] = []
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    private let dbManager = DatabaseManager()

    var body: some View {
        VStack(alignment: .leading) {
            Text("Updates in Themes — \(instrumentName)")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            TextField("Search", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16)
            List(filteredThemes) { info in
                HStack {
                    Text(info.name)
                    if info.isArchived {
                        Text("Archived")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("\(info.count)")
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect(info)
                    dismiss()
                }
            }
            .listStyle(.inset)
        }
        .frame(minWidth: 360, minHeight: 300)
        .onAppear { load() }
    }

    private var filteredThemes: [ThemeInfo] {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return themes
        }
        return themes.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private func load() {
        let rows = dbManager.listThemesForInstrumentWithUpdateCounts(instrumentId: instrumentId)
        themes = rows.map { ThemeInfo(themeId: $0.themeId, name: $0.themeName, isArchived: $0.isArchived, count: $0.updatesCount) }
        let payload: [String: Any] = ["instrumentId": instrumentId, "themesListed": rows.count, "action": "updates_in_themes_panel_shown"]
        if let data = try? JSONSerialization.data(withJSONObject: payload), let log = String(data: data, encoding: .utf8) {
            LoggingService.shared.log(log, logger: .ui)
        }
    }
}
