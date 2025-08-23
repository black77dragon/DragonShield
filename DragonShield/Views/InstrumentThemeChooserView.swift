import SwiftUI

struct InstrumentThemeChooserView: View {
    struct ThemeInfo: Identifiable {
        let themeId: Int
        let name: String
        let isArchived: Bool
        let updatesCount: Int
        let mentionsCount: Int
        var id: Int { themeId }
    }

    enum SelectionAction {
        case updates
        case mentions
    }

    let instrumentId: Int
    let instrumentName: String
    let instrumentCode: String
    var onSelect: (ThemeInfo, SelectionAction) -> Void

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
                    Button("\(info.updatesCount)") {
                        onSelect(info, .updates)
                        dismiss()
                    }
                    .buttonStyle(.borderless)
                    Button("\(info.mentionsCount)") {
                        onSelect(info, .mentions)
                        dismiss()
                    }
                    .buttonStyle(.borderless)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect(info, .updates)
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
        let rows = dbManager.listThemesForInstrumentWithCounts(instrumentId: instrumentId, instrumentCode: instrumentCode, instrumentName: instrumentName)
        themes = rows.map { ThemeInfo(themeId: $0.themeId, name: $0.themeName, isArchived: $0.isArchived, updatesCount: $0.updatesCount, mentionsCount: $0.mentionsCount) }
        let payload: [String: Any] = ["instrumentId": instrumentId, "themesListed": rows.count, "action": "updates_in_themes_panel_shown"]
        if let data = try? JSONSerialization.data(withJSONObject: payload), let log = String(data: data, encoding: .utf8) {
            LoggingService.shared.log(log, logger: .ui)
        }
    }
}
