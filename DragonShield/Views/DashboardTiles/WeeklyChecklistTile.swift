import SwiftUI

struct WeeklyChecklistTile: DashboardTile {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.openWindow) private var openWindow
    @State private var dueThemes: [PortfolioTheme] = []
    @State private var totalEnabled: Int = 0
    @State private var completedCount: Int = 0
    @State private var loading = false

    init() {}
    static let tileID = "weekly_checklist"
    static let tileName = "Weekly Checklists"
    static let iconName = "checklist"

    var body: some View {
        DashboardCard(title: Self.tileName, minHeight: DashboardTileLayout.heroTileHeight) {
            VStack(alignment: .leading, spacing: 8) {
                if loading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    summaryRow
                    if dueThemes.isEmpty {
                        Text("No portfolios due this week.")
                            .foregroundColor(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(dueThemes.prefix(3)) { theme in
                                Text("- \(theme.name)")
                                    .font(.caption)
                            }
                            if dueThemes.count > 3 {
                                Text("...and \(dueThemes.count - 3) more")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    Button("Open Weekly Checklist") {
                        openWindow(id: "weeklyChecklist")
                    }
                    .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
                    .disabled(totalEnabled == 0)
                }
            }
        }
        .onAppear(perform: load)
        .onReceive(NotificationCenter.default.publisher(for: .weeklyChecklistUpdated)) { _ in
            load()
        }
        .accessibilityElement(children: .contain)
    }

    private var summaryRow: some View {
        HStack(spacing: 12) {
            Text("Due: \(dueThemes.count)")
                .font(.headline)
                .foregroundColor(dueThemes.isEmpty ? .secondary : .primary)
            if totalEnabled > 0 {
                Text("Completed: \(completedCount)/\(totalEnabled)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("No portfolios enabled")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private func load() {
        loading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let currentWeek = WeeklyChecklistDateHelper.weekStart(for: Date())
            let themes = dbManager.fetchPortfolioThemes(includeArchived: false, includeSoftDeleted: false)
            let enabled = themes.filter { $0.weeklyChecklistEnabled }
            var due: [PortfolioTheme] = []
            var completed = 0
            for theme in enabled {
                if let entry = dbManager.fetchWeeklyChecklist(themeId: theme.id, weekStartDate: currentWeek) {
                    if entry.status == .completed || entry.status == .skipped {
                        completed += 1
                    } else {
                        due.append(theme)
                    }
                } else {
                    due.append(theme)
                }
            }
            DispatchQueue.main.async {
                dueThemes = due.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                totalEnabled = enabled.count
                completedCount = completed
                loading = false
            }
        }
    }
}
