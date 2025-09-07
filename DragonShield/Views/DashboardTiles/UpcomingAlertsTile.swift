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
                            let urgent = isWithinWeek(row.upcomingDate)
                            let dueSoon = !urgent && isDueSoon(row.upcomingDate)
                            HStack {
                                Text(row.alertName)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .foregroundColor(urgent ? .white : (dueSoon ? .red : .primary))
                                Spacer()
                                Text(format(dateStr: row.upcomingDate))
                                    .foregroundColor(urgent ? .white : (dueSoon ? .red : .secondary))
                            }
                            .fontWeight((urgent || dueSoon) ? .bold : .regular)
                            .frame(height: DashboardTileLayout.rowHeight)
                            .padding(.horizontal, urgent ? 6 : 0)
                            .padding(.vertical, urgent ? 2 : 0)
                            .background(
                                Group { if urgent { RoundedRectangle(cornerRadius: 6).fill(Color.red) } else { Color.clear } }
                            )
                        }
                    }
                    .padding(.vertical, DashboardTileLayout.rowSpacing)
                }
                .frame(maxHeight: items.count > 7 ? DashboardTileLayout.rowHeight * 7 + DashboardTileLayout.rowSpacing * 2 : .infinity)
            }
        }
        .padding(DashboardTileLayout.tilePadding)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
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

    private func load() {
        var rows = dbManager.listUpcomingDateAlerts(limit: 200)
        rows.sort { $0.upcomingDate < $1.upcomingDate }
        items = rows
    }

    private func isDueSoon(_ dateStr: String) -> Bool {
        guard let d = Self.inDf.date(from: dateStr) else { return false }
        // Compare date-only in UTC
        let today = Self.inDf.date(from: Self.inDf.string(from: Date())) ?? Date()
        guard let twoWeeks = Calendar.current.date(byAdding: .day, value: 14, to: today) else { return false }
        return d < twoWeeks
    }

    private func isWithinWeek(_ dateStr: String) -> Bool {
        guard let d = Self.inDf.date(from: dateStr) else { return false }
        let today = Self.inDf.date(from: Self.inDf.string(from: Date())) ?? Date()
        guard let oneWeek = Calendar.current.date(byAdding: .day, value: 7, to: today) else { return false }
        return d < oneWeek
    }
}
