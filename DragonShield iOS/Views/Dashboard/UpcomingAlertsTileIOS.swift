#if os(iOS)
import SwiftUI
import SQLite3

struct UpcomingAlertsTileIOS: View {
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.exclamationmark")
                Text("Upcoming Alerts").font(.headline)
                Spacer()
                Button("View All") { showAlerts = true }
                    .font(.caption)
            }
            if items.isEmpty {
                Text("No upcoming alerts").font(.caption).foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(items.enumerated()), id: \.1.alertId) { _, row in
                            let dueSoon = isDueSoon(row.upcomingDate)
                            HStack {
                                Text(row.alertName)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Spacer()
                                Text(format(dateStr: row.upcomingDate))
                                    .foregroundColor(dueSoon ? .red : .secondary)
                            }
                            .font(.subheadline)
                            .fontWeight(dueSoon ? .bold : .regular)
                            .foregroundColor(dueSoon ? .red : .primary)
                            .frame(height: 22)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: items.count > 7 ? 22 * 7 + 8 : .infinity)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onAppear(perform: load)
        .onChange(of: dbManager.dbFilePath) { _ in load() }
        .sheet(isPresented: $showAlerts) { UpcomingAlertsFullListIOS().environmentObject(dbManager) }
    }

    private func format(dateStr: String) -> String {
        if let d = Self.inDf.date(from: dateStr) { return Self.outDf.string(from: d) }
        return dateStr
    }

    private func load() {
        let rows = fetchUpcomingDateAlerts(dbManager, limit: 200)
        items = rows.sorted { $0.upcomingDate < $1.upcomingDate }
    }

    private func isDueSoon(_ dateStr: String) -> Bool {
        guard let d = Self.inDf.date(from: dateStr) else { return false }
        let today = Self.inDf.date(from: Self.inDf.string(from: Date())) ?? Date()
        guard let twoWeeks = Calendar.current.date(byAdding: .day, value: 14, to: today) else { return false }
        return d < twoWeeks
    }
}
#if os(iOS)
private struct UpcomingAlertsFullListIOS: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var items: [(alertId: Int, alertName: String, severity: String, upcomingDate: String)] = []
    private static let inDf: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private static let outDf: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "de_CH"); f.dateFormat = "dd.MM.yy"; return f
    }()
    private func format(_ s: String) -> String { if let d = Self.inDf.date(from: s) { return Self.outDf.string(from: d) }; return s }
    private func isDueSoon(_ s: String) -> Bool {
        guard let d = Self.inDf.date(from: s) else { return false }
        let today = Self.inDf.date(from: Self.inDf.string(from: Date())) ?? Date()
        guard let two = Calendar.current.date(byAdding: .day, value: 14, to: today) else { return false }
        return d < two
    }
    var body: some View {
        NavigationStack {
            List(items, id: \.alertId) { row in
                let due = isDueSoon(row.upcomingDate)
                HStack {
                    Text(row.alertName)
                    Spacer()
                    Text(format(row.upcomingDate)).foregroundColor(due ? .red : .secondary)
                }
                .fontWeight(due ? .bold : .regular)
                .foregroundColor(due ? .red : .primary)
            }
            .navigationTitle("Upcoming Alerts")
            .toolbar { ToolbarItem(placement: .primaryAction) { Button("Done") { dismiss() } } }
            .onAppear(perform: load)
        }
    }
    private func load() {
        let rows = fetchUpcomingDateAlerts(dbManager, limit: 200)
        items = rows.sorted { $0.upcomingDate < $1.upcomingDate }
    }
}
#endif
#endif

// MARK: - Lightweight iOS helper (no dependency on mac-only files)
#if os(iOS)
fileprivate func fetchUpcomingDateAlerts(_ dbManager: DatabaseManager, limit: Int) -> [(alertId: Int, alertName: String, severity: String, upcomingDate: String)] {
    guard let db = dbManager.db else { return [] }
    // Validate that the Alert table exists; if not, return empty (older snapshots)
    var check: OpaquePointer?
    if sqlite3_prepare_v2(db, "SELECT 1 FROM sqlite_master WHERE type='table' AND name='Alert' LIMIT 1", -1, &check, nil) != SQLITE_OK {
        return []
    }
    let exists = sqlite3_step(check) == SQLITE_ROW
    sqlite3_finalize(check)
    guard exists else { return [] }

    // Load candidate date alerts
    var stmt: OpaquePointer?
    let sql = "SELECT id, name, severity, trigger_type_code, params_json, schedule_end FROM Alert WHERE enabled = 1 ORDER BY id DESC"
    var all: [(Int, String, String, String, String?)] = []
    if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(stmt, 0))
            let name = String(cString: sqlite3_column_text(stmt, 1))
            let sev = String(cString: sqlite3_column_text(stmt, 2))
            let trig = String(cString: sqlite3_column_text(stmt, 3))
            guard trig == "date" else { continue }
            let params = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? "{}"
            let schedEnd = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
            all.append((id, name, sev, params, schedEnd))
        }
    }

    // Filter for upcoming (>= today) and within schedule_end; skip those already triggered today
    let inDf = DateFormatter(); inDf.locale = Locale(identifier: "en_US_POSIX"); inDf.timeZone = TimeZone(secondsFromGMT: 0); inDf.dateFormat = "yyyy-MM-dd"
    guard let today = inDf.date(from: inDf.string(from: Date())) else { return [] }

    func alreadyTriggeredToday(_ alertId: Int) -> Bool {
        var s: OpaquePointer?
        defer { sqlite3_finalize(s) }
        let start = inDf.string(from: today) + "T00:00:00Z"
        let next = inDf.string(from: today.addingTimeInterval(86_400)) + "T00:00:00Z"
        if sqlite3_prepare_v2(db, "SELECT 1 FROM AlertEvent WHERE alert_id = ? AND status = 'triggered' AND occurred_at >= ? AND occurred_at < ? LIMIT 1", -1, &s, nil) == SQLITE_OK {
            let T = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_int(s, 1, Int32(alertId))
            sqlite3_bind_text(s, 2, start, -1, T)
            sqlite3_bind_text(s, 3, next, -1, T)
            return sqlite3_step(s) == SQLITE_ROW
        }
        return false
    }

    var out: [(Int, String, String, String)] = []
    for (id, name, sev, params, schedEnd) in all {
        guard let data = params.data(using: .utf8),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { continue }
        let dateStr = (obj["date"] as? String) ?? (obj["trigger_date"] as? String) ?? ""
        guard !dateStr.isEmpty, let d = inDf.date(from: dateStr) else { continue }
        if let end = schedEnd, let endD = inDf.date(from: end), d > endD { continue }
        if d < today { continue }
        if d == today && alreadyTriggeredToday(id) { continue }
        out.append((id, name, sev, dateStr))
        if out.count >= limit { break }
    }
    out.sort { $0.3 < $1.3 }
    return out
}
#endif
