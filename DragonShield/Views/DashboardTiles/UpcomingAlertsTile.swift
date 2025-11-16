import SwiftUI

struct UpcomingAlertsTile: DashboardTile {
    init() {}
    static let tileID = "upcoming_alerts"
    static let tileName = "Upcoming Alerts"
    static let iconName = "calendar.badge.exclamationmark"

    @EnvironmentObject var dbManager: DatabaseManager
    @State private var items: [(alertId: Int, alertName: String, severity: String, upcomingDate: String)] = []
    @State private var showAlerts: Bool = false

    private static let inDf: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let outDf: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.dateFormat = "dd.MM.yy"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(Self.tileName)
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button("Open Alerts") { showAlerts = true }
                    .buttonStyle(.link)
            }

            if items.isEmpty {
                Text("No upcoming alerts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DashboardTileLayout.rowSpacing) {
                        ForEach(Array(items.enumerated()), id: \.1.alertId) { _, row in
                            let overdue = isOverdue(row.upcomingDate)
                            let urgent = !overdue && isWithinWeek(row.upcomingDate)
                            let dueSoon = !(overdue || urgent) && isDueSoon(row.upcomingDate)
                            let highlight = overdue || urgent
                            HStack {
                                Text(row.alertName)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .foregroundColor(highlight ? .white : (dueSoon ? .red : .primary))
                                Spacer()
                                HStack(spacing: 8) {
                                    Text(format(dateStr: row.upcomingDate))
                                        .foregroundColor(highlight ? .white : (dueSoon ? .red : .secondary))
                                    if let daysText = daysUntilText(for: row.upcomingDate) {
                                        Text(daysText)
                                            .fontWeight((highlight || dueSoon) ? .bold : .regular)
                                            .foregroundColor(highlight ? .white : .blue)
                                    }
                                }
                            }
                            .fontWeight((highlight || dueSoon) ? .bold : .regular)
                            .frame(height: DashboardTileLayout.rowHeight)
                            .padding(.horizontal, highlight ? 6 : 0)
                            .padding(.vertical, highlight ? 2 : 0)
                            .background(
                                Group { if highlight { RoundedRectangle(cornerRadius: 6).fill(Color.red) } else { Color.clear } }
                            )
                        }
                    }
                    .padding(.vertical, DashboardTileLayout.rowSpacing)
                }
                .frame(maxHeight: items.count > 7 ? DashboardTileLayout.rowHeight * 7 + DashboardTileLayout.rowSpacing * 2 : .infinity)
            }
        }
        .padding(DashboardTileLayout.tilePadding)
        .dashboardTileBackground(cornerRadius: 16)
        .onAppear(perform: load)
        .sheet(isPresented: $showAlerts) {
            AlertsSettingsView().environmentObject(dbManager)
        }
        .accessibilityElement(children: .combine)
    }

    private func format(dateStr: String) -> String {
        if let d = Self.inDf.date(from: dateStr) { return Self.outDf.string(from: d) }
        return dateStr
    }

    private func daysUntilText(for dateStr: String) -> String? {
        guard let dueDate = Self.inDf.date(from: dateStr) else { return nil }
        let today = Self.inDf.date(from: Self.inDf.string(from: Date())) ?? Date()
        let diff = Calendar.current.dateComponents([.day], from: today, to: dueDate).day ?? 0
        if diff < 0 {
            let overdueDays = abs(diff)
            return overdueDays == 1 ? "Overdue by 1 day" : "Overdue by \(overdueDays) days"
        }
        if diff == 0 { return "Today" }
        if diff == 1 { return "1 day" }
        return "\(diff) days"
    }

    private func load() {
        var rows = dbManager.listUpcomingDateAlerts(limit: 200, includeOverdue: true)
        rows.sort { $0.upcomingDate < $1.upcomingDate }
        items = rows
    }

    private func isDueSoon(_ dateStr: String) -> Bool {
        guard let d = Self.inDf.date(from: dateStr) else { return false }
        // Compare date-only in UTC
        let today = Self.inDf.date(from: Self.inDf.string(from: Date())) ?? Date()
        guard let twoWeeks = Calendar.current.date(byAdding: .day, value: 14, to: today) else { return false }
        return d >= today && d < twoWeeks
    }

    private func isWithinWeek(_ dateStr: String) -> Bool {
        guard let d = Self.inDf.date(from: dateStr) else { return false }
        let today = Self.inDf.date(from: Self.inDf.string(from: Date())) ?? Date()
        guard let oneWeek = Calendar.current.date(byAdding: .day, value: 7, to: today) else { return false }
        return d >= today && d < oneWeek
    }

    private func isOverdue(_ dateStr: String) -> Bool {
        guard let d = Self.inDf.date(from: dateStr) else { return false }
        let today = Self.inDf.date(from: Self.inDf.string(from: Date())) ?? Date()
        return d < today
    }
}
