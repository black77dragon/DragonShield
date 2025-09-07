import SwiftUI

private struct AlertEventRow: Identifiable, Hashable {
    let id: Int
    let alertId: Int
    let alertName: String
    let severity: String
    let occurredAt: String // ISO8601
    let when: String       // formatted display
    let status: String
    let message: String?
}

struct AlertEventsView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var rows: [AlertEventRow] = []
    @State private var upcoming: [UpcomingRow] = []
    @State private var sortOrder: [SortDescriptor<AlertEventRow>] = [ .init(\AlertEventRow.occurredAt, order: .reverse) ]
    @State private var sortUpcoming: [SortDescriptor<UpcomingRow>] = [ .init(\UpcomingRow.upcomingDate) ]

    private struct UpcomingRow: Identifiable, Hashable {
        let id: Int
        let alertName: String
        let severity: String
        let upcomingDate: String // yyyy-MM-dd
        let when: String         // formatted display
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Alert Events").font(.title3).bold(); Spacer() ; Button("Refresh", action: load) }
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent").font(.headline)
                Table(rows.sorted(using: sortOrder), sortOrder: $sortOrder) {
                    TableColumn("When", value: \AlertEventRow.when).width(180)
                    TableColumn("Alert", value: \AlertEventRow.alertName)
                    TableColumn("Severity", value: \AlertEventRow.severity).width(100)
                    TableColumn("Status", value: \AlertEventRow.status).width(100)
                    TableColumn("Message") { r in Text(r.message ?? "") }
                }
                .frame(minHeight: 220)
                Divider().padding(.vertical, 6)
                Text("Upcoming").font(.headline)
                Table(upcoming.sorted(using: sortUpcoming), sortOrder: $sortUpcoming) {
                    TableColumn("When", value: \UpcomingRow.when).width(180)
                    TableColumn("Alert", value: \UpcomingRow.alertName)
                    TableColumn("Severity", value: \UpcomingRow.severity).width(100)
                }
                .frame(minHeight: 180)
            }
        }
        .padding(16)
        .onAppear(perform: load)
    }

    private func load() {
        // Load recent events
        let events = dbManager.listAlertEvents(limit: 300)
        rows = events.map { e in
            .init(id: e.id, alertId: e.alertId, alertName: e.alertName, severity: e.severity, occurredAt: e.occurredAt, when: formatDateTime(e.occurredAt), status: e.status, message: e.message)
        }
        // Build a recent window set (last 30 days) to prevent duplicates across Recent and Upcoming
        let iso = ISO8601DateFormatter()
        let recentCut = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentIds: Set<Int> = Set(events.compactMap { e in
            if let d = iso.date(from: e.occurredAt), d >= recentCut { return e.alertId } else { return nil }
        })
        // Load upcoming and exclude any alert that has a recent event
        let ups = dbManager.listUpcomingDateAlerts(limit: 200)
            .filter { u in !recentIds.contains(u.alertId) }
        upcoming = ups.map { u in .init(id: u.alertId, alertName: u.alertName, severity: u.severity, upcomingDate: u.upcomingDate, when: formatDateOnly(u.upcomingDate)) }
    }

    private func formatDateTime(_ iso: String) -> String {
        let isoFmt = ISO8601DateFormatter()
        guard let d = isoFmt.date(from: iso) else { return iso }
        let fmt = DateFormatter(); fmt.locale = Locale(identifier: "de_CH"); fmt.dateFormat = "dd.MM.yyyy HH:mm"
        return fmt.string(from: d)
    }
    private func formatDateOnly(_ ymd: String) -> String {
        let df = DateFormatter(); df.locale = Locale(identifier: "de_CH"); df.dateFormat = "yyyy-MM-dd"
        if let d = df.date(from: ymd) {
            let out = DateFormatter(); out.locale = df.locale; out.dateFormat = "dd.MM.yyyy 00:00"
            return out.string(from: d)
        }
        return ymd
    }
}
